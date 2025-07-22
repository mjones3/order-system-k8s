provider "aws" {
  region = "us-east-1" # Set your AWS region
}

# Create Cognito User Pool
resource "aws_cognito_user_pool" "order_user_pool" {
  name = "order-user-pool"

  # Set any other pool attributes you want
  mfa_configuration = "OFF"

  # Password policy block directly under user pool configuration
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }
}

# Create Cognito User Pool Client (App Client)
resource "aws_cognito_user_pool_client" "order_user_pool_client" {
  name            = "order-user-pool-client"
  user_pool_id    = aws_cognito_user_pool.order_user_pool.id # Correct reference here
  generate_secret = false

  # Optional: Set allowed OAuth Flows if you plan to use OAuth
  allowed_oauth_flows  = ["code"]
  allowed_oauth_scopes = ["openid", "profile"]
}


# Create a sample user in the User Pool
resource "aws_cognito_user" "order_user" {
  username     = "sampleuser"
  user_pool_id = aws_cognito_user_pool.order_user_pool.id
  attributes = {
    email       = "sampleuser@example.com"
    given_name  = "Sample"
    family_name = "User"
  }

  # Setting the temporary password and requiring the user to reset it
  temporary_password   = "TempPassword123~!"
  force_alias_creation = false
}

