provider "aws" {
  region = var.aws_region
}

#Part 1 
module "serverless" {
  count      = var.apply_serverless ? 1 : 0
  source     = "./modules/serverless"
  aws_region = var.aws_region
  table_name = "ItemsTable"
}

/*
#Part 2
module "monitoring" {
  source = "./modules/monitoring"
}
*/

#part 3 
module "networking" {
  count                = var.apply_networking || var.apply_database || var.apply_eks ? 1 : 0
  source               = "./modules/networking"
  vpc_name             = "TestVPC"
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  #Handler to handle Tag Deletion Loop
  create_eks = var.apply_eks
  eks_cluster_name = var.apply_eks ? var.cluster_name : ""
}

#part 4
module "database" {
  count       = var.apply_database ? 1 : 0
  source      = "./modules/database"
  aws_region  = var.aws_region
  db_name     = "tenantdb"
  vpc_id      = module.networking[0].vpc_id
  subnet_ids  = module.networking[0].private_subnet_ids
  db_username = var.db_username
  db_password = var.db_password

  depends_on = [module.networking]
}

#part 5
module "eks_infra" {
  count              = var.apply_eks ? 1 : 0
  source             = "./modules/eks/eks_infra"
  eks_cluster_name   = "tester"
  vpc_id             = module.networking[0].vpc_id
  aws_region         = var.aws_region
  private_subnet_ids = module.networking[0].private_subnet_ids
  public_subnet_ids  = module.networking[0].public_subnet_ids
  update_kubeconfig  = true

  depends_on = [module.networking]
}




provider "kubernetes" {
  host                   = var.apply_eks ? module.eks_infra[0].cluster_endpoint : null
  cluster_ca_certificate = var.apply_eks ? base64decode(module.eks_infra[0].cluster_ca_data) : null
  token                  = var.apply_eks ? module.eks_infra[0].cluster_token : null

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.apply_eks ? module.eks_infra[0].cluster_name : ""]
  }
}

module "eks_deployment" {
  count                  = var.deploy_to_eks ? 1 : 0
  source                 = "./modules/eks/eks_deployment"
  eks_cluster_name       = module.eks_infra[0].cluster_name
  cluster_endpoint       = module.eks_infra[0].cluster_endpoint
  cluster_namespace      = var.cluster_namespace
  depends_on             = [module.eks_infra]
}

module "eks_monitoring" {
  count = var.monitor_eks ? 1 : 0
  source = "./modules/eks/eks_monitoring"
  cluster_namespace = "monitoring"
  depends_on             = [module.eks_deployment]
}
