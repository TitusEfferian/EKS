# --- ACM certificate ---
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate. Set it as ingress.certificateArn in eks-infra nifi/values.yaml."
  value       = module.acm.acm_certificate_arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate (ISSUED once DNS validation completes)."
  value       = module.acm.acm_certificate_status
}

# --- DNS ---
output "fqdn" {
  description = "FQDN served by the NiFi Ingress."
  value       = var.domain_name
}

output "alb_dns_name" {
  description = "DNS name of the ALB the alias record points to (null when enable_dns = false)."
  value       = one(data.aws_lb.this[*].dns_name)
}
