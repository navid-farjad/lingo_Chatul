# infra/

Production infrastructure docs for lingo_Chatul.

- **[DEPLOY.md](DEPLOY.md)** — comprehensive guide: how the frontend deploys to Cloudflare Workers (live), how the backend deploys to Hetzner via Kamal (in progress), known blockers, where secrets live, repo structure, branches.

## Quick reference

- Frontend: <https://app.lingochatul.com> (Cloudflare Worker `lingo-chatul-web`, auto-deploys on push to `production`)
- Backend: `api.lingochatul.com` → Hetzner `49.12.247.57` (deploy via `./bin/kamal.ps1 deploy` — currently blocked, see [DEPLOY.md §3](DEPLOY.md#3-backend--in-progress-))
- Domain: `lingochatul.com` (Cloudflare zone `89c6ec5aee8eaf2d89195ea7f67e5671`)
- SSH key: `~/.ssh/lingo_chatul`

For day-to-day deploys read [DEPLOY.md](DEPLOY.md). The Kamal config itself lives at [`api/config/deploy.yml`](../api/config/deploy.yml).
