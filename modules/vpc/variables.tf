variable "name" {
  description = "Name prefix for the VPC and its subnets/route tables/NAT gateways (e.g. \"<cluster>-vpc\")."
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC. Must not overlap peered/on-prem ranges or the account's default VPC (172.31.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block (e.g. \"10.0.0.0/16\")."
  }
}

variable "azs" {
  description = "Availability Zones to spread subnets across. Tokyo (ap-northeast-1) exposes 1a/1c/1d only (no 1b). EKS requires at least two."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "azs must contain at least two Availability Zones."
  }
}

variable "single_nat_gateway" {
  description = "true = ONE NAT gateway shared by all AZs (1 Elastic IP, lowest cost, single-AZ point of failure). false = ONE NAT gateway per AZ (HA, no cross-AZ egress charges; needs one free Elastic IP per AZ)."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Create the free S3 Gateway VPC endpoint so ECR image-layer pulls (backed by S3) skip paid NAT data processing."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for the VPC resources (merged on top of the provider's default_tags)."
  type        = map(string)
  default     = {}
}
