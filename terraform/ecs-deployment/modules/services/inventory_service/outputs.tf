output "inventory_lb_dns" {
  description = "The DNS name of the inventory service load balancer"
  value       = aws_lb.inventory_lb.dns_name
}
