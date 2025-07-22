# Order Service Deployment

This directory contains scripts and configuration files for deploying the Order Service to both cloud (EKS) and local environments.

## Cloud Deployment

To deploy the Order Service to EKS:

```bash
./deploy-order-service.sh
```

This will:
1. Update the kubeconfig for the EKS cluster
2. Create the necessary Kubernetes resources (namespace, service account, role, role binding, config map, deployment, service, HPA)
3. Deploy the Order Service to the EKS cluster

## Local Development

There are two ways to run the Order Service locally:

### Option 1: Using Kubernetes (Minikube or Kind)

```bash
./deploy-local.sh
```

This will:
1. Start a local Kubernetes cluster (Minikube or Kind) if not already running
2. Build a Docker image for the Order Service
3. Deploy the Order Service to the local Kubernetes cluster
4. Set up port forwarding to access the service at http://localhost:8080

You can customize the database connection and other parameters:

```bash
./deploy-local.sh --db-host localhost --db-port 5432 --db-name orderdb --db-user orderuser --db-password orderpass --image-tag dev
```

### Option 2: Using Docker Compose

```bash
docker-compose up
```

This will:
1. Start a PostgreSQL container
2. Build and start the Order Service container
3. Make the service accessible at http://localhost:8080

## Environment Variables

The deployment scripts support the following environment variables:

- `ENVIRONMENT`: Set to "local" for local development, "cloud" for EKS deployment (default: "cloud")
- `DB_HOST`: Database hostname (default: RDS endpoint for cloud, "localhost" for local)
- `DB_PORT`: Database port (default: "5432")
- `DB_NAME`: Database name (default: "orderdb")
- `DB_USER`: Database username (default: "orderuser")
- `DB_PASSWORD`: Database password (default: "orderpass")
- `IMAGE_TAG`: Docker image tag (default: "latest" for cloud, "dev" for local)
- `SKIP_DB_CHECK`: Set to "true" to skip database connectivity check (default: "false")

## Troubleshooting

If you encounter issues with the deployment:

1. Check the logs of the Order Service:
   ```bash
   kubectl logs -n order-service -l app=order-service
   ```

2. Check the database connectivity:
   ```bash
   kubectl exec -it -n order-service $(kubectl get pod -n order-service -l app=order-service -o jsonpath='{.items[0].metadata.name}') -- env | grep PG
   ```

3. Test the database connection directly:
   ```bash
   kubectl run -it --rm --restart=Never postgres-client --image=postgres:14-alpine -n order-service -- psql -h $DB_HOST -U $DB_USER -d $DB_NAME
   ```

4. For local development issues, check Docker logs:
   ```bash
   docker logs order-service
   ```