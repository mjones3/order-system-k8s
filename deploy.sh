#!/usr/bin/env bash
set -e
set -euxo pipefail

# Determine the project root (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

echo "Project root is: $PROJECT_ROOT"

# Define a single ECR repository URL for all services
ECR_REPO_URL="294417223953.dkr.ecr.us-east-1.amazonaws.com"

# List the service folders you want to build
services=("order-service" "inventory-service" "payment-service")

# Use the first command-line argument as the image tag, defaulting to "latest"
IMAGE_TAG=${1:-"latest"}

# Log in to ECR once (common for all images)
echo "Logging into ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${ECR_REPO_URL}"

# Loop through each service and build & push its Docker image
for service in "${services[@]}"; do
  # Create a unique image tag per service: e.g., order-service-latest, inventory-service-latest, etc.
  IMAGE_FULL_TAG="${ECR_REPO_URL}/${service}:${IMAGE_TAG}"
  
  echo "-------------------------------------------------------"
  echo "Building Docker image for $service with tag $IMAGE_FULL_TAG..."
  # docker build -t "${IMAGE_FULL_TAG}" "./apps/${service}"
  # docker build --platform linux/arm64 -t "${IMAGE_FULL_TAG}" "./apps/${service}"
  
  docker build --platform linux/amd64 -t "${IMAGE_FULL_TAG}" "./apps/${service}"
  echo "Pushing Docker image for $service..."
  docker push "${IMAGE_FULL_TAG}"
  echo "-------------------------------------------------------"
done

#lambdas

# Define parallel arrays: one for Lambda function names and one for their corresponding source directories (where the ZIP file is located)
lambda_names=("orderServiceFunction" "inventoryServiceFunction" "paymentServiceFunction" "cancelOrderFunction" "releaseInventoryFunction")
lambda_dirs=(
  "./apps/functions/order-service-handler"    # orderServiceFunction ZIP is in this folder
  "./apps/functions/inventory-service-handler"    # inventoryServiceFunction
  "./apps/functions/payment-service-handler"    # paymentServiceFunction
  "./apps/functions/cancel-order-handler"    # cancelOrderFunction
  "./apps/functions/release-inventory-handler"    # releaseInventoryFunction
)

changed_lambdas=()

# Loop over the arrays using indices.
for i in "${!lambda_names[@]}"; do
  lambda="${lambda_names[$i]}"
  LAMBDA_DIR="${lambda_dirs[$i]}"
  ZIP_FILE="${LAMBDA_DIR}/${lambda}.zip"  # Build path relative to each lambda's directory
  CHECKSUM_FILE="./${lambda}.checksum"
  echo "-------------------------------------------------------"
  echo "Checking for changes in $lambda code in $LAMBDA_DIR..."

  

  # Compute a combined checksum for all files in the Lambda source directory.
  CURRENT_CHECKSUM=$(find "$LAMBDA_DIR" -type f -exec sha256sum {} \; | sort | sha256sum | awk '{print $1}')

  # Read stored checksum if it exists.
  if [ -f "$CHECKSUM_FILE" ]; then
      STORED_CHECKSUM=$(cat "$CHECKSUM_FILE")
  else
      STORED_CHECKSUM=""
  fi

  if [ "$CURRENT_CHECKSUM" != "$STORED_CHECKSUM" ]; then
      echo "Changes detected for $lambda. Packaging source into $ZIP_FILE..."
      # Create the ZIP package. Change directory to the Lambda directory and zip its contents.
      pushd "$LAMBDA_DIR" > /dev/null
      zip -r "${lambda}.zip" .
      popd > /dev/null

      # Update the checksum file.
      echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"
      changed_lambdas+=("${lambda}")
  fi
done


# Now run Terraform, passing each service's image URI as a variable.
# cd terraform
# terraform init
# terraform apply \
#   -var="order_service_image=${ECR_REPO_URL}:order-service-${IMAGE_TAG}" \
#   -var="inventory_service_image=${ECR_REPO_URL}:inventory-service-${IMAGE_TAG}" \
#   -var="payment_service_image=${ECR_REPO_URL}:payment-service-${IMAGE_TAG}" \
#   -auto-approve
# terraform refresh
# terraform output module.api.orders_api_endpoint

for fn in "${changed_lambdas[@]}"; do
  echo "-------------------------------------------------------"
  echo "Looking for ${fn}.zip in $PROJECT_ROOT/apps/functions ..."

  ZIP_FILE=$(find "${PROJECT_ROOT}/apps/functions" -type f -name "${fn}.zip" -print -quit)

  if [[ -z "$ZIP_FILE" ]]; then
    echo "❌  Could not find ${fn}.zip under ${PROJECT_ROOT}/apps/functions" >&2
    continue
  fi

  echo "✔  Found $ZIP_FILE"
  echo "Updating Lambda function code for $fn..."

  aws lambda update-function-code \
    --function-name "$fn" \
    --zip-file "fileb://$ZIP_FILE"

  echo "✔  Updated $fn"
done
echo "-------------------------------------------------------"
