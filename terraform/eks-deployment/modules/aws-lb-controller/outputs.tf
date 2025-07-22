output "role_arn" {
  description = "ARN of the IAM role used by the AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "policy_arn" {
  description = "ARN of the IAM policy used by the AWS Load Balancer Controller"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}