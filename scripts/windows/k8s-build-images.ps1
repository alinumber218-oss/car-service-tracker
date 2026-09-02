# Builds both service images. On Docker Desktop's Kubernetes, images built
# here are immediately visible to the cluster - no separate "load into
# cluster" step needed (unlike kind/minikube), since Docker Desktop's
# Kubernetes shares the same image store as the Docker Engine.
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-build-images.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")

Write-Host "Building auth-service:local..."
docker build -t auth-service:local .\services\auth-service

Write-Host "Building core-service:local..."
docker build -t core-service:local .\services\core-service

Write-Host ""
Write-Host "Images built:"
docker images | Select-String -Pattern "^(auth-service|core-service)\s"
