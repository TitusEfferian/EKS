# Tag every default-VPC subnet so the controller can auto-discover them when
# placing INTERNET-FACING load balancers. (kubernetes.io/role/elb = public.)
resource "aws_ec2_tag" "elb_role" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

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
