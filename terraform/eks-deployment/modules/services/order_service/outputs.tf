output "order_lb_dns" {
  description = "The DNS name of the order service load balancer"
  value       = aws_lb.order_lb.dns_name
}
