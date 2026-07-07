# EKS cluster in Auto Mode, deployed into the dedicated VPC's private subnets.
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
  version = "21.24.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # --- EKS Auto Mode: AWS-managed compute via built-in node pools ---
  compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # --- Networking: dedicated VPC, PRIVATE subnets (nodes egress via the NAT) ---
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # --- Kubernetes API endpoint exposure ---
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = var.public_access_cidrs

  # --- Authentication: API access entries; grant the applier cluster-admin ---
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  tags = var.tags
}
