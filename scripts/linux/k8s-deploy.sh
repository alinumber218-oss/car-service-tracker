#!/bin/bash
# Full first-time deploy to Docker Desktop's Kubernetes: build images,
# apply the k8s manifests, wait for Postgres, run migrations.
# Run ./scripts/linux/k8s-start-cluster.sh first if the cluster isn't up yet.
set -e

cd "$(dirname "$0")/../.."

echo "Current kubectl context: $(kubectl config current-context)"
if [[ "$(kubectl config current-context)" != "docker-desktop" ]]; then
  echo "Switching to the docker-desktop context..."
  kubectl config use-context docker-desktop
fi

./scripts/linux/k8s-build-images.sh

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
echo "Port-forward to reach the API locally:"
echo "  kubectl port-forward -n car-tracker svc/auth-service 4001:4001"
echo "  kubectl port-forward -n car-tracker svc/core-service 4002:4002"
echo ""
echo "Or set up the Ingress (see k8s/README.md) to reach everything on localhost:8080."
