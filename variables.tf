variable "region" {
  description = "AWS region to deploy into. Must match the region of vpc_azs (the dedicated EKS VPC is created here)."
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

variable "vpc_cidr" {
  description = "CIDR block for the dedicated EKS VPC. Chosen to avoid overlap with the account's default VPC (172.31.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability Zones for the VPC subnets. Tokyo (ap-northeast-1) exposes 1a/1c/1d only (no 1b)."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (1 Elastic IP, cheapest, single-AZ SPOF). false = one NAT gateway per AZ (HA; needs one free Elastic IP per AZ)."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Create the free S3 Gateway VPC endpoint so ECR image pulls skip paid NAT data processing."
  type        = bool
  default     = true
}

variable "clients" {
  description = <<-EOT
    Clients that need a DEDICATED static egress IP (see ./modules/client-egress).
    Map key = client name; it becomes the `egress-client` subnet tag that the EKS
    Auto Mode NodeClass selects on. Each entry provisions a dedicated private
    subnet + route table + NAT gateway + Elastic IP in ONE AZ (one entry = one
    static egress IP). CIDRs must be carved from the VPC's free space
    (10.0.108.0/22+ for the default 10.0.0.0/16) and must NOT overlap the
    module.vpc private/public subnets.
  EOT
  type = map(object({
    az   = string
    cidr = string
  }))
  default = {
    "destination-a" = {
      az   = "ap-northeast-1a"
      cidr = "10.0.108.0/24"
    }
    "destination-b" = {
      az   = "ap-northeast-1a"
      cidr = "10.0.109.0/24"
    }
  }

  validation {
    condition     = alltrue([for k, v in var.clients : can(cidrhost(v.cidr, 0))])
    error_message = "Every client's cidr must be a valid IPv4 CIDR block (e.g. 10.0.108.0/24)."
  }
  validation {
    condition     = alltrue([for k, v in var.clients : contains(["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"], v.az)])
    error_message = "Every client's az must be one of ap-northeast-1a / ap-northeast-1c / ap-northeast-1d (Tokyo has no 1b), and must match an AZ in var.vpc_azs."
  }
}

# --- Module toggles ---
variable "enable_vpc" {
  description = "Create the dedicated VPC (./modules/vpc). Required by enable_eks and enable_client_egress. Flip to false to destroy it."
  type        = bool
  default     = false
}

variable "enable_eks" {
  description = "Create the EKS Auto Mode cluster + LBC Pod Identity (./modules/EKS). Requires enable_vpc = true. Flip to false to destroy the cluster."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_eks || var.enable_vpc
    error_message = "enable_eks = true requires enable_vpc = true (the cluster is deployed into module.vpc's private subnets)."
  }
}

variable "enable_client_egress" {
  description = "Create per-client dedicated static egress subnets/NAT/EIPs (./modules/client-egress). Requires enable_vpc = true. Flip to false to destroy them."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_client_egress || var.enable_vpc
    error_message = "enable_client_egress = true requires enable_vpc = true (egress NATs live in module.vpc's public subnets)."
  }
}
