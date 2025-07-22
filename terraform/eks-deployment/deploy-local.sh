#!/bin/bash

# Script to deploy the order service locally
set -e

# Default values for local development
export ENVIRONMENT="local"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="orderdb"
export DB_USER="orderuser"
export DB_PASSWORD="orderpass"
export IMAGE_TAG="dev"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --db-host)
      export DB_HOST="$2"
      shift 2
      ;;
    --db-port)
      export DB_PORT="$2"
      shift 2
      ;;
    --db-name)
      export DB_NAME="$2"
      shift 2
      ;;
    --db-user)
      export DB_USER="$2"
      shift 2
      ;;
    --db-password)
      export DB_PASSWORD="$2"
      shift 2
      ;;
    --image-tag)
      export IMAGE_TAG="$2"
      shift 2
      ;;
    --skip-db-check)
      export SKIP_DB_CHECK="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--db-host host] [--db-port port] [--db-name name] [--db-user user] [--db-password password] [--image-tag tag] [--skip-db-check]"
      exit 1
      ;;
  esac
done

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if local PostgreSQL is running
if [ "$DB_HOST" = "localhost" ] && ! nc -z localhost $DB_PORT > /dev/null 2>&1; then
  echo "⚠️ Local PostgreSQL is not running on port $DB_PORT."
  echo "Would you like to start a PostgreSQL container? (y/n)"
  read -r start_postgres
  
  if [[ $start_postgres =~ ^[Yy]$ ]]; then
    echo "🐘 Starting PostgreSQL container..."
    docker run --name postgres-orderdb \
      -e POSTGRES_DB=$DB_NAME \
      -e POSTGRES_USER=$DB_USER \
      -e POSTGRES_PASSWORD=$DB_PASSWORD \
      -p $DB_PORT:5432 \
      -d postgres:14-alpine
      
    echo "⏳ Waiting for PostgreSQL to start..."
    sleep 5
    
    # Check if PostgreSQL is running
    if ! nc -z localhost $DB_PORT > /dev/null 2>&1; then
      echo "❌ Failed to start PostgreSQL container."
      exit 1
    fi
    
    echo "✅ PostgreSQL container started successfully."
  else
    echo "⚠️ Continuing without local PostgreSQL. Make sure your database configuration is correct."
    export SKIP_DB_CHECK="true"
  fi
fi

# Build the order service image for local development
echo "🔨 Building order service image..."
docker build -t order-service:$IMAGE_TAG -f Dockerfile.local .

# Deploy the order service
echo "🚀 Deploying order service locally..."
./deploy-order-service.sh

echo "✅ Local deployment completed."
echo "The order service is accessible at http://localhost:8080"
echo "Press Ctrl+C to stop the service."