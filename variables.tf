#general var
variable "aws_region" {
  default = "eu-west-1"
}


#apply control (Partial Module Support)
variable "apply_serverless" {
  default = false
}

variable "apply_networking" {
  default = false
}

variable "apply_database" {
  default = false
}

variable "apply_eks" {
  default = true
}

variable "deploy_to_eks" {
  default = true
}

variable "monitor_eks" {
  default = true
}



#Networking
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  default = [
    "10.0.3.0/24",
    "10.0.4.0/24"
  ]
}

#serverless

variable "table_name" {
  default = "test_table"
}


#database
variable "db_name" {
  default = "tenantdb"
}
variable "db_username" {
  default = "have"
}
variable "db_password" {
  default = "patience"
}


#eks
variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "tester"
}

variable "cluster_namespace" {
  description = "The namespace where we wish to deploy everything"
  type        = string
  default     = "default"
}