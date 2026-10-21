data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.1"

  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.this.zone_id

  validation_method                  = "DNS"
  create_route53_records             = true
  validation_allow_overwrite_records = true
  wait_for_validation                = true
  validation_timeout                 = "30m"

  key_algorithm = "RSA_2048"

  tags = var.tags
}

data "aws_lb" "this" {
  count = var.enable_dns ? 1 : 0

  name = var.alb_name
}

module "dns" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  create      = var.enable_dns
  create_zone = false
  name        = var.zone_name

  records = var.enable_dns ? {
    nifi_a = {
      full_name = var.domain_name
      type      = "A"
      alias = {
        name                   = one(data.aws_lb.this[*].dns_name)
        zone_id                = one(data.aws_lb.this[*].zone_id)
        evaluate_target_health = true
      }
    }
  } : {}

  tags = var.tags
}
