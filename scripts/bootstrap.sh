#!/usr/bin/env bash
# =====================================================================
# bootstrap.sh — one-time scaffold for Rails 8 API + Vite/React web
# Run from repo root after Docker is installed and running.
# (PowerShell equivalent: scripts/bootstrap.ps1)
# =====================================================================

set -euo pipefail

echo "==> Checking Docker..."
docker --version

# ---------------------------------------------------------------------
# 1. Generate Rails 8 API in api/
# ---------------------------------------------------------------------
if [ ! -f "api/Gemfile" ]; then
  echo "==> Generating Rails 8 API in api/ ..."
  docker run --rm -v "$(pwd):/work" -w /work ruby:3.3-bookworm bash -c '
    set -e
    apt-get update -qq && apt-get install -y -qq libpq-dev nodejs > /dev/null
    gem install rails -v "~> 8.0" --no-document
    rails new api --api -d postgresql --skip-git --skip-test --skip-system-test
  '
else
  echo "==> api/Gemfile already exists, skipping Rails generation."
fi

# ---------------------------------------------------------------------
# 2. Generate Vite + React + TS in web/
# ---------------------------------------------------------------------
if [ ! -f "web/package.json" ]; then
  echo "==> Generating Vite + React app in web/ ..."
  docker run --rm -v "$(pwd):/work" -w /work node:20-bookworm bash -c '
    set -e
    npm create vite@latest web -- --template react-ts -y
    cd web && npm install
  '
else
  echo "==> web/package.json already exists, skipping Vite generation."
fi

# ---------------------------------------------------------------------
# 3. Build Rails container and prepare DB
# ---------------------------------------------------------------------
echo "==> Building Rails dev container ..."
docker compose build api

echo "==> Bringing up Postgres ..."
docker compose up -d db

echo
echo "==> Bootstrap complete."
echo
echo "Next steps:"
echo "  docker compose up           # start full stack (db + api)"
echo "  cd web && npm run dev       # start web frontend on :5173"
