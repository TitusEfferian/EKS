output "vpc_id" {
  description = "ID of the VPC. Feed to the EKS module's vpc_id."
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "ARN of the VPC."
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC (useful for security-group rules)."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs (nodes + pods). Feed to the EKS module's subnet_ids."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT gateways + internet-facing load balancers)."
  value       = module.vpc.public_subnets
}

output "private_route_table_ids" {
  description = "Private route table IDs (targeted by the S3 gateway endpoint)."
  value       = module.vpc.private_route_table_ids
}

output "nat_public_ips" {
  description = "Elastic IP(s) of the NAT gateway(s) — the cluster's outbound egress address(es)."
  value       = module.vpc.nat_public_ips
}

output "igw_id" {
  description = "ID of the internet gateway."
  value       = module.vpc.igw_id
}

output "azs" {
  description = "Availability Zones the VPC subnets span."
  value       = module.vpc.azs
}
