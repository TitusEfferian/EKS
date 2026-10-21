# Public hosted zone of the registered domain (titusefferian.dev). Looked up by
# name so this module does not depend on enable_route53_domain being on.
data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

# TLS certificate for the NiFi Ingress. Issued in the default provider's region
# (ap-northeast-1) because the ALB that terminates TLS lives in Tokyo. DNS
# validation writes the ACM CNAME into the zone above; keep it there, ACM needs
# it for automatic renewal.
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.1"

  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.this.zone_id

  # The module default is null (no validation); DNS is required here.
  validation_method                  = "DNS"
  create_route53_records             = true
  validation_allow_overwrite_records = true
  wait_for_validation                = true
  validation_timeout                 = "30m"

  key_algorithm = "RSA_2048"

  tags = var.tags
}

# ALB created by the AWS Load Balancer Controller for the eks-infra NiFi Ingress
# (named via alb.ingress.kubernetes.io/load-balancer-name). Only read when
# enable_dns = true: the lookup errors if the ALB does not exist.
data "aws_lb" "this" {
  count = var.enable_dns ? 1 : 0

  name = var.alb_name
}

# Alias A record nifi.<zone> -> ALB in the existing zone (v6 looks the zone up
# by name when create_zone = false). No AAAA: the ALB is IPv4-only.
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
