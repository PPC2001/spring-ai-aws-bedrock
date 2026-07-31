# ==============================================================================
# Automated Deployment Script for AWS ECS Fargate & ECR
# Usage: .\deploy-to-ecs.ps1 -Env dev
# ==============================================================================

param (
    [string]$Env = "dev"
)

$ErrorActionPreference = "Stop"

$IacFile = ".\.iac\$Env.json"
if (-not (Test-Path $IacFile)) {
    Write-Host "Error: Configuration file $IacFile not found." -ForegroundColor Red
    exit 1
}

Write-Host ">>> Loading environment configuration from $IacFile..." -ForegroundColor Cyan
$Config = Get-Content $IacFile | ConvertFrom-Json

$AccountID  = $Config.aws_account_id
$Region     = $Config.aws_region
$EcrRepo    = $Config.ecr_repository
$EcrImage   = $Config.ecr_image_uri
$Cluster    = $Config.ecs_cluster_name
$Service    = $Config.ecs_service_name
$TaskFamily = $Config.task_family

Write-Host "==================================================================" -ForegroundColor Yellow
Write-Host " Deploying to Environment : $Env" -ForegroundColor Yellow
Write-Host " ECR Repository           : $EcrImage" -ForegroundColor Yellow
Write-Host " ECS Cluster              : $Cluster" -ForegroundColor Yellow
Write-Host " AWS Region               : $Region" -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Yellow

# 1. AWS ECR Login
Write-Host ">>> Step 1: Logging into AWS ECR..." -ForegroundColor Cyan
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin "$AccountID.dkr.ecr.$Region.amazonaws.com"

# 2. Build Docker Image
Write-Host ">>> Step 2: Building Docker image..." -ForegroundColor Cyan
docker build -t "$EcrRepo:latest" .

# 3. Tag Docker Image
Write-Host ">>> Step 3: Tagging Docker image for ECR..." -ForegroundColor Cyan
docker tag "$EcrRepo:latest" $EcrImage

# 4. Push to ECR
Write-Host ">>> Step 4: Pushing image to ECR ($EcrImage)..." -ForegroundColor Cyan
docker push $EcrImage

# 5. Create CloudWatch Log Group if not exists
Write-Host ">>> Step 5: Ensuring CloudWatch Log Group exists..." -ForegroundColor Cyan
aws logs create-log-group --log-group-name "/ecs/$TaskFamily" --region $Region 2>$null

# 6. Register Task Definition
Write-Host ">>> Step 6: Registering ECS Task Definition..." -ForegroundColor Cyan

$Template = Get-Content ".\.iac\task-definition-template.json" -Raw
$TaskDefJson = $Template `
    -replace '\$\{TASK_FAMILY\}', $TaskFamily `
    -replace '\$\{CPU\}', $Config.cpu `
    -replace '\$\{MEMORY\}', $Config.memory `
    -replace '\$\{AWS_ACCOUNT_ID\}', $AccountID `
    -replace '\$\{CONTAINER_NAME\}', $Config.container_name `
    -replace '\$\{ECR_IMAGE_URI\}', $EcrImage `
    -replace '\$\{CONTAINER_PORT\}', $Config.container_port `
    -replace '\$\{SPRING_PROFILES_ACTIVE\}', $Config.env_variables.SPRING_PROFILES_ACTIVE `
    -replace '\$\{AWS_REGION\}', $Region `
    -replace '\$\{BEDROCK_MODEL_ID\}', $Config.env_variables.BEDROCK_MODEL_ID `
    -replace '\$\{BEDROCK_TEMPERATURE\}', $Config.env_variables.BEDROCK_TEMPERATURE `
    -replace '\$\{BEDROCK_MAX_TOKENS\}', $Config.env_variables.BEDROCK_MAX_TOKENS `
    -replace '\$\{PORT\}', $Config.env_variables.PORT

$TempTaskFile = [System.IO.Path]::GetTempFileName() + ".json"
$TaskDefJson | Set-Content $TempTaskFile

$RegisterResult = aws ecs register-task-definition --cli-input-json "file://$TempTaskFile" --region $Region | ConvertFrom-Json
Remove-Item $TempTaskFile -Force

$TaskDefArn = $RegisterResult.taskDefinition.taskDefinitionArn
Write-Host "Registered Task Definition ARN: $TaskDefArn" -ForegroundColor Green

# 7. Check if ECS Service exists & Update/Create
Write-Host ">>> Step 7: Deploying to ECS Cluster ($Cluster)..." -ForegroundColor Cyan
$ServiceStatus = (aws ecs describe-services --cluster $Cluster --services $Service --region $Region --query "services[0].status" --output text 2>$null)

if ($ServiceStatus -eq "ACTIVE") {
    Write-Host "Updating existing ECS Service '$Service' with new task definition..." -ForegroundColor Yellow
    aws ecs update-service --cluster $Cluster --service $Service --task-definition $TaskDefArn --force-new-deployment --region $Region
} else {
    Write-Host "Service '$Service' does not exist yet. Please run the ALB setup script first or specify subnets & target group to create the service." -ForegroundColor Yellow
    Write-Host "Command to create service with ALB:" -ForegroundColor Cyan
    Write-Host "aws ecs create-service --cluster $Cluster --service-name $Service --task-definition $TaskDefArn --desired-count 1 --launch-type FARGATE --network-configuration 'awsvpcConfiguration={subnets=[<subnet-1>,<subnet-2>],securityGroups=[<task-sg-id>],assignPublicIp=ENABLED}' --load-balancers 'targetGroupArn=<target-group-arn>,containerName=springai-app,containerPort=8080' --region $Region" -ForegroundColor White
}

Write-Host "==================================================================" -ForegroundColor Green
Write-Host " Deployment process completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
