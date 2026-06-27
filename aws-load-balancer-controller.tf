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

# --- Public subnet discovery tags --------------------------------------------
# The controller auto-discovers subnets for internet-facing ALBs by these tags.
# The default VPC's subnets are untagged, so tag all of them here.
#
# kubernetes.io/role/elb = 1  -> eligible for PUBLIC (internet-facing) load balancers.
resource "aws_ec2_tag" "subnet_elb_role" {
  for_each = toset(data.aws_subnets.default.ids)

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# kubernetes.io/cluster/<name> = shared -> associates the subnet with this cluster.
resource "aws_ec2_tag" "subnet_cluster" {
  for_each = toset(data.aws_subnets.default.ids)

  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

# --- Output ------------------------------------------------------------------
output "lbc_pod_identity_role_arn" {
  description = "IAM role ARN assumed by the AWS Load Balancer Controller via EKS Pod Identity. No SA annotation is needed (Pod Identity); shown for reference/verification."
  value       = module.aws_lb_controller_pod_identity.iam_role_arn
}
