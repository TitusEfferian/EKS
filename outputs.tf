output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by the EKS Auto Mode nodes."
  value       = module.eks.node_iam_role_arn
}

output "configure_kubectl" {
  description = "Run this to point kubectl at the new cluster after apply."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

# --- Consumed by the separate AWS Load Balancer Controller Helm project ---

output "vpc_id" {
  description = "ID of the (default) VPC the cluster runs in. Pass as --set vpcId=... to the controller's Helm chart (Auto Mode blocks IMDS, so it can't be auto-discovered)."
  value       = data.aws_vpc.default.id
}

output "region" {
  description = "AWS region the cluster runs in. Pass as --set region=... to the controller's Helm chart (required because Auto Mode blocks IMDS)."
  value       = var.region
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider. Exported for reference/IRSA-based tooling; the self-managed controller here authenticates via EKS Pod Identity, not IRSA."
  value       = module.eks.oidc_provider_arn
}

output "aws_lb_controller_role_arn" {
  description = "ARN of the IAM role the AWS Load Balancer Controller assumes via its EKS Pod Identity association (kube-system/aws-load-balancer-controller)."
  value       = module.aws_lb_controller_pod_identity.iam_role_arn
}
