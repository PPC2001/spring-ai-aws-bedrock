# ==============================================================================
# AWS CLI Script: Create ALB, Target Group, Security Groups, IAM Roles for ECS
# Environment: dev (ap-south-1)
# ==============================================================================

param (
    [string]$Region = "ap-south-1",
    [string]$VpcId = "",
    [string]$Env = "dev"
)

$ErrorActionPreference = "Stop"

Write-Host ">>> Checking AWS CLI identity..." -ForegroundColor Cyan
aws sts get-caller-identity --region $Region

# 1. Get VPC ID if not provided
if (-not $VpcId) {
    Write-Host ">>> Fetching default VPC ID..." -ForegroundColor Cyan
    $VpcId = (aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region $Region)
    if ($VpcId -eq "None" -or -not $VpcId) {
        Write-Host "Error: Default VPC not found. Please pass -VpcId <your-vpc-id>" -ForegroundColor Red
        exit 1
    }
}
Write-Host "Using VPC ID: $VpcId" -ForegroundColor Green

# 2. Get Subnets
Write-Host ">>> Fetching subnets..." -ForegroundColor Cyan
$SubnetIds = (aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" --query "Subnets[*].SubnetId" --output text --region $Region) -split "\s+"
if ($SubnetIds.Count -lt 2) {
    Write-Host "Error: Need at least 2 subnets in different availability zones." -ForegroundColor Red
    exit 1
}
$Subnet1 = $SubnetIds[0]
$Subnet2 = $SubnetIds[1]
Write-Host "Selected Subnets: $Subnet1, $Subnet2" -ForegroundColor Green

# 3. Create Security Group for ALB
$AlbSgName = "springai-alb-sg-$Env"
Write-Host ">>> Creating ALB Security Group ($AlbSgName)..." -ForegroundColor Cyan
$AlbSgId = (aws ec2 create-security-group --group-name $AlbSgName --description "ALB SG for Spring AI" --vpc-id $VpcId --query "GroupId" --output text --region $Region 2>$null)
if (-not $AlbSgId) {
    $AlbSgId = (aws ec2 describe-security-groups --group-names $AlbSgName --query "SecurityGroups[0].GroupId" --output text --region $Region)
}
aws ec2 authorize-security-group-ingress --group-id $AlbSgId --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $Region 2>$null
Write-Host "ALB Security Group ID: $AlbSgId" -ForegroundColor Green

# 4. Create Security Group for ECS Task
$TaskSgName = "springai-ecs-task-sg-$Env"
Write-Host ">>> Creating ECS Task Security Group ($TaskSgName)..." -ForegroundColor Cyan
$TaskSgId = (aws ec2 create-security-group --group-name $TaskSgName --description "ECS Task SG for Spring AI" --vpc-id $VpcId --query "GroupId" --output text --region $Region 2>$null)
if (-not $TaskSgId) {
    $TaskSgId = (aws ec2 describe-security-groups --group-names $TaskSgName --query "SecurityGroups[0].GroupId" --output text --region $Region)
}
aws ec2 authorize-security-group-ingress --group-id $TaskSgId --protocol tcp --port 8080 --source-group $AlbSgId --region $Region 2>$null
Write-Host "ECS Task Security Group ID: $TaskSgId" -ForegroundColor Green

# 5. Create Target Group
$TgName = "springai-tg-$Env"
Write-Host ">>> Creating Target Group ($TgName)..." -ForegroundColor Cyan
$TgArn = (aws elbv2 create-target-group `
    --name $TgName `
    --protocol HTTP `
    --port 8080 `
    --vpc-id $VpcId `
    --target-type ip `
    --health-check-protocol HTTP `
    --health-check-path "/actuator/health" `
    --health-check-interval-seconds 30 `
    --healthy-threshold-count 2 `
    --unhealthy-threshold-count 3 `
    --query "TargetGroups[0].TargetGroupArn" `
    --output text `
    --region $Region 2>$null)

if (-not $TgArn) {
    $TgArn = (aws elbv2 describe-target-groups --names $TgName --query "TargetGroups[0].TargetGroupArn" --output text --region $Region)
}
Write-Host "Target Group ARN: $TgArn" -ForegroundColor Green

# 6. Create Load Balancer (ALB)
$AlbName = "springai-alb-$Env"
Write-Host ">>> Creating Application Load Balancer ($AlbName)..." -ForegroundColor Cyan
$AlbArn = (aws elbv2 create-load-balancer `
    --name $AlbName `
    --subnets $Subnet1 $Subnet2 `
    --security-groups $AlbSgId `
    --scheme internet-facing `
    --type application `
    --query "LoadBalancers[0].LoadBalancerArn" `
    --output text `
    --region $Region 2>$null)

if (-not $AlbArn) {
    $AlbArn = (aws elbv2 describe-load-balancers --names $AlbName --query "LoadBalancers[0].LoadBalancerArn" --output text --region $Region)
}
$AlbDns = (aws elbv2 describe-load-balancers --load-balancer-arns $AlbArn --query "LoadBalancers[0].DNSName" --output text --region $Region)
Write-Host "ALB DNS Name: $AlbDns" -ForegroundColor Green

# 7. Create Listener
Write-Host ">>> Creating ALB HTTP Listener..." -ForegroundColor Cyan
aws elbv2 create-listener `
    --load-balancer-arn $AlbArn `
    --protocol HTTP `
    --port 80 `
    --default-actions Type=forward,TargetGroupArn=$TgArn `
    --region $Region 2>$null

# 8. Create IAM Task Execution Role & Task Role (with Bedrock)
Write-Host ">>> Verifying IAM Roles for ECS & Bedrock..." -ForegroundColor Cyan

# Execution Role
$ExecRoleName = "ecsTaskExecutionRole"
$ExecRoleArn = (aws iam get-role --role-name $ExecRoleName --query "Role.Arn" --output text 2>$null)
if (-not $ExecRoleArn) {
    $TrustPolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    $ExecRoleArn = (aws iam create-role --role-name $ExecRoleName --assume-role-policy-document $TrustPolicy --query "Role.Arn" --output text)
    aws iam attach-role-policy --role-name $ExecRoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Bedrock Task Role
$BedrockRoleName = "ecsTaskBedrockRole"
$BedrockRoleArn = (aws iam get-role --role-name $BedrockRoleName --query "Role.Arn" --output text 2>$null)
if (-not $BedrockRoleArn) {
    $TrustPolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    $BedrockRoleArn = (aws iam create-role --role-name $BedrockRoleName --assume-role-policy-document $TrustPolicy --query "Role.Arn" --output text)
    
    $BedrockPolicy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["bedrock:InvokeModel","bedrock:InvokeModelWithResponseStream"],"Resource":"*"}]}'
    aws iam put-role-policy --role-name $BedrockRoleName --policy-name "BedrockInvokeAccess" --policy-document $BedrockPolicy
}

Write-Host "==========================================================================" -ForegroundColor Green
Write-Host " ALB Infrastructure Provisioned Successfully!" -ForegroundColor Green
Write-Host " ALB DNS Name       : http://$AlbDns" -ForegroundColor Yellow
Write-Host " Target Group ARN   : $TgArn" -ForegroundColor Yellow
Write-Host " ALB Security Group : $AlbSgId" -ForegroundColor Yellow
Write-Host " Task Security Group: $TaskSgId" -ForegroundColor Yellow
Write-Host " Subnets            : $Subnet1, $Subnet2" -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Green
