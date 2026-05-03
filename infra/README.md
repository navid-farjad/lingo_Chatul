# infra/

Production infrastructure for lingo_Chatul. Both halves of the app are live.

> The deploy story is **AI-as-operator**. When the user says "deploy" or "ship", the agent reads [DEPLOY.md](DEPLOY.md) and executes its commands directly — there is no human runbook.

- **[DEPLOY.md](DEPLOY.md)** — agent runbook: architecture, secrets, exact PowerShell+SSH command sequences, gotchas burned in previous sessions, how to seed prod data.

## Quick reference

- Frontend: <https://app.lingochatul.com> (Cloudflare Worker, auto-deploys on push to `production`)
- Backend: <https://api.lingochatul.com> (Hetzner `49.12.247.57`, deploy via `./infra/deploy.ps1`)
- Domain: `lingochatul.com` (Cloudflare zone `89c6ec5aee8eaf2d89195ea7f67e5671`)
- SSH key: `~/.ssh/lingo_chatul`

## Files in this folder

- [docker-compose.prod.yml](docker-compose.prod.yml) — three services: `db` (postgres:16), `app` (Rails image built from [api/Dockerfile](../api/Dockerfile)), `caddy` (auto-TLS reverse proxy)
- [Caddyfile](Caddyfile) — `api.lingochatul.com → app:80`, Let's Encrypt cert handled automatically
- [deploy.ps1](deploy.ps1) — what you run from your dev machine to ship a backend update

For first-deploy bootstrap, ops commands, and the full picture, see [DEPLOY.md](DEPLOY.md).
