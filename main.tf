# Reuse the existing default VPC and its subnets in the target region.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EKS cluster in Auto Mode, deployed into the default VPC.
#
# With compute_config.enabled = true the module also creates BOTH IAM roles
# automatically, with the correct managed policies:
#   - Cluster role: AmazonEKSClusterPolicy, AmazonEKSComputePolicy,
#     AmazonEKSBlockStoragePolicy, AmazonEKSLoadBalancingPolicy,
#     AmazonEKSNetworkingPolicy (+ the sts:TagSession trust Auto Mode requires).
#   - Auto Mode node role: AmazonEKSWorkerNodeMinimalPolicy,
#     AmazonEC2ContainerRegistryPullOnly.
# Karpenter, the built-in node pools, the EBS CSI driver and the load balancer
# controller are all AWS-managed in Auto Mode — nothing to install here.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # --- EKS Auto Mode: AWS-managed compute via built-in node pools ---
  compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # --- Networking: reuse the existing default VPC ---
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # --- Kubernetes API endpoint exposure ---
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.public_access_cidrs

  # --- Authentication: API access entries; grant the applier cluster-admin ---
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true
}
