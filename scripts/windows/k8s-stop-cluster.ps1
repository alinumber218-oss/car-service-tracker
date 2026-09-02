# Stops Docker Desktop (Windows). Note this stops all of Docker Desktop, not
# just Kubernetes - Docker Desktop doesn't offer a way to pause just the
# cluster while leaving the Docker Engine running.
#
# Usage (from a PowerShell prompt, repo root):
#   .\scripts\windows\k8s-stop-cluster.ps1

Write-Host "Stopping Docker Desktop..."

# Newer Docker Desktop versions bundle a `docker desktop` CLI plugin that
# can shut things down cleanly. Fall back to killing the process if that
# subcommand isn't available on your installed version.
docker desktop stop *> $null
if ($LASTEXITCODE -ne 0) {
    Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force
}

Write-Host "Docker Desktop stopped. Your pods, volumes, and images are preserved"
Write-Host "and will still be there next time you run .\scripts\windows\k8s-start-cluster.ps1."
