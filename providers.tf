provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

# Route 53 Domains is a us-east-1-only API, so domain registration (./modules/route53)
# uses this aliased provider. Hosted zones are global, so it serves the zone lookup too.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = var.tags
  }
}
