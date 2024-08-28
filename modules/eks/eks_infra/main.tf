#1 Setting up the cluster
#-------------------------------------

# EKS Cluster Resource
# Creates an EKS cluster with specified name, role, and VPC configuration
resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.main.arn

  vpc_config {
    subnet_ids = var.private_subnet_ids
  }
}

# IAM Role for EKS Cluster
# Defines IAM role to be assumed by the EKS cluster
resource "aws_iam_role" "main" {
  name = "test-cluster-role-1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# EKS Cluster Policy Attachment
# Attaches AmazonEKSClusterPolicy to the EKS IAM role
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.main.name
}

# EKS Service Policy Attachment
# Attaches AmazonEKSServicePolicy to the EKS IAM role
resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.main.name
}

# Kubeconfig Update Resource
# Conditionally updates kubeconfig to connect to the EKS cluster
resource "null_resource" "update_kubeconfig" {
  count = var.update_kubeconfig ? 1 : 0

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
  }

  depends_on = [aws_eks_cluster.main]
}

# EKS Node Group Resource
# Creates a node group for the EKS cluster with specified instance types and scaling configuration
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "example-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]
  ami_type       = "AL2_x86_64"

  tags = {
    "Name" = "${var.eks_cluster_name}-worker-node"
  }
}

# IAM Role for EKS Node Group
# Defines IAM role to be assumed by EKS worker nodes
resource "aws_iam_role" "eks_nodes" {
  name = "${var.eks_cluster_name}-worker-nodes"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Worker Node Policy Attachment
# Attaches AmazonEKSWorkerNodePolicy to the EKS Node Group IAM role
resource "aws_iam_role_policy_attachment" "eks_nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

# CNI Policy Attachment for Worker Nodes
# Attaches AmazonEKS_CNI_Policy to the EKS Node Group IAM role
resource "aws_iam_role_policy_attachment" "eks_nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

# EC2 Container Registry Read-Only Policy Attachment
# Attaches AmazonEC2ContainerRegistryReadOnly policy to the EKS Node Group IAM role
resource "aws_iam_role_policy_attachment" "eks_nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# OIDC TLS Certificate Data
# Retrieves the TLS certificate for the EKS cluster's OIDC identity provider
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# OIDC Provider for EKS Cluster
# Creates an IAM OIDC provider for the EKS cluster to enable IAM roles for service accounts
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
}

data "aws_eks_cluster_auth" "main" {
  name = data.aws_eks_cluster.main.name
}