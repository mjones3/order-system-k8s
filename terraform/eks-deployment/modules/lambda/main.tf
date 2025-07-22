resource "aws_sfn_state_machine" "order_saga" {
  name     = "OrderSagaStateMachine"
  role_arn = var.aws_iam_role_sfn_role_arn

  definition = <<EOF
{
  "Comment": "State machine for processing the order saga with Choice states",
  "StartAt": "OrderService",
  "States": {
    "OrderService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.order_service.arn}",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "InventoryService"
    },

    "InventoryService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.inventory_service.arn}",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "CheckInventory"
    },

    "CheckInventory": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Payload.statusCode",
          "NumericEquals": 404,
          "Next": "CancelOrder"
        }
      ],
      "Default": "PaymentService"
    },

    "PaymentService": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.payment_service.arn}",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "CheckPayment"
    },

    "CheckPayment": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Payload.statusCode",
          "NumericEquals": 402,
          "Next": "ReleaseInventory"
        }
      ],
      "Default": "CompleteSaga"
    },

    "ReleaseInventory": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.release_inventory.arn}",
        "Payload": { "input.$": "$" }
      },
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "Next": "FailSaga"
        }
      ],
      "Next": "CancelOrder"
    },

    "CancelOrder": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${aws_lambda_function.cancel_order.arn}",
        "Payload": { "input.$": "$" }
      },
      "Next": "FailSaga"
    },

    "CompleteSaga": {
      "Type": "Succeed"
    },

    "FailSaga": {
      "Type": "Fail",
      "Cause": "SagaFailed"
    }
  }
}
EOF
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
  tracing_configuration { enabled = true }
}


resource "aws_lambda_function" "order_service" {
  function_name = "orderServiceFunction"
  handler       = "lambda_function.lambda_handler" # file name . function name
  runtime       = "python3.9"                      # or your preferred Python version
  role          = var.aws_lambda_assume_role_arn
  filename      = "../apps/functions/order-service-handler/orderServiceFunction.zip" # your deployment package ZIP file
  environment {
    variables = {
      API_ENDPOINT_ORDERS = var.api_endpoint_orders
    }
  }
  tracing_config {
    mode = "Active"
  }
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}

resource "aws_lambda_function" "inventory_service" {
  function_name = "inventoryServiceFunction"
  handler       = "lambda_function.lambda_handler" # file name . function name
  runtime       = "python3.9"                      # or your preferred Python version
  role          = var.aws_lambda_assume_role_arn
  filename      = "../apps/functions/inventory-service-handler/inventoryServiceFunction.zip" # your deployment package ZIP file

  environment {
    variables = {
      API_ENDPOINT_INVENTORY = var.api_endpoint_inventory
    }
  }
  tracing_config {
    mode = "Active"
  }
  tags = {
    Environment = "dev"
    project     = "order-system"
  }
}


resource "aws_lambda_function" "payment_service" {
  function_name = "paymentServiceFunction"
  handler       = "lambda_function.lambda_handler" # file name . function name
  runtime       = "python3.9"                      # or your preferred Python version
  role          = var.aws_lambda_assume_role_arn
  filename      = "../apps/functions/payment-service-handler/paymentServiceFunction.zip" # your deployment package ZIP file

  environment {
    variables = {
      API_ENDPOINT_PAYMENT = var.api_endpoint_payment
    }

  }
  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_function" "release_inventory" {
  function_name = "releaseInventoryFunction"
  handler       = "lambda_function.lambda_handler" # file name . function name
  runtime       = "python3.9"                      # or your preferred Python version
  role          = var.aws_lambda_assume_role_arn
  filename      = "../apps/functions/release-inventory-handler/releaseInventoryFunction.zip" # your deployment package ZIP file

  environment {
    variables = {
      API_ENDPOINT_RELEASE_INVENTORY = var.api_endpoint_release_inventory
    }
  }
  tracing_config {
    mode = "Active"
  }
}


resource "aws_lambda_function" "cancel_order" {
  function_name = "cancelOrderFunction"
  handler       = "lambda_function.lambda_handler" # file name . function name
  runtime       = "python3.9"                      # or your preferred Python version
  role          = var.aws_lambda_assume_role_arn
  filename      = "../apps/functions/cancel-order-handler/cancelOrderFunction.zip" # your deployment package ZIP file

  environment {
    variables = {
      API_ENDPOINT_CANCEL_ORDER = var.api_endpoint_cancel_order
    }
  }
  tracing_config {
    mode = "Active"
  }
}
