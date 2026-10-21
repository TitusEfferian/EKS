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

# --- Route 53 domain registration (./modules/route53) ---
variable "domain_name" {
  description = "Domain to register via Route 53 Domains when enable_route53_domain = true. Lowercase, no trailing dot."
  type        = string
  default     = "titusefferian.dev"

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase, fully qualified domain name without a trailing dot (e.g. \"titusefferian.dev\")."
  }
}

variable "domain_duration_in_years" {
  description = "Number of years to register the domain for (1-10). Each year is billed up front and is non-refundable."
  type        = number
  default     = 1

  validation {
    condition     = var.domain_duration_in_years >= 1 && var.domain_duration_in_years <= 10 && floor(var.domain_duration_in_years) == var.domain_duration_in_years
    error_message = "domain_duration_in_years must be a whole number between 1 and 10."
  }
}

variable "domain_auto_renew" {
  description = "Whether Route 53 automatically renews the domain before it expires (renewals are billed to the account)."
  type        = bool
  default     = true
}

variable "domain_contact" {
  description = <<-EOT
    Contact used for the registrant, admin, tech and billing roles of the
    domain (WHOIS privacy is enabled for all). Required when
    enable_route53_domain = true. Set it ONLY in the gitignored
    terraform.tfvars � this repo is public. contact_type is one of PERSON,
    COMPANY, ASSOCIATION, PUBLIC_BODY or RESELLER (organization_name required
    unless PERSON); phone_number/fax use "+<country code>.<number>"
    (e.g. "+81.312345678"); country_code is ISO 3166-1 alpha-2 (e.g. "JP").
    The registrant email must be verified within 15 days of registration or
    the domain is suspended.
  EOT
  type = object({
    contact_type      = optional(string, "PERSON")
    first_name        = string
    last_name         = string
    organization_name = optional(string)
    email             = string
    phone_number      = string
    fax               = optional(string)
    address_line_1    = string
    address_line_2    = optional(string)
    city              = string
    state             = optional(string)
    zip_code          = string
    country_code      = string
  })
  default   = null
  sensitive = true

  # Conditionals (not ||) so a null contact never gets dereferenced.
  validation {
    condition     = !var.enable_route53_domain || var.domain_contact != null
    error_message = "domain_contact must be set (in terraform.tfvars) when enable_route53_domain = true."
  }
  validation {
    condition     = var.domain_contact == null ? true : contains(["PERSON", "COMPANY", "ASSOCIATION", "PUBLIC_BODY", "RESELLER"], var.domain_contact.contact_type)
    error_message = "domain_contact.contact_type must be one of PERSON, COMPANY, ASSOCIATION, PUBLIC_BODY or RESELLER."
  }
  validation {
    condition     = var.domain_contact == null ? true : (var.domain_contact.contact_type == "PERSON" || var.domain_contact.organization_name != null)
    error_message = "domain_contact.organization_name is required when domain_contact.contact_type is not PERSON."
  }
  validation {
    condition     = var.domain_contact == null ? true : can(regex("^\\+[0-9]{1,3}\\.[0-9]{1,20}$", var.domain_contact.phone_number))
    error_message = "domain_contact.phone_number must use the \"+<country code>.<number>\" format, e.g. \"+81.312345678\"."
  }
  validation {
    condition     = var.domain_contact == null ? true : (var.domain_contact.fax == null ? true : can(regex("^\\+[0-9]{1,3}\\.[0-9]{1,20}$", var.domain_contact.fax)))
    error_message = "domain_contact.fax, when set, must use the \"+<country code>.<number>\" format, e.g. \"+81.312345678\"."
  }
  validation {
    condition     = var.domain_contact == null ? true : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.domain_contact.email))
    error_message = "domain_contact.email must be a valid email address (it receives the registrant verification email)."
  }
  validation {
    condition     = var.domain_contact == null ? true : can(regex("^[A-Z]{2}$", var.domain_contact.country_code))
    error_message = "domain_contact.country_code must be an uppercase ISO 3166-1 alpha-2 code, e.g. \"JP\"."
  }
}

variable "domain_records" {
  description = <<-EOT
    DNS records to create in the domain's adopted hosted zone, passed through
    to terraform-aws-modules/route53's `records` input. Apex records need
    `full_name = "<domain>"`. Empty by default (the zone keeps only the NS/SOA
    records Route 53 created).
  EOT
  type        = any
  default     = {}
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

variable "enable_route53_domain" {
  description = <<-EOT
    Register var.domain_name via Route 53 Domains and adopt its auto-created
    hosted zone (./modules/route53). WARNING: true PURCHASES the domain
    (non-refundable). Requires domain_contact. Flipping back to false will NOT
    deregister it: the module's prevent_destroy guard makes the plan fail
    (see README "Domain registration" for the deliberate teardown path).
  EOT
  type        = bool
  default     = false
}
