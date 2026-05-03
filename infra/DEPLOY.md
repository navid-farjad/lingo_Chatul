# Deploy guide — lingo_Chatul

How both halves of the app reach production. Read this before touching
`web/wrangler.jsonc`, `infra/docker-compose.prod.yml`, or any GitHub
Actions / Hetzner state.

Last updated: 2026-05-04. Both frontend and backend are **live**.

---

## 1. Architecture

```
┌────────────────────────┐                ┌──────────────────────────┐
│  app.lingochatul.com   │  HTTPS         │ api.lingochatul.com      │
│  (Cloudflare Worker —  │ ─────────────▶ │ (Hetzner box,             │
│   static SPA assets)   │   cross-origin │  Caddy → Rails app →      │
│                        │                │  Postgres in compose)     │
└────────────────────────┘                └──────────────────────────┘
        │                                          │
        │ static assets bundled in                  │ writes images / audio
        │ Cloudflare Workers Static Assets          │ to R2 via S3 API
        ▼                                          ▼
        served edge-side                     ┌──────────────────────┐
                                             │ Cloudflare R2 bucket │
                                             │  `lang` (public)     │
                                             └──────────────────────┘
```

| Host | Points to | Purpose | Proxied |
|---|---|---|---|
| `app.lingochatul.com` | Cloudflare Worker `lingo-chatul-web` (custom domain attachment) | SPA frontend | n/a (Workers) |
| `api.lingochatul.com` | A record → `49.12.247.57` | Rails API behind Caddy | DNS-only (HTTP-01 / TLS-ALPN-01 needs to reach origin) |

DNS records (Cloudflare zone `lingochatul.com`, zone ID `89c6ec5aee8eaf2d89195ea7f67e5671`):
- `api` A → `49.12.247.57` (record `f4f943e8318a01eb5a0ffe24c8728e79`, proxied=false)

Cloudflare account: `7d3108b03d75422190c487690eff151c`. R2 endpoint
`https://7d3108b03d75422190c487690eff151c.r2.cloudflarestorage.com`,
public CDN `https://pub-77b504a173c248358fc3f5e878d7bbf5.r2.dev`.

Hetzner box: `49.12.247.57`, `lingoChatul`, Ubuntu 24.04, Docker 29.4.2.
SSH user `root`, key at `~/.ssh/lingo_chatul`. Repo is checked out at
`/opt/lingo`. Production secrets in `/opt/lingo/.env` (mode 0600).

---

## 2. Frontend — Cloudflare Workers

### Files
- [web/wrangler.jsonc](../web/wrangler.jsonc) — Worker config (assets-only, SPA fallback, custom domain `app.lingochatul.com`)
- [web/src/api.ts:3](../web/src/api.ts#L3) — `API_BASE` reads `import.meta.env.VITE_API_BASE`, falls back to `http://localhost:3000` for dev
- [.github/workflows/deploy-web.yml](../.github/workflows/deploy-web.yml) — auto-deploys on push to `production`

### How a deploy happens
1. Commit on `main`.
2. `git push origin main:production` (or merge `main` → `production`).
3. The Action's `paths: web/**` filter matches; it runs `npm install && npm run build && wrangler deploy` in `web/`.
4. Cloudflare picks up the new bundle in seconds. Custom domain stays attached.

### GitHub repo settings
At <https://github.com/navid-farjad/lingo_Chatul>:

| Type | Name | Value |
|---|---|---|
| Secret | `CLOUDFLARE_API_TOKEN` | The `lingo_Chatul` Cloudflare token (also stored in `.env` as `CLOUDFLARE_DNS_TOKEN`) |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | `7d3108b03d75422190c487690eff151c` |
| Variable | `VITE_API_BASE` | `https://api.lingochatul.com` |

### Cloudflare API token scopes (minimum)
- `Account → Workers Scripts → Edit`
- `Account → Account Settings → Read`
- `User → User Details → Read`
- `Zone → Zone → Read` + `Zone → Workers Routes → Edit`

### Quirks worth knowing
- **First-deploy gotcha:** GitHub fires `CreateEvent` (not `PushEvent`) when a new branch is created, and a workflow with `paths:` filter does not run on `CreateEvent`. The first run was triggered manually via `gh workflow run deploy-web.yml --ref production`.
- **Lockfile platform skew:** the workflow uses `npm install --no-audit --no-fund` (not `npm ci`) because the lockfile generated on Windows misses some Linux-only optional deps.
- The old Vite scaffold's [web/src/index.css](../web/src/index.css) had a competing `:root` block and a `#root { width: 1126px; border-inline: ...; }` rule that fought `App.css`. It's been gutted; layout/theme lives in `App.css`.

---

## 3. Backend — Hetzner + docker compose

### Files
- [infra/docker-compose.prod.yml](docker-compose.prod.yml) — three services on the default compose network:
  - `db` — `postgres:16-alpine`, persistent volume `pg_data`
  - `app` — Rails image built from [api/Dockerfile](../api/Dockerfile) on the box
  - `caddy` — `caddy:2-alpine`, owns ports 80/443, auto-TLS via Let's Encrypt
- [infra/Caddyfile](Caddyfile) — `api.lingochatul.com → app:80` reverse proxy
- [infra/deploy.ps1](deploy.ps1) — what you run locally to ship a backend update
- [api/config/database.yml](../api/config/database.yml) — multi-database config; `default.host` reads `DB_HOST` (set to `db` in compose, falls back to `localhost` for `bin/rails db:setup` in dev)
- [api/config/initializers/cors.rb](../api/config/initializers/cors.rb) — production allow-list includes `https://app.lingochatul.com`
- [api/config/environments/production.rb](../api/config/environments/production.rb) — `assume_ssl`, `force_ssl`, hosts allow-list, ActiveStorage = `:r2`
- [api/config/storage.yml](../api/config/storage.yml) — `:r2` is the AWS S3 adapter pointed at the R2 endpoint

### Day-to-day deploy

```powershell
# From repo root, after you've committed + pushed to main:
./infra/deploy.ps1
```

This SSHs in, fast-forwards `/opt/lingo` to `origin/main`, rebuilds the
`app` image (cached layers), and restarts only the containers that
changed. Caddy and Postgres stay up; Caddy keeps its issued cert.

### First-deploy bootstrap (already done; reproduce only if rebuilding the box)

```powershell
$key = "$env:USERPROFILE\.ssh\lingo_chatul"

# 1. Install git, clone repo into /opt/lingo.
ssh -i $key root@49.12.247.57 'apt-get update -qq && apt-get install -y -qq git curl && mkdir -p /opt && cd /opt && git clone https://github.com/navid-farjad/lingo_Chatul.git lingo'

# 2. Build the production env file: local .env + RAILS_MASTER_KEY appended.
$envLocal = Get-Content "$PWD\.env" -Raw
$masterKey = (Get-Content "$PWD\api\config\master.key" -Raw).Trim()
$hetznerEnv = $envLocal.TrimEnd() + "`n`nRAILS_MASTER_KEY=$masterKey`n"
$tmp = New-TemporaryFile; [System.IO.File]::WriteAllText($tmp, $hetznerEnv)
scp -i $key $tmp root@49.12.247.57:/opt/lingo/.env
Remove-Item $tmp
ssh -i $key root@49.12.247.57 'chmod 600 /opt/lingo/.env'

# 3. First build + up.
ssh -i $key root@49.12.247.57 'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env up -d --build'
```

After the first `up`, Caddy obtains a Let's Encrypt cert (TLS-ALPN-01
challenge over port 443) within ~10 seconds. Verify:

```powershell
curl https://api.lingochatul.com/up                 # → 200
curl https://api.lingochatul.com/api/v1/languages   # → 200 []
```

### Database state
The Rails docker-entrypoint runs `db:prepare` on every boot, so on first
launch all four databases (`api_production`, `api_production_cache`,
`api_production_queue`, `api_production_cable`) get created and migrated
automatically. There's no seed data shipped — cards come from the
content pipeline; see Section 5.

### Migrations on subsequent deploys
Same — `db:prepare` runs on container start, applies pending migrations
in primary + cache + queue + cable databases, exits 0 if nothing to do.
No separate migration step needed.

### Logs and ops

```powershell
# Tail app logs
ssh -i $env:USERPROFILE\.ssh\lingo_chatul root@49.12.247.57 'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env logs -f app'

# Rails console
ssh -i $env:USERPROFILE\.ssh\lingo_chatul root@49.12.247.57 'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env exec app bin/rails console'

# psql
ssh -i $env:USERPROFILE\.ssh\lingo_chatul root@49.12.247.57 'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env exec db psql -U api -d api_production'

# Restart app only (e.g. after editing .env on the box)
ssh -i $env:USERPROFILE\.ssh\lingo_chatul root@49.12.247.57 'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env up -d app'
```

### A note on the exec bit
`api/bin/*` scripts must have `+x` mode in the git index so the Linux
container can run them. Windows checkouts strip the exec bit; we worked
around it via `git update-index --chmod=+x`. If you ever add a new
binstub, do the same:

```sh
git update-index --chmod=+x api/bin/<script>
git commit -m "fix: mark <script> executable"
```

If you forget, the `app` container will fail at startup with
`exec: "/rails/bin/docker-entrypoint": permission denied`.

---

## 4. Repo structure (current)

```
lingo_chatul/
├── api/                            # Rails 8 API
│   ├── Dockerfile                  # Production multi-stage build (Ruby 3.3, Thruster front)
│   ├── Dockerfile.dev              # Dev container used by docker-compose at the repo root
│   └── config/
│       ├── database.yml            # Multi-DB; default.host reads DB_HOST
│       ├── storage.yml             # :r2 ActiveStorage service via S3 adapter
│       ├── initializers/cors.rb    # Allows app.lingochatul.com in production
│       ├── environments/production.rb  # SSL, allowed hosts, ActiveStorage = :r2
│       └── master.key              # Decrypts Rails credentials (gitignored)
│
├── web/                            # Vite + React + TS, deployed to Cloudflare Workers
│   ├── wrangler.jsonc              # Worker config (assets, SPA fallback, custom domain)
│   ├── .env.example                # Documents VITE_API_BASE
│   └── src/
│       ├── api.ts                  # API_BASE = import.meta.env.VITE_API_BASE ?? localhost:3000
│       └── …                       # App.tsx, Card.tsx, App.css, vite-env.d.ts
│
├── content-pipeline/seeds/         # CSV decks (greek_starter.csv, hebrew_starter.csv, …)
│
├── infra/
│   ├── README.md                   # Pointer to this file
│   ├── DEPLOY.md                   # ⭐ this document
│   ├── docker-compose.prod.yml     # Production stack: db + app + caddy
│   ├── Caddyfile                   # api.lingochatul.com → app:80
│   └── deploy.ps1                  # ssh + git pull + docker compose build + up
│
├── .github/workflows/
│   └── deploy-web.yml              # Auto-deploys web/ on push to `production`
│
├── docs/
│   └── add-content.md              # How to add words / new languages
│
├── docker-compose.yml              # Local dev (Postgres + Rails)
├── scripts/bootstrap.ps1           # One-time scaffold
├── .env / .env.example             # Local secrets (gitignored)
├── CLAUDE.md                       # Top-level project guide
└── README.md
```

---

## 5. Branches

| Branch | Purpose | Triggers |
|---|---|---|
| `main` | Day-to-day development | Nothing automatic |
| `production` | Release branch for the web Worker | `paths: web/**` triggers `deploy-web.yml` on push |

The Hetzner backend is **not** wired to a GitHub Action — it's deployed
from a developer's machine via [infra/deploy.ps1](deploy.ps1). Future
work could wire this into Actions; the box already has Docker installed
and pulls from a public git repo, so all you need is an SSH deploy key
on the runner.

---

## 6. Where secrets live

| Secret | Local | GitHub | Hetzner |
|---|---|---|---|
| Cloudflare API token (Workers + DNS + Zone) | `.env` → `CLOUDFLARE_DNS_TOKEN` | Repo secret `CLOUDFLARE_API_TOKEN` | n/a |
| Cloudflare account ID | n/a | Repo secret `CLOUDFLARE_ACCOUNT_ID` | n/a |
| Anthropic API key | `.env` → `ANTHROPIC_API_KEY` | n/a | `/opt/lingo/.env` (same key) |
| Fal AI key | `.env` → `FAL_KEY` | n/a | same |
| ElevenLabs key | `.env` → `ELEVENLABS_API_KEY` | n/a | same |
| R2 access key / secret | `.env` → `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | n/a | same |
| Rails master key | `api/config/master.key` (gitignored) | n/a | `/opt/lingo/.env` → `RAILS_MASTER_KEY` (appended at bootstrap) |
| Postgres password | `.env` → `API_DATABASE_PASSWORD` (auto-generated) | n/a | same |

Rotation: edit `.env` locally, rerun the first-deploy bootstrap step 2
(rebuilds `/opt/lingo/.env`), then `./infra/deploy.ps1` to restart with
new values. For GitHub-side secrets use `gh secret set <NAME> -R navid-farjad/lingo_Chatul`.

---

## 7. Adding card data to production

The production DB is empty — `/api/v1/languages` returns `[]` until you
seed it. Two reasonable paths:

**A) Push a pgdump from local dev:**
```powershell
docker exec lingo_chatul_db pg_dump -U lingo_chatul -d lingo_chatul_development \
  --data-only --table=languages --table=words --table=cards \
  > prod_seed.sql
scp -i $env:USERPROFILE\.ssh\lingo_chatul prod_seed.sql root@49.12.247.57:/tmp/
ssh -i $env:USERPROFILE\.ssh\lingo_chatul root@49.12.247.57 \
  'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env exec -T db psql -U api -d api_production < /tmp/prod_seed.sql'
```

**B) Run the content pipeline against production:** copy the CSV decks
to the box and `bin/rails content:generate[deck_name]` inside the app
container. Hits the AI services live, costs API credits, slow.

(A) is faster and free if dev already has the cards generated.

---

## 8. Costs to keep in mind

- Cloudflare Workers Static Assets — free tier covers the SPA traffic
- Cloudflare R2 — pay per GB-stored, egress is free; expect a few cents/month
- Hetzner CX22 (or whatever the box is) — ~€4-6/mo
- Anthropic / Fal / ElevenLabs — pay-as-you-go, only triggered offline by `bin/rails content:generate`
