variable "aws_iam_role_sfn_role_arn" {
  type = string
}

variable "lambda_exec_role_arn" {
  type = string
}
variable "aws_lambda_assume_role_arn" {
  type = string
}

variable "api_endpoint_orders" {
  type = string
}

variable "api_endpoint_inventory" {
  type = string
}

variable "api_endpoint_payment" {
  type = string
}

variable "api_endpoint_release_inventory" {
  type = string
}

variable "api_endpoint_cancel_order" {
  type = string
}
