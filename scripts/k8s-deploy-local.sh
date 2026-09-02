#!/bin/bash
# Builds both service images and deploys everything to whatever Kubernetes
# cluster your current kubectl context points at (kind, minikube, or a real
# cloud cluster). See k8s/README.md for one-time cluster setup.
set -e

cd "$(dirname "$0")/.."

echo "Current kubectl context: $(kubectl config current-context)"
read -p "Deploy to this context? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted. Run 'kubectl config use-context <name>' to switch, then re-run this script."
  exit 1
fi

echo "Building service images..."
docker build -t auth-service:local ./services/auth-service
docker build -t core-service:local ./services/core-service

# kind clusters need images loaded explicitly - they don't share the host's
# Docker daemon. Skip this step for minikube (uses `minikube image load`
# instead) or a real cluster (push to a registry and use the staging/production
# overlays' `images:` section instead of :local tags).
if command -v kind &> /dev/null && kubectl config current-context | grep -q "^kind-"; then
  echo "Loading images into kind cluster..."
  kind load docker-image auth-service:local
  kind load docker-image core-service:local
fi

echo "Applying base manifests..."
kubectl apply -k k8s/base

echo "Waiting for Postgres to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n car-tracker --timeout=120s

echo "Running database migrations..."
kubectl delete job auth-service-migrate -n car-tracker --ignore-not-found
kubectl apply -f k8s/base/auth-service/migrate-job.yaml
kubectl wait --for=condition=complete job/auth-service-migrate -n car-tracker --timeout=60s

kubectl delete job core-service-migrate -n car-tracker --ignore-not-found
kubectl apply -f k8s/base/core-service/migrate-job.yaml
kubectl wait --for=condition=complete job/core-service-migrate -n car-tracker --timeout=60s

echo ""
echo "Deployed. Check status with:"
echo "  kubectl get pods -n car-tracker"
echo ""
echo "To reach the API locally without an Ingress controller set up, port-forward:"
echo "  kubectl port-forward -n car-tracker svc/auth-service 4001:4001"
echo "  kubectl port-forward -n car-tracker svc/core-service 4002:4002"
