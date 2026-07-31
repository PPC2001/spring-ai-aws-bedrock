#!/bin/bash
# ==============================================================================
# Automated Deployment Script for AWS ECS Fargate & ECR
# Usage: ./deploy-to-ecs.sh dev
# ==============================================================================

set -e

ENV=${1:-dev}
IAC_FILE="./.iac/${ENV}.json"

if [ ! -f "$IAC_FILE" ]; then
    echo "Error: Configuration file $IAC_FILE not found."
    exit 1
fi

echo ">>> Loading environment configuration from $IAC_FILE..."

ACCOUNT_ID=$(jq -r '.aws_account_id' "$IAC_FILE")
REGION=$(jq -r '.aws_region' "$IAC_FILE")
ECR_REPO=$(jq -r '.ecr_repository' "$IAC_FILE")
ECR_IMAGE=$(jq -r '.ecr_image_uri' "$IAC_FILE")
CLUSTER=$(jq -r '.ecs_cluster_name' "$IAC_FILE")
SERVICE=$(jq -r '.ecs_service_name' "$IAC_FILE")
TASK_FAMILY=$(jq -r '.task_family')

echo "=================================================================="
echo " Deploying to Environment : $ENV"
echo " ECR Repository           : $ECR_IMAGE"
echo " ECS Cluster              : $CLUSTER"
echo " AWS Region               : $REGION"
echo "=================================================================="

# 1. AWS ECR Login
echo ">>> Step 1: Logging into AWS ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# 2. Build Docker Image
echo ">>> Step 2: Building Docker image..."
docker build -t "$ECR_REPO:latest" .

# 3. Tag Docker Image
echo ">>> Step 3: Tagging Docker image for ECR..."
docker tag "$ECR_REPO:latest" "$ECR_IMAGE"

# 4. Push to ECR
echo ">>> Step 4: Pushing image to ECR ($ECR_IMAGE)..."
docker push "$ECR_IMAGE"

# 5. Create CloudWatch Log Group
echo ">>> Step 5: Ensuring CloudWatch Log Group exists..."
aws logs create-log-group --log-group-name "/ecs/$TASK_FAMILY" --region "$REGION" 2>/dev/null || true

# 6. Register Task Definition
echo ">>> Step 6: Registering ECS Task Definition..."
TASK_DEF_JSON=$(sed \
  -e "s/\${TASK_FAMILY}/$TASK_FAMILY/g" \
  -e "s/\${CPU}/$(jq -r '.cpu' "$IAC_FILE")/g" \
  -e "s/\${MEMORY}/$(jq -r '.memory' "$IAC_FILE")/g" \
  -e "s/\${AWS_ACCOUNT_ID}/$ACCOUNT_ID/g" \
  -e "s/\${CONTAINER_NAME}/$(jq -r '.container_name' "$IAC_FILE")/g" \
  -e "s|\${ECR_IMAGE_URI}|$ECR_IMAGE|g" \
  -e "s/\${CONTAINER_PORT}/$(jq -r '.container_port' "$IAC_FILE")/g" \
  -e "s/\${SPRING_PROFILES_ACTIVE}/$(jq -r '.env_variables.SPRING_PROFILES_ACTIVE' "$IAC_FILE")/g" \
  -e "s/\${AWS_REGION}/$REGION/g" \
  -e "s/\${BEDROCK_MODEL_ID}/$(jq -r '.env_variables.BEDROCK_MODEL_ID' "$IAC_FILE")/g" \
  -e "s/\${BEDROCK_TEMPERATURE}/$(jq -r '.env_variables.BEDROCK_TEMPERATURE' "$IAC_FILE")/g" \
  -e "s/\${BEDROCK_MAX_TOKENS}/$(jq -r '.env_variables.BEDROCK_MAX_TOKENS' "$IAC_FILE")/g" \
  -e "s/\${PORT}/$(jq -r '.env_variables.PORT' "$IAC_FILE")/g" \
  "./.iac/task-definition-template.json")

TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json "$TASK_DEF_JSON" --region "$REGION" --query "taskDefinition.taskDefinitionArn" --output text)
echo "Registered Task Definition ARN: $TASK_DEF_ARN"

# 7. Update ECS Service
echo ">>> Step 7: Deploying to ECS Cluster ($CLUSTER)..."
SERVICE_STATUS=$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" --query "services[0].status" --output text 2>/dev/null || echo "MISSING")

if [ "$SERVICE_STATUS" == "ACTIVE" ]; then
    echo "Updating existing ECS Service '$SERVICE'..."
    aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --task-definition "$TASK_DEF_ARN" --force-new-deployment --region "$REGION"
else
    echo "Service '$SERVICE' does not exist yet. Please run ALB setup first to provision ALB and ECS service."
fi

echo "=================================================================="
echo " Deployment completed!"
echo "=================================================================="
