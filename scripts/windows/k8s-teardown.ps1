# Removes everything deployed by k8s-deploy.ps1. Pass -Wipe to also delete
# PersistentVolumeClaims (wipes Postgres/MinIO data).
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-teardown.ps1
#   .\scripts\windows\k8s-teardown.ps1 -Wipe

param(
    [switch]$Wipe
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")

kubectl delete -k k8s\base --ignore-not-found

if ($Wipe) {
    Write-Host "Deleting PersistentVolumeClaims (this wipes stored data)..."
    kubectl delete pvc -n car-tracker --all --ignore-not-found
}

Write-Host "Done. Docker Desktop's Kubernetes cluster itself is still running -"
Write-Host "use k8s-stop-cluster.ps1 if you want to stop Docker Desktop entirely."
