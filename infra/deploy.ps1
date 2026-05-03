# lingo_Chatul backend deploy script.
#
# What this does:
#   - SSHs into the Hetzner box (49.12.247.57)
#   - Pulls the latest code from main into /opt/lingo
#   - Builds the Rails image locally (no registry round-trip)
#   - Brings the docker-compose stack up: Caddy → Rails app → Postgres
#
# First-time bootstrap (do this once before the first deploy):
#   See infra/DEPLOY.md §"First deploy" for the full sequence.
#
# Subsequent deploys: just run this script.

$ErrorActionPreference = "Stop"
$key = "$env:USERPROFILE\.ssh\lingo_chatul"

if (-not (Test-Path $key)) {
  Write-Error "SSH key not found at $key"
  exit 1
}

Write-Host "→ Pulling latest code on Hetzner and rebuilding…"
ssh -i $key -o StrictHostKeyChecking=accept-new root@49.12.247.57 @'
set -e
cd /opt/lingo
git fetch origin main
git reset --hard origin/main
cd infra
docker compose -f docker-compose.prod.yml --env-file ../.env build app
docker compose -f docker-compose.prod.yml --env-file ../.env up -d
docker compose -f docker-compose.prod.yml ps
'@

Write-Host ""
Write-Host "→ Probing api.lingochatul.com/up…"
try {
  $r = Invoke-WebRequest -Uri "https://api.lingochatul.com/up" -UseBasicParsing -TimeoutSec 30
  Write-Host "   HTTP $($r.StatusCode)"
} catch {
  Write-Host "   FAILED: $($_.Exception.Message)"
  Write-Host "   (Cert issuance can take 30-60s on the very first deploy. Try again in a minute.)"
}
