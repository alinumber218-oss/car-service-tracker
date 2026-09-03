#!/bin/bash
# Builds both service images. On Docker Desktop's Kubernetes, images built
# here are immediately visible to the cluster - no separate "load into
# cluster" step needed (unlike kind/minikube), since Docker Desktop's
# Kubernetes shares the same image store as the Docker Engine.
#
# Base images and npm packages are pulled through Nexus if NEXUS_DOCKER_PROXY
# is set (falls back to the public registries otherwise). See docs/NEXUS.md.
set -e

cd "$(dirname "$0")/../.."

BASE_REGISTRY="${NEXUS_DOCKER_PROXY:-docker.io/library}"
NPM_TOKEN_FILE="${NEXUS_NPM_TOKEN_FILE:-./secrets/nexus_npm_token.txt}"
[ -f "$NPM_TOKEN_FILE" ] || touch "$NPM_TOKEN_FILE"

echo "Building auth-service:local (BASE_REGISTRY=$BASE_REGISTRY)..."
DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_REGISTRY="$BASE_REGISTRY" \
  --secret id=npm_token,src="$NPM_TOKEN_FILE" \
  -t auth-service:local ./services/auth-service

echo "Building core-service:local (BASE_REGISTRY=$BASE_REGISTRY)..."
DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_REGISTRY="$BASE_REGISTRY" \
  --secret id=npm_token,src="$NPM_TOKEN_FILE" \
  -t core-service:local ./services/core-service

echo ""
echo "Images built:"
docker images | grep -E "^(auth-service|core-service)\s" || true
