###############################################################################
# Per-client dedicated static egress IP.
#
# For each client this creates a dedicated egress path so the client sees a
# single, stable outbound IP (which they can allowlist on their side):
#
#   dedicated private subnet  ->  dedicated route table (0.0.0.0/0)
#     ->  dedicated NAT gateway  ->  dedicated Elastic IP  (= the static egress IP)
#
# The private subnet is tagged `egress-client = <name>`; the EKS Auto Mode
# NodeClass selects it via subnetSelectorTerms, so ONLY that client's nodes
# (and therefore their pods, via the VPC CNI) land there and egress through the
# client's dedicated NAT. This routes by SOURCE (which subnet the workload runs
# in) instead of by destination CIDR.
#
# The NAT gateway is placed in an EXISTING public subnet (already routed to the
# IGW) in the SAME AZ as the client's private subnet, to avoid cross-AZ NAT
# data-processing charges. A subnet and a NAT gateway are both AZ-scoped, so one
# client entry here == one AZ == one static IP (no multi-AZ HA — that would need
# one subnet/NAT/EIP per AZ and the client would allowlist several IPs).
###############################################################################

# Dedicated private workload subnet — EKS Auto Mode nodes for this client land here.
resource "aws_subnet" "this" {
  for_each = var.clients

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false # private: nodes get no public IP; egress is via the NAT

  tags = merge(var.tags, {
    Name                              = "${each.key}-egress"
    "egress-client"                   = each.key # the tag the NodeClass subnetSelectorTerms matches
    "kubernetes.io/role/internal-elb" = "1"
  })

  lifecycle {
    precondition {
      condition     = contains(keys(var.public_subnet_ids_by_az), each.value.az)
      error_message = "Client \"${each.key}\" targets AZ ${each.value.az}, which has no entry in public_subnet_ids_by_az. A public NAT gateway must be placed in a public subnet in the SAME AZ as the client's private subnet."
    }
  }
}

# Dedicated Elastic IP — THIS is the client's stable static egress IP.
# Treat it as the durable anchor: never taint/replace it or the client's IP changes.
resource "aws_eip" "this" {
  for_each = var.clients

  domain = "vpc"

  tags = merge(var.tags, {
    Name            = "${each.key}-egress-nat"
    "egress-client" = each.key
  })
}

# Dedicated NAT gateway, placed in the EXISTING public subnet of the client's AZ.
resource "aws_nat_gateway" "this" {
  for_each = var.clients

  allocation_id     = aws_eip.this[each.key].id
  subnet_id         = var.public_subnet_ids_by_az[each.value.az] # a PUBLIC subnet (routes to IGW)
  connectivity_type = "public"

  tags = merge(var.tags, {
    Name            = "${each.key}-egress"
    "egress-client" = each.key
  })
}

# Dedicated route table for the client's private subnet.
resource "aws_route_table" "this" {
  for_each = var.clients

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name            = "${each.key}-egress"
    "egress-client" = each.key
  })
}

# Default route: all egress from the client's subnet exits via its dedicated NAT.
# Standalone aws_route (not an inline route{} block) so the table composes cleanly
# and additional routes can be added later without churning the whole table.
resource "aws_route" "this_default" {
  for_each = var.clients

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# Bind the client's private subnet to its dedicated route table.
resource "aws_route_table_association" "this" {
  for_each = var.clients

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}
