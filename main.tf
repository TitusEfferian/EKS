module "vpc" {
  source = "./modules/vpc"
  count  = var.enable_vpc ? 1 : 0

  name                       = "${var.cluster_name}-vpc"
  cidr                       = var.vpc_cidr
  azs                        = var.vpc_azs
  single_nat_gateway         = var.single_nat_gateway
  enable_s3_gateway_endpoint = var.enable_s3_gateway_endpoint
  tags                       = var.tags
}

# EKS Auto Mode cluster + AWS Load Balancer Controller prerequisites.
# All actual resources live in ./modules/EKS; this root just wires variables through.
module "eks" {
  source = "./modules/EKS"
  count  = var.enable_eks ? 1 : 0

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  node_pools          = var.node_pools
  public_access_cidrs = var.public_access_cidrs

  vpc_id     = module.vpc[0].vpc_id
  subnet_ids = module.vpc[0].private_subnet_ids

  tags = var.tags
}

module "client_egress" {
  source = "./modules/client-egress"
  count  = var.enable_client_egress ? 1 : 0

  vpc_id                  = module.vpc[0].vpc_id
  public_subnet_ids_by_az = zipmap(module.vpc[0].azs, module.vpc[0].public_subnet_ids)
  clients                 = var.clients
  tags                    = var.tags
}
