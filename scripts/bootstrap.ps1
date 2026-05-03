# =====================================================================
# bootstrap.ps1 — one-time scaffold for Rails 8 API + Vite/React web
# Run from repo root after Docker Desktop is installed and running.
# =====================================================================

$ErrorActionPreference = "Stop"

Write-Host "==> Checking Docker..." -ForegroundColor Cyan
docker --version
if ($LASTEXITCODE -ne 0) { throw "Docker not found. Install Docker Desktop first." }

# ---------------------------------------------------------------------
# 1. Generate Rails 8 API in api/
# ---------------------------------------------------------------------
if (-not (Test-Path "api/Gemfile")) {
  Write-Host "==> Generating Rails 8 API in api/ ..." -ForegroundColor Cyan
  docker run --rm -v "${PWD}:/work" -w /work ruby:3.3-bookworm bash -c @'
set -e
apt-get update -qq && apt-get install -y -qq libpq-dev nodejs > /dev/null
gem install rails -v '~> 8.0' --no-document
rails new api --api -d postgresql --skip-git --skip-test --skip-system-test
'@
} else {
  Write-Host "==> api/Gemfile already exists, skipping Rails generation." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# 2. Generate Vite + React + TS in web/
# ---------------------------------------------------------------------
if (-not (Test-Path "web/package.json")) {
  Write-Host "==> Generating Vite + React app in web/ ..." -ForegroundColor Cyan
  docker run --rm -v "${PWD}:/work" -w /work node:20-bookworm bash -c @'
set -e
npm create vite@latest web -- --template react-ts -y
cd web
npm install
'@
} else {
  Write-Host "==> web/package.json already exists, skipping Vite generation." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------
# 3. Build Rails container and prepare DB
# ---------------------------------------------------------------------
Write-Host "==> Building Rails dev container ..." -ForegroundColor Cyan
docker compose build api

Write-Host "==> Bringing up Postgres ..." -ForegroundColor Cyan
docker compose up -d db

Write-Host ""
Write-Host "==> Bootstrap complete." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  docker compose up           # start full stack (db + api)"
Write-Host "  cd web && npm run dev       # start web frontend on :5173"
