output "aws_lambda_function_order_service_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_lambda_function.order_service.arn
}

output "aws_lambda_function_inventory_service_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_lambda_function.inventory_service.arn
}

output "aws_lambda_function_payment_service_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_lambda_function.payment_service.arn
}

output "aws_lambda_function_cancel_order_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_lambda_function.cancel_order.arn
}

output "aws_lambda_function_release_inventory_arn" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_lambda_function.release_inventory.arn
}

output "aws_sfn_state_machine_order_saga" {
  description = "The ARN of the ECS Task Execution Role"
  value       = aws_sfn_state_machine.order_saga.arn
}


