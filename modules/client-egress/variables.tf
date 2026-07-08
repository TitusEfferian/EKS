variable "vpc_id" {
  description = "ID of the VPC to create the per-client dedicated egress resources in."
  type        = string
}

variable "public_subnet_ids_by_az" {
  description = "Map of availability zone -> public subnet ID. Each per-client NAT gateway is placed in the public subnet of that client's AZ (the subnet must already route 0.0.0.0/0 to the internet gateway). Build with zipmap(module.vpc.azs, module.vpc.public_subnet_ids)."
  type        = map(string)
}

variable "clients" {
  description = "Per-client dedicated egress config. Map key = client name (used for the Name/egress-client tags the EKS Auto Mode NodeClass selects on). Each client gets a dedicated private subnet + route table + NAT gateway + Elastic IP (one entry = one AZ = one static egress IP)."
  type = map(object({
    az   = string
    cidr = string
  }))

  validation {
    condition     = alltrue([for k, v in var.clients : can(cidrhost(v.cidr, 0))])
    error_message = "Every client's cidr must be a valid IPv4 CIDR block (e.g. 10.0.108.0/24), carved from the VPC's free space and non-overlapping with the module.vpc subnets."
  }
}

variable "tags" {
  description = "Tags merged onto the created resources (in addition to the AWS provider's default_tags)."
  type        = map(string)
  default     = {}
}
