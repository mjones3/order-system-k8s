output "role_arn" {
  description = "ARN of the IAM role used by the AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "policy_arn" {
  description = "ARN of the IAM policy used by the AWS Load Balancer Controller"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}

output "service_account_name" {
  description = "Name of the Kubernetes service account used by the AWS Load Balancer Controller"
  value       = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
}

output "helm_release_name" {
  description = "Name of the Helm release used to deploy the AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.name
}