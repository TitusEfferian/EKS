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

output "node_iam_role_name" {
  description = "Name of the IAM role used by the EKS Auto Mode nodes. Consumed by a custom NodeClass.spec.role (Auto Mode takes the role NAME, not the ARN). Reusing this existing role means its EKS access entry already exists."
  value       = module.eks.node_iam_role_name
}

output "lbc_pod_identity_role_arn" {
  description = "IAM role ARN assumed by the AWS Load Balancer Controller via EKS Pod Identity. No SA annotation is needed (Pod Identity); shown for reference/verification."
  value       = module.aws_lb_controller_pod_identity.iam_role_arn
}
