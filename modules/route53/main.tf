resource "aws_route53domains_domain" "this" {
  domain_name       = var.domain_name
  duration_in_years = var.duration_in_years
  auto_renew        = var.auto_renew

  transfer_lock = true

  admin_privacy      = true
  registrant_privacy = true
  tech_privacy       = true
  billing_privacy    = true

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

  timeouts {
    create = "60m"
  }

  lifecycle {
    prevent_destroy = true
  }
}

module "route53" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  create_zone = false
  name        = aws_route53domains_domain.this.domain_name

  records = var.records

  tags = var.tags

  depends_on = [aws_route53domains_domain.this]
}
