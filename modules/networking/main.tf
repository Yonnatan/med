#Check if EKS is being created , and if it does add relevant tags to subnets
locals {
  eks_cluster_tag = var.create_eks ? { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" } : {}

  eks_public_subnet_tags = var.create_eks ? { "kubernetes.io/role/elb" = "1" } : {}

  eks_private_subnet_tags = var.create_eks ? { "kubernetes.io/role/internal-elb" = "1" } : {}
}


# Data Source for Availability Zones
# Used by: The VPC module to determine which Availability Zones to use
data "aws_availability_zones" "available" {}

# VPC Module Definition
# Used by: Creates a VPC with public and private subnets, and optionally a NAT Gateway
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.2.0"

  name = var.vpc_name
  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  public_subnet_tags  = merge(var.public_subnet_tags, local.eks_cluster_tag, local.eks_public_subnet_tags)
  private_subnet_tags = merge(var.private_subnet_tags, local.eks_cluster_tag, local.eks_private_subnet_tags)

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
}

# Security Group for Lambda Function
# Used by: Lambda function to allow outbound traffic to the internet via the NAT Gateway
resource "aws_security_group" "lambda_sg" {
  name   = "networking_lambda_sg"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lambda Function Definition
# Used by: Tests connectivity to the internet through the NAT Gateway
resource "aws_lambda_function" "item_function" {
  filename         = "${path.module}/networking_lambda_function.zip"
  function_name    = "networkFunction"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "networking_lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("${path.module}/networking_lambda_function.zip")

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# IAM Role for Lambda Function
# Used by: Allows the Lambda function to assume the role necessary to execute and access AWS resources
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda to Access VPC
# Used by: Grants Lambda permissions to manage network interfaces in the VPC
resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "lambda_vpc_policy"
  description = "IAM policy for Lambda to manage network interfaces in VPC"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*"
      }
    ]
  })
}

# IAM Policy Attachment for Lambda Execution
# Used by: Attaches the basic Lambda execution policy and the VPC access policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}
