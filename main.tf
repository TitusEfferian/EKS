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

module "route53" {
  source = "./modules/route53"
  count  = var.enable_route53_domain ? 1 : 0

  providers = {
    aws = aws.us_east_1
  }

  domain_name       = var.domain_name
  duration_in_years = var.domain_duration_in_years
  auto_renew        = var.domain_auto_renew
  contact           = var.domain_contact
  records           = var.domain_records
  tags              = var.tags
}

module "nifi_ingress" {
  source = "./modules/nifi-ingress"
  count  = var.enable_nifi_ingress ? 1 : 0

  domain_name = var.nifi_domain_name
  zone_name   = var.domain_name
  enable_dns  = var.enable_nifi_dns
  alb_name    = var.nifi_alb_name
  tags        = var.tags
}
