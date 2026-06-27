variable "region" {
  description = "AWS region to deploy into. Must be the region that contains the default VPC you want to reuse."
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as the prefix for the IAM roles and security groups the module creates."
  type        = string
  default     = "tituseff-playground"
}

variable "kubernetes_version" {
  description = "Kubernetes control-plane version for the EKS cluster."
  type        = string
  default     = "1.36"
}

variable "node_pools" {
  description = "Built-in EKS Auto Mode (AWS-managed Karpenter) node pools to enable. Valid values: general-purpose, system."
  type        = list(string)
  default     = ["general-purpose", "system"]
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the cluster's PUBLIC Kubernetes API endpoint. Set this to your workstation IP in terraform.tfvars (copy terraform.tfvars.example)."
  type        = list(string)
  default     = ["203.0.113.0/32"] # placeholder (RFC 5737 doc range) — override in terraform.tfvars
}

variable "tags" {
  description = "Tags applied to every resource via the AWS provider's default_tags."
  type        = map(string)
  default = {
    Project     = "tituseff-playground"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "eks-auto-mode"
  }
}
