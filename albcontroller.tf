# ---------------------------------------------------------------------------
# Self-managed AWS Load Balancer Controller — CLUSTER PREP (coexistence).
#
# EKS Auto Mode stays fully enabled, so its AWS-managed load balancing capability
# is still on. We do NOT disable it (the provider forbids splitting the Auto Mode
# compute/block-storage/load-balancing toggles). Instead, a self-managed AWS Load
# Balancer Controller is installed LATER (separate Helm project) and coexists with
# the built-in one, scoped by IngressClass / loadBalancerClass.
#
# This file preps the cluster only:
#   1. Subnet discovery tags for internet-facing ALB/NLB placement.
#   2. The IAM role + EKS Pod Identity association the controller's ServiceAccount
#      (kube-system/aws-load-balancer-controller) assumes at runtime.
# No Helm release, IngressClass, or Ingress/Service objects are created here.
# ---------------------------------------------------------------------------

# Tag every default-VPC subnet so the controller can auto-discover them when
# placing INTERNET-FACING load balancers. (kubernetes.io/role/elb = public.)
resource "aws_ec2_tag" "elb_role" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# IAM via EKS Pod Identity (NOT IRSA). The official pod-identity module creates:
#   - an IAM role trusting pods.eks.amazonaws.com,
#   - the curated AWS Load Balancer Controller managed policy attachment,
#   - the aws_eks_pod_identity_association mapping the cluster + namespace +
#     ServiceAccount to that role.
# The Kubernetes ServiceAccount does not need to exist yet; Helm creates it later
# and the association binds it to the role by name.
module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.0"

  name            = "${var.cluster_name}-aws-lbc"
  use_name_prefix = false # exact, predictable role name (no random suffix)

  # Curated AWS Load Balancer Controller IAM policy.
  attach_aws_lb_controller_policy = true

  # Create the Pod Identity association for the controller's ServiceAccount.
  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}
