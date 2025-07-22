#!/bin/bash

# Script to update Helm repository in S3
set -e

BUCKET_NAME="mjones3-order-system-helm-chart-repo"
CHART_NAME="order-system"
CHART_VERSION="0.1.1"  # Increment version

echo "🔄 Updating Helm repository..."

# Package the chart
echo "📦 Packaging Helm chart..."
helm package helm/ --version $CHART_VERSION --app-version 1.0.1

# Update index
echo "📋 Updating index..."
helm repo index . --url https://${BUCKET_NAME}.s3.amazonaws.com/charts

# Upload to S3
echo "☁️  Uploading to S3..."
aws s3 cp ${CHART_NAME}-${CHART_VERSION}.tgz s3://${BUCKET_NAME}/charts/
aws s3 cp index.yaml s3://${BUCKET_NAME}/

# Make files public (if needed)
aws s3api put-object-acl --bucket ${BUCKET_NAME} --key charts/${CHART_NAME}-${CHART_VERSION}.tgz --acl public-read
aws s3api put-object-acl --bucket ${BUCKET_NAME} --key index.yaml --acl public-read

echo "✅ Helm repository updated successfully!"
echo "📍 Repository URL: https://${BUCKET_NAME}.s3.amazonaws.com"
echo "📦 Chart: ${CHART_NAME}-${CHART_VERSION}.tgz"

# Test the repository
echo "🧪 Testing repository..."
helm repo add order-system https://${BUCKET_NAME}.s3.amazonaws.com || true
helm repo update
helm search repo order-system