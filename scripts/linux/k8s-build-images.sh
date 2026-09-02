#!/bin/bash
# Builds both service images. On Docker Desktop's Kubernetes, images built
# here are immediately visible to the cluster - no separate "load into
# cluster" step needed (unlike kind/minikube), since Docker Desktop's
# Kubernetes shares the same image store as the Docker Engine.
set -e

cd "$(dirname "$0")/../.."

echo "Building auth-service:local..."
docker build -t auth-service:local ./services/auth-service

echo "Building core-service:local..."
docker build -t core-service:local ./services/core-service

echo ""
echo "Images built:"
docker images | grep -E "^(auth-service|core-service)\s" || true
