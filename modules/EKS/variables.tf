variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as the prefix for the IAM roles and security groups the module creates."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes control-plane version for the EKS cluster. Leave null to fall back to the underlying module's own default."
  type        = string
  default     = null
}

variable "node_pools" {
  description = "Built-in EKS Auto Mode (AWS-managed Karpenter) node pools to enable. Valid values: general-purpose, system."
  type        = list(string)
  default     = ["general-purpose", "system"]

  validation {
    condition     = alltrue([for pool in var.node_pools : contains(["general-purpose", "system"], pool)])
    error_message = "node_pools entries must be one of: \"general-purpose\", \"system\"."
  }
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the cluster's PUBLIC Kubernetes API endpoint. Set this to your workstation IP in terraform.tfvars (copy terraform.tfvars.example)."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "public_access_cidrs entries must be valid CIDR blocks (e.g. \"1.2.3.4/32\")."
  }

  validation {
    condition     = !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "public_access_cidrs must not include \"0.0.0.0/0\" — restrict access to specific IPs/ranges."
  }
}

variable "tags" {
  description = "Tags applied to every resource via the AWS provider's default_tags."
  type        = map(string)
  default     = {}
}
