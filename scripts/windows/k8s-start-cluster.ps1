# Starts Docker Desktop (Windows) and waits until its built-in Kubernetes
# cluster (context "docker-desktop") is ready to use.
#
# One-time setup required before this script works:
#   Docker Desktop > Settings > Kubernetes > check "Enable Kubernetes" > Apply & Restart
# That toggle can only be done through the Docker Desktop UI once - after
# that, this script can start/stop Docker Desktop itself going forward.
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-start-cluster.ps1

$ErrorActionPreference = "Stop"

Write-Host "Starting Docker Desktop..."

$dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue)) {
    if (Test-Path $dockerDesktopPath) {
        Start-Process $dockerDesktopPath
    } else {
        Write-Warning "Could not find Docker Desktop at the default install path."
        Write-Warning "Please start Docker Desktop manually, then re-run this script."
    }
}

Write-Host "Waiting for the Docker Engine to respond..."
$maxAttempts = 60
$attempt = 0
while ($attempt -lt $maxAttempts) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
    $attempt++
}
if ($attempt -ge $maxAttempts) {
    Write-Error "Docker Engine did not become ready in time. Is Docker Desktop starting correctly?"
    exit 1
}
Write-Host "Docker Engine is up."

Write-Host "Waiting for the docker-desktop Kubernetes context to be ready..."
kubectl config use-context docker-desktop

$attempt = 0
while ($attempt -lt $maxAttempts) {
    kubectl cluster-info *> $null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 3
    $attempt++
}
if ($attempt -ge $maxAttempts) {
    Write-Error "Kubernetes did not become ready in time. Make sure it's enabled in Docker Desktop Settings > Kubernetes."
    exit 1
}

Write-Host ""
Write-Host "Docker Desktop Kubernetes is ready."
kubectl get nodes
Write-Host ""
Write-Host "Next: .\scripts\windows\k8s-deploy.ps1"
