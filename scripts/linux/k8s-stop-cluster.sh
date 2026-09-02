#!/bin/bash
# Stops Docker Desktop (Linux). Note this stops all of Docker Desktop, not
# just Kubernetes - Docker Desktop doesn't offer a CLI-only way to pause
# just the cluster while leaving the Docker Engine running.
set -e

echo "Stopping Docker Desktop..."
if command -v docker &> /dev/null && docker desktop stop &> /dev/null; then
  : # newer Docker Desktop versions bundle a `docker desktop` CLI plugin
elif systemctl --user list-unit-files 2>/dev/null | grep -q docker-desktop; then
  systemctl --user stop docker-desktop
else
  pkill -f "docker-desktop" 2>/dev/null || true
fi

echo "Docker Desktop stopped. Your pods, volumes, and images are preserved"
echo "and will still be there next time you run ./scripts/linux/k8s-start-cluster.sh."
