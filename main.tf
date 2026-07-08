module "vpc" {
  source = "./modules/vpc"

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

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  node_pools          = var.node_pools
  public_access_cidrs = var.public_access_cidrs

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  tags = var.tags
}

module "client_egress" {
  source = "./modules/client-egress"

  vpc_id                  = module.vpc.vpc_id
  public_subnet_ids_by_az = zipmap(module.vpc.azs, module.vpc.public_subnet_ids)
  clients                 = var.clients
  tags                    = var.tags
}
