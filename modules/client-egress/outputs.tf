output "egress_ips" {
  description = "Map of client name -> dedicated static egress IP. Hand each client their IP to allowlist on their side."
  value       = { for k, eip in aws_eip.this : k => eip.public_ip }
}

output "clients" {
  description = "Full per-client dedicated egress details (static IP, EIP allocation, dedicated subnet / NAT / route table, AZ, CIDR)."
  value = {
    for k, eip in aws_eip.this : k => {
      egress_ip      = eip.public_ip
      eip_allocation = eip.allocation_id
      subnet_id      = aws_subnet.this[k].id
      nat_gateway_id = aws_nat_gateway.this[k].id
      route_table_id = aws_route_table.this[k].id
      az             = var.clients[k].az
      cidr           = var.clients[k].cidr
    }
  }
}
