# EKS Auto Mode cluster + AWS Load Balancer Controller prerequisites.
# All actual resources live in ./modules/EKS; this root just wires variables through.
module "eks" {
  source = "./modules/EKS"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  node_pools          = var.node_pools
  public_access_cidrs = var.public_access_cidrs
  tags                = var.tags
}
