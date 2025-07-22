output "payment_lb_dns" {
  description = "The DNS name of the order service load balancer"
  value       = aws_lb.payment_lb.dns_name
}
