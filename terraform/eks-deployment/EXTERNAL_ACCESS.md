# Accessing the Order Service Externally

This document explains how to access the Order Service that has been deployed to EKS with an AWS Application Load Balancer (ALB).

## Getting the External URL

After deploying the Order Service with the ALB ingress, you can get the external URL using:

```bash
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace/terraform/eks-deployment hashicorp/terraform:latest output order_service_url
```

This will output something like:
```
http://k8s-orderser-orderser-1234567890.us-east-1.elb.amazonaws.com
```

## Making API Requests

You can now make API requests to the Order Service using this URL:

### Health Check

```bash
curl http://<your-alb-url>/actuator/health
```

### Create an Order

```bash
curl -X POST http://<your-alb-url>/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "123",
    "items": [
      {
        "productId": "456",
        "quantity": 1
      }
    ]
  }'
```

### Get an Order

```bash
curl http://<your-alb-url>/orders/1
```

### List Orders

```bash
curl http://<your-alb-url>/orders
```

## Securing the API

For production use, it's recommended to:

1. **Enable HTTPS**: Update the ingress annotations to include SSL certificate ARN:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account-id:certificate/certificate-id
```

2. **Add Authentication**: Implement API authentication using JWT, OAuth, or API keys.

3. **Configure WAF**: Set up AWS WAF to protect against common web exploits.

4. **Set up a Custom Domain**: Configure Route 53 to point a custom domain to the ALB.

## Troubleshooting

If you're having issues accessing the service:

1. **Check the Ingress Status**:
```bash
kubectl get ingress -n order-service
```

2. **Check the ALB Controller Logs**:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

3. **Verify Security Groups**:
Make sure the security groups allow traffic on port 80/443 from your IP or the internet.

4. **Check Target Group Health**:
In the AWS Console, go to EC2 > Target Groups and check if the targets are healthy.

5. **Verify Service Endpoints**:
```bash
kubectl get endpoints -n order-service
```

## Cleaning Up

To delete the ALB and associated resources:

```bash
kubectl delete ingress order-service-ingress -n order-service
```

Or use Terraform:

```bash
docker run --rm -v $(pwd):/workspace -v ~/.aws:/root/.aws -w /workspace/terraform/eks-deployment hashicorp/terraform:latest destroy -target=module.eks_order_service.kubernetes_ingress_v1.order_service_ingress
```