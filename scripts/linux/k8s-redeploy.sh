#!/bin/bash
# Rebuilds both service images and does a rolling restart so the running
# Deployments pick up the new image content. Since Docker Desktop's
# Kubernetes shares the Docker Engine's image store, re-tagging
# "auth-service:local" / "core-service:local" via a fresh `docker build`
# is enough - `kubectl rollout restart` recreates pods, which then pick up
# whatever the tag currently points to (imagePullPolicy: IfNotPresent, the
# default for non-"latest" tags, just uses the local store as-is).
#
# Use this after you've changed service code and want to redeploy without
# tearing everything down.
set -e

cd "$(dirname "$0")/../.."

./scripts/linux/k8s-build-images.sh

echo "Restarting auth-service..."
kubectl rollout restart deployment/auth-service -n car-tracker
echo "Restarting core-service..."
kubectl rollout restart deployment/core-service -n car-tracker

echo "Waiting for rollouts to complete..."
kubectl rollout status deployment/auth-service -n car-tracker --timeout=120s
kubectl rollout status deployment/core-service -n car-tracker --timeout=120s

echo ""
echo "Redeployed. If you added new .sql migration files, also run:"
echo "  kubectl delete job auth-service-migrate core-service-migrate -n car-tracker --ignore-not-found"
echo "  kubectl apply -f k8s/base/auth-service/migrate-job.yaml"
echo "  kubectl apply -f k8s/base/core-service/migrate-job.yaml"
