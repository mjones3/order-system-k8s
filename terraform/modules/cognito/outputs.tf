output "user_pool_id" {
  value = aws_cognito_user_pool.order_user_pool.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.order_user_pool_client.id
}

output "sample_user_id" {
  value = aws_cognito_user.order_user.id
}
