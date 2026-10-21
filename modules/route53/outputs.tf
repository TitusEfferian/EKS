# --- Domain registration ---
output "domain_name" {
  description = "The registered domain name."
  value       = aws_route53domains_domain.this.domain_name
}

output "hosted_zone_id" {
  description = "ID of the hosted zone Route 53 Domains associated with the domain at registration (as reported by the registration resource)."
  value       = aws_route53domains_domain.this.hosted_zone_id
}

output "expiration_date" {
  description = "Date the current registration expires (auto-renew extends it when enabled)."
  value       = aws_route53domains_domain.this.expiration_date
}

output "creation_date" {
  description = "Date the domain was registered."
  value       = aws_route53domains_domain.this.creation_date
}

output "status_list" {
  description = "EPP status codes for the domain (e.g. clientTransferProhibited while transfer_lock is on)."
  value       = aws_route53domains_domain.this.status_list
}

# --- Adopted hosted zone (terraform-aws-modules/route53) ---
output "zone_id" {
  description = "ID of the adopted public hosted zone."
  value       = module.route53.id
}

output "zone_arn" {
  description = "ARN of the adopted public hosted zone."
  value       = module.route53.arn
}

output "zone_name" {
  description = "Name of the adopted public hosted zone."
  value       = module.route53.name
}

output "name_servers" {
  description = "Name servers of the adopted hosted zone (the domain is delegated to these at registration)."
  value       = module.route53.name_servers
}

output "records" {
  description = "Records created in the adopted hosted zone by the route53 module."
  value       = module.route53.records
}
