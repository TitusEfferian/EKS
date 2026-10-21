###############################################################################
# Route 53 Domains registration + adoption of the auto-created hosted zone.
#
# WARNING: applying this module PURCHASES the domain. Registration is
# non-refundable, and destroying aws_route53domains_domain DEREGISTERS the
# domain (no refund). prevent_destroy below makes Terraform refuse to plan a
# destroy until that guard is removed on purpose.
#
# The Route 53 Domains API only exists in us-east-1, so the caller must pass a
# us-east-1 provider (root: `providers = { aws = aws.us_east_1 }`). Route 53
# hosted zones are global, so the same provider works for the zone lookup too.
###############################################################################

# --- Domain registration ---
# No terraform-aws-modules module supports registration, so this is the raw
# provider resource. No name_server blocks: Route 53 creates a public hosted
# zone at registration and points the domain's NS records at it, which is
# exactly the zone the route53 module below adopts.
resource "aws_route53domains_domain" "this" {
  domain_name       = var.domain_name
  duration_in_years = var.duration_in_years
  auto_renew        = var.auto_renew

  # Registrar lock: blocks unauthorized transfers away from Route 53.
  transfer_lock = true

  # WHOIS privacy on for every contact. AWS requires admin/registrant/tech
  # privacy to match, so they are all pinned to true.
  admin_privacy      = true
  registrant_privacy = true
  tech_privacy       = true
  billing_privacy    = true

  # One contact (var.contact) is used for all four roles. Optional fields left
  # null are simply omitted from the API request.
  registrant_contact {
    contact_type      = var.contact.contact_type
    first_name        = var.contact.first_name
    last_name         = var.contact.last_name
    organization_name = var.contact.organization_name
    email             = var.contact.email
    phone_number      = var.contact.phone_number
    fax               = var.contact.fax
    address_line_1    = var.contact.address_line_1
    address_line_2    = var.contact.address_line_2
    city              = var.contact.city
    state             = var.contact.state
    zip_code          = var.contact.zip_code
    country_code      = var.contact.country_code
  }

  admin_contact {
    contact_type      = var.contact.contact_type
    first_name        = var.contact.first_name
    last_name         = var.contact.last_name
    organization_name = var.contact.organization_name
    email             = var.contact.email
    phone_number      = var.contact.phone_number
    fax               = var.contact.fax
    address_line_1    = var.contact.address_line_1
    address_line_2    = var.contact.address_line_2
    city              = var.contact.city
    state             = var.contact.state
    zip_code          = var.contact.zip_code
    country_code      = var.contact.country_code
  }

  tech_contact {
    contact_type      = var.contact.contact_type
    first_name        = var.contact.first_name
    last_name         = var.contact.last_name
    organization_name = var.contact.organization_name
    email             = var.contact.email
    phone_number      = var.contact.phone_number
    fax               = var.contact.fax
    address_line_1    = var.contact.address_line_1
    address_line_2    = var.contact.address_line_2
    city              = var.contact.city
    state             = var.contact.state
    zip_code          = var.contact.zip_code
    country_code      = var.contact.country_code
  }

  billing_contact {
    contact_type      = var.contact.contact_type
    first_name        = var.contact.first_name
    last_name         = var.contact.last_name
    organization_name = var.contact.organization_name
    email             = var.contact.email
    phone_number      = var.contact.phone_number
    fax               = var.contact.fax
    address_line_1    = var.contact.address_line_1
    address_line_2    = var.contact.address_line_2
    city              = var.contact.city
    state             = var.contact.state
    zip_code          = var.contact.zip_code
    country_code      = var.contact.country_code
  }

  tags = var.tags

  # Registration is asynchronous on the AWS side and can take well over the
  # 30m default, so give create more headroom.
  timeouts {
    create = "60m"
  }

  lifecycle {
    # A destroy deregisters the domain with no refund. To really tear it down,
    # remove this guard deliberately (see README "Domain registration").
    prevent_destroy = true
  }
}

# --- Hosted zone (adopted, not created) ---
# create_zone = false: the zone already exists because Route 53 auto-created it
# at registration. Creating a second zone would leave the domain delegated to
# the auto-created one (or require name_server blocks + a second zone's cost).
# depends_on defers the zone lookup until the registration has completed.
module "route53" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  create_zone = false
  name        = aws_route53domains_domain.this.domain_name

  records = var.records

  tags = var.tags

  depends_on = [aws_route53domains_domain.this]
}
