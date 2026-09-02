# Full first-time deploy to Docker Desktop's Kubernetes: build images,
# apply the k8s manifests, wait for Postgres, run migrations.
# Run .\scripts\windows\k8s-start-cluster.ps1 first if the cluster isn't up yet.
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-deploy.ps1

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")

$currentContext = kubectl config current-context
Write-Host "Current kubectl context: $currentContext"
if ($currentContext -ne "docker-desktop") {
    Write-Host "Switching to the docker-desktop context..."
    kubectl config use-context docker-desktop
}

& "$PSScriptRoot\k8s-build-images.ps1"

Write-Host "Applying base manifests..."
kubectl apply -k k8s\base

Write-Host "Waiting for Postgres to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n car-tracker --timeout=120s

Write-Host "Running database migrations..."
kubectl delete job auth-service-migrate -n car-tracker --ignore-not-found
kubectl apply -f k8s\base\auth-service\migrate-job.yaml
kubectl wait --for=condition=complete job/auth-service-migrate -n car-tracker --timeout=60s

kubectl delete job core-service-migrate -n car-tracker --ignore-not-found
kubectl apply -f k8s\base\core-service\migrate-job.yaml
kubectl wait --for=condition=complete job/core-service-migrate -n car-tracker --timeout=60s

Write-Host ""
Write-Host "Deployed. Check status with:"
Write-Host "  kubectl get pods -n car-tracker"
Write-Host ""
Write-Host "Port-forward to reach the API locally:"
Write-Host "  kubectl port-forward -n car-tracker svc/auth-service 4001:4001"
Write-Host "  kubectl port-forward -n car-tracker svc/core-service 4002:4002"
Write-Host ""
Write-Host "Or set up the Ingress (see k8s\README.md) to reach everything on localhost:8080."
