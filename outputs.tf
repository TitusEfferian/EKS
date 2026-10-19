output "cluster_name" {
  description = "EKS cluster name."
  value       = one(module.eks[*].cluster_name)
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = one(module.eks[*].cluster_arn)
}

output "cluster_endpoint" {
  description = "Endpoint for the Kubernetes API server."
  value       = one(module.eks[*].cluster_endpoint)
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = one(module.eks[*].cluster_certificate_authority_data)
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = one(module.eks[*].cluster_security_group_id)
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by the EKS Auto Mode nodes."
  value       = one(module.eks[*].node_iam_role_arn)
}

output "node_iam_role_name" {
  description = "Name of the EKS Auto Mode node IAM role. Set this as `nodeRole` in the egress-test Helm chart's NodeClass (Auto Mode takes the role NAME, not the ARN). Reusing this existing role means its EKS access entry already exists — no new access entry is required for the custom NodeClass."
  value       = one(module.eks[*].node_iam_role_name)
}

output "lbc_pod_identity_role_arn" {
  description = "IAM role ARN assumed by the AWS Load Balancer Controller via EKS Pod Identity. No SA annotation is needed (Pod Identity); shown for reference/verification."
  value       = one(module.eks[*].lbc_pod_identity_role_arn)
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster after apply (null when enable_eks = false)."
  value       = var.enable_eks ? "aws eks update-kubeconfig --region ${var.region} --name ${module.eks[0].cluster_name}" : null
}

# --- Dedicated VPC (./modules/vpc) ---
output "vpc_id" {
  description = "ID of the dedicated EKS VPC."
  value       = one(module.vpc[*].vpc_id)
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC."
  value       = one(module.vpc[*].vpc_cidr_block)
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes + pods)."
  value       = try(module.vpc[0].private_subnet_ids, [])
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT gateways + internet-facing load balancers)."
  value       = try(module.vpc[0].public_subnet_ids, [])
}

output "nat_public_ips" {
  description = "Elastic IP(s) of the NAT gateway(s) — the cluster's outbound egress address(es)."
  value       = try(module.vpc[0].nat_public_ips, [])
}

# --- Per-client dedicated egress (./modules/client-egress) ---
output "client_egress_ips" {
  description = "Map of client name -> dedicated static egress IP. Hand each client their IP to allowlist on their side. (Populated at apply time.)"
  value       = try(module.client_egress[0].egress_ips, {})
}

output "client_egress_details" {
  description = "Full per-client dedicated egress details (static IP, EIP allocation, dedicated subnet / NAT gateway / route table, AZ, CIDR)."
  value       = try(module.client_egress[0].clients, {})
}
