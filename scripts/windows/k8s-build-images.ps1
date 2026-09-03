# Builds both service images. On Docker Desktop's Kubernetes, images built
# here are immediately visible to the cluster - no separate "load into
# cluster" step needed (unlike kind/minikube), since Docker Desktop's
# Kubernetes shares the same image store as the Docker Engine.
#
# Base images and npm packages are pulled through Nexus if NEXUS_DOCKER_PROXY
# is set (falls back to the public registries otherwise). See docs/NEXUS.md.
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-build-images.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")

$BaseRegistry = if ($env:NEXUS_DOCKER_PROXY) { $env:NEXUS_DOCKER_PROXY } else { "docker.io/library" }
$NpmTokenFile = if ($env:NEXUS_NPM_TOKEN_FILE) { $env:NEXUS_NPM_TOKEN_FILE } else { ".\secrets\nexus_npm_token.txt" }
if (-not (Test-Path $NpmTokenFile)) { New-Item -ItemType File -Path $NpmTokenFile -Force | Out-Null }

$env:DOCKER_BUILDKIT = "1"

Write-Host "Building auth-service:local (BASE_REGISTRY=$BaseRegistry)..."
docker build `
  --build-arg BASE_REGISTRY=$BaseRegistry `
  --secret id=npm_token,src=$NpmTokenFile `
  -t auth-service:local .\services\auth-service

Write-Host "Building core-service:local (BASE_REGISTRY=$BaseRegistry)..."
docker build `
  --build-arg BASE_REGISTRY=$BaseRegistry `
  --secret id=npm_token,src=$NpmTokenFile `
  -t core-service:local .\services\core-service

Write-Host ""
Write-Host "Images built:"
docker images | Select-String -Pattern "^(auth-service|core-service)\s"
