module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.8"

  name = "${var.cluster_name}-aws-lbc"

  # Attach the module's curated AWS Load Balancer Controller IAM policy.
  attach_aws_lb_controller_policy = true

  # Bind the role to the controller's ServiceAccount via EKS Pod Identity.
  associations = {
    main = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}
