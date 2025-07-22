#!/bin/bash
set -e

cd terraform/eks-deployment
terraform init -reconfigure
terraform validate