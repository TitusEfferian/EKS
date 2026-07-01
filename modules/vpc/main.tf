locals {
  # Subnet math derived from var.cidr. For the default 10.0.0.0/16 this yields:
  #   private /19 (8,190 usable each): 10.0.0.0/19, 10.0.32.0/19, 10.0.64.0/19
  #   public  /22 (1,019 usable each): 10.0.96.0/22, 10.0.100.0/22, 10.0.104.0/22
  private_subnets = [for i in range(length(var.azs)) : cidrsubnet(var.cidr, 3, i)]
  public_subnets  = [for i in range(length(var.azs)) : cidrsubnet(var.cidr, 6, 24 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  # Required by EKS: enable_dns_hostnames defaults to FALSE on a new VPC; without
  # it nodes cannot register and interface-endpoint private DNS will not resolve.
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Load balancers/NAT get their own EIPs; nodes run in the private tier.
  map_public_ip_on_launch = false

  # Subnet auto-discovery tags for EKS Auto Mode's built-in load balancing /
  # the AWS Load Balancer Controller. These two role tags are the complete set
  # for Kubernetes >= 1.19 (legacy kubernetes.io/cluster/<name> is not needed).
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1" # internet-facing load balancers
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1" # internal load balancers
  }

  tags = var.tags
}

###############################################################################
# S3 Gateway VPC endpoint (free) — routes S3 traffic (which backs ECR image
# layers) through the AWS network instead of the NAT gateway. Interface
# endpoints for ecr/sts/ec2/elb/logs are included as commented examples.
###############################################################################
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.1"

  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = { Name = "${var.name}-s3-gateway" }
    }

    # --- Optional interface endpoints (uncomment to route AWS APIs off NAT) ---
    # Also uncomment subnet_ids + the security group block below when enabling.
    # ecr_api = { service = "ecr.api", private_dns_enabled = true }
    # ecr_dkr = { service = "ecr.dkr", private_dns_enabled = true }
    # sts     = { service = "sts", private_dns_enabled = true }
    # ec2     = { service = "ec2", private_dns_enabled = true }
    # elb     = { service = "elasticloadbalancing", private_dns_enabled = true }
    # logs    = { service = "logs", private_dns_enabled = true }
  }

  # Required only when interface endpoints (above) are enabled:
  # subnet_ids            = module.vpc.private_subnets
  # create_security_group = true
  # security_group_rules = {
  #   ingress_https = {
  #     description = "HTTPS from within the VPC"
  #     cidr_blocks = [module.vpc.vpc_cidr_block]
  #   }
  # }

  tags = var.tags
}
