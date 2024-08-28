variable "vpc_name" {
  description = "Name of the VPC"
  default     = "TestVPC"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  description = "CIDR block for public subnet"
}

variable "private_subnet_cidrs" {
  description = "CIDR block for private subnet"
}

variable "enable_nat_gateway" {
  default = true
}

variable "single_nat_gateway" {
  default = true
}

variable "enable_dns_hostnames" {
  default = true
}

#Relevant to Tag Creations in case of EKS cluster creation

variable "create_eks" {
  description = "Whether to create EKS tags"
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = ""
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default     = {}
}