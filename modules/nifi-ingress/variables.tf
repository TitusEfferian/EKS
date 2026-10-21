variable "domain_name" {
  description = "FQDN served by the NiFi Ingress (e.g. \"nifi.titusefferian.dev\"). Used as the ACM certificate's domain and the alias record's name."
  type        = string
}

variable "zone_name" {
  description = "Name of the existing public Route 53 hosted zone that domain_name belongs to (e.g. \"titusefferian.dev\")."
  type        = string
}

variable "enable_dns" {
  description = "Create the alias A record domain_name -> ALB. Requires alb_name to name an ALB that already exists (the data source lookup errors otherwise)."
  type        = bool
  default     = false
}

variable "alb_name" {
  description = "Name of the ALB the AWS Load Balancer Controller created for the NiFi Ingress (its alb.ingress.kubernetes.io/load-balancer-name annotation). Only used when enable_dns = true."
  type        = string
  default     = ""

  validation {
    condition     = length(var.alb_name) <= 32
    error_message = "alb_name must be at most 32 characters (the ELB name limit)."
  }
}

variable "tags" {
  description = "Tags merged onto the certificate and records (in addition to the AWS provider's default_tags)."
  type        = map(string)
  default     = {}
}
