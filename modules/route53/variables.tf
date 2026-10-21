variable "domain_name" {
  description = "Domain name to register via Route 53 Domains (e.g. \"titusefferian.dev\"). The TLD must be one Route 53 supports."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase, fully qualified domain name without a trailing dot (e.g. \"titusefferian.dev\")."
  }
}

variable "duration_in_years" {
  description = "Number of years to register the domain for. Route 53 allows 1-10 (some TLDs have narrower limits)."
  type        = number
  default     = 1

  validation {
    condition     = var.duration_in_years >= 1 && var.duration_in_years <= 10 && floor(var.duration_in_years) == var.duration_in_years
    error_message = "duration_in_years must be a whole number between 1 and 10."
  }
}

variable "auto_renew" {
  description = "Whether Route 53 automatically renews the registration before it expires (renewals are billed to the account)."
  type        = bool
  default     = true
}

variable "contact" {
  description = <<-EOT
    Contact used for the registrant, admin, tech and billing roles. WHOIS
    privacy is enabled for all of them, but AWS (and the registry) still hold
    the real data, and the registrant email must be verified within 15 days or
    the domain is suspended. contact_type is one of PERSON, COMPANY,
    ASSOCIATION, PUBLIC_BODY or RESELLER; organization_name is required unless
    PERSON. phone_number/fax use the "+<country code>.<number>" format
    (e.g. "+81.312345678"). country_code is an ISO 3166-1 alpha-2 code.
    NEVER commit real values — this repo is public.
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
  sensitive = true

  validation {
    condition     = contains(["PERSON", "COMPANY", "ASSOCIATION", "PUBLIC_BODY", "RESELLER"], var.contact.contact_type)
    error_message = "contact.contact_type must be one of PERSON, COMPANY, ASSOCIATION, PUBLIC_BODY or RESELLER."
  }
  validation {
    condition     = var.contact.contact_type == "PERSON" || var.contact.organization_name != null
    error_message = "contact.organization_name is required when contact.contact_type is not PERSON."
  }
  validation {
    condition     = can(regex("^\\+[0-9]{1,3}\\.[0-9]{1,20}$", var.contact.phone_number))
    error_message = "contact.phone_number must use the \"+<country code>.<number>\" format, e.g. \"+81.312345678\"."
  }
  validation {
    condition     = var.contact.fax == null ? true : can(regex("^\\+[0-9]{1,3}\\.[0-9]{1,20}$", var.contact.fax))
    error_message = "contact.fax, when set, must use the \"+<country code>.<number>\" format, e.g. \"+81.312345678\"."
  }
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.contact.email))
    error_message = "contact.email must be a valid email address (it receives the registrant verification email)."
  }
  validation {
    condition     = can(regex("^[A-Z]{2}$", var.contact.country_code))
    error_message = "contact.country_code must be an uppercase ISO 3166-1 alpha-2 code, e.g. \"JP\"."
  }
}

variable "records" {
  description = <<-EOT
    Records to create in the adopted hosted zone, passed straight through to
    terraform-aws-modules/route53's `records` input (map keyed by an arbitrary
    name). Apex records need `full_name = "<domain>"`. Note .dev is
    HSTS-preloaded, so any website served here must use HTTPS.
  EOT
  type        = any
  default     = {}
}

variable "tags" {
  description = "Tags merged onto the domain registration and the route53 module's resources (in addition to the AWS provider's default_tags)."
  type        = map(string)
  default     = {}
}
