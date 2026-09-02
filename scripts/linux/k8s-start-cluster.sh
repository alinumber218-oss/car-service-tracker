#!/bin/bash
# Starts Docker Desktop (Linux) and waits until its built-in Kubernetes
# cluster (context "docker-desktop") is ready to use.
#
# One-time setup required before this script works:
#   Docker Desktop > Settings > Kubernetes > check "Enable Kubernetes" > Apply & Restart
# That toggle can only be done through the Docker Desktop UI once - after
# that, this script can start/stop Docker Desktop itself going forward.
set -e

echo "Starting Docker Desktop..."
if systemctl --user list-unit-files 2>/dev/null | grep -q docker-desktop; then
  systemctl --user start docker-desktop
else
  # Fallback for installs that don't register the systemd user service
  nohup docker-desktop > /dev/null 2>&1 &
  disown
fi

echo "Waiting for the Docker Engine to respond..."
until docker info > /dev/null 2>&1; do
  sleep 2
done
echo "Docker Engine is up."

echo "Waiting for the docker-desktop Kubernetes context to be ready..."
kubectl config use-context docker-desktop
until kubectl cluster-info > /dev/null 2>&1; do
  sleep 3
done

echo ""
echo "Docker Desktop Kubernetes is ready."
kubectl get nodes
echo ""
echo "Next: ./scripts/linux/k8s-deploy.sh"
