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
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-redeploy.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")

& "$PSScriptRoot\k8s-build-images.ps1"

Write-Host "Restarting auth-service..."
kubectl rollout restart deployment/auth-service -n car-tracker
Write-Host "Restarting core-service..."
kubectl rollout restart deployment/core-service -n car-tracker

Write-Host "Waiting for rollouts to complete..."
kubectl rollout status deployment/auth-service -n car-tracker --timeout=120s
kubectl rollout status deployment/core-service -n car-tracker --timeout=120s

Write-Host ""
Write-Host "Redeployed. If you added new .sql migration files, also run:"
Write-Host "  kubectl delete job auth-service-migrate core-service-migrate -n car-tracker --ignore-not-found"
Write-Host "  kubectl apply -f k8s\base\auth-service\migrate-job.yaml"
Write-Host "  kubectl apply -f k8s\base\core-service\migrate-job.yaml"
