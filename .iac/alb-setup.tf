terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ----------------------------------------------------
# Variables
# ----------------------------------------------------
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_id" {
  type        = string
  description = "Default or Custom VPC ID in ap-south-1"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB (at least 2 in different AZs)"
}

variable "ecs_cluster_name" {
  type    = string
  default = "pratik-dev-cluster"
}

variable "service_name" {
  type    = string
  default = "springai-app-service-dev"
}

variable "ecr_image_uri" {
  type    = string
  default = "012751250391.dkr.ecr.ap-south-1.amazonaws.com/spring-app:latest"
}

# ----------------------------------------------------
# Security Groups
# ----------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "springai-alb-sg-${var.environment}"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    ="-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_task_sg" {
  name        = "springai-ecs-task-sg-${var.environment}"
  description = "Allow inbound traffic from ALB to ECS Task"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------------------------------
# Application Load Balancer (ALB)
# ----------------------------------------------------
resource "aws_lb" "main" {
  name               = "springai-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "app_tg" {
  name        = "springai-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/actuator/health"
    protocol            = "HTTP"
    port                = "8080"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ----------------------------------------------------
# IAM Roles for ECS
# ----------------------------------------------------
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_bedrock_role" {
  name = "ecsTaskBedrockRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "bedrock_access_policy" {
  name        = "BedrockModelInvokePolicy-${var.environment}"
  description = "Allow Spring AI task to call AWS Bedrock model"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_bedrock_attach" {
  role       = aws_iam_role.ecs_task_bedrock_role.name
  policy_arn = aws_iam_policy.bedrock_access_policy.arn
}

# ----------------------------------------------------
# Outputs
# ----------------------------------------------------
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public DNS name of the ALB"
}

output "target_group_arn" {
  value = aws_lb_target_group.app_tg.arn
}

output "alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}

output "ecs_task_security_group_id" {
  value = aws_security_group.ecs_task_sg.id
}
