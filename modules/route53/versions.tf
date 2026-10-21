terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.28: floor required by terraform-aws-modules/route53 v6.5.1.
      # (aws_route53domains_domain itself only needs >= 5.85.)
      version = "~> 6.28"
    }
  }
}
