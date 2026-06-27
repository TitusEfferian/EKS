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
