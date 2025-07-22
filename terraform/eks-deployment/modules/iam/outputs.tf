output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "aws_iam_role_sfn_role_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_iam_role.sfn_role.arn
}

output "lambda_exec_role_arn" {
  description = "The ARN of the Lambda Task Execution Role"
  value       = aws_iam_role.sfn_role.arn
}


output "aws_lambda_assume_role_arn" {
  value = aws_iam_role.lambda_exec_role.arn

}
