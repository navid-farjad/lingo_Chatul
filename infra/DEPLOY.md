# Deploy runbook — lingo_Chatul

This is the runbook for the next AI agent. Humans don't deploy this app;
they ask an agent to do it, and the agent reads this file and executes.
Everything here is scripted PowerShell + SSH that you can run directly
against the user's machine and the Hetzner box.

Both halves are **live** as of the last session — your job is usually
to ship a change to one of them, not to bootstrap from zero.

When in doubt:
- Frontend change → Section 2 ("ship a deploy")
- Backend change → Section 3 ("ship a deploy")
- Box rebuild → Section 3 ("first-deploy bootstrap")
- Adding card data to prod → Section 7
- Rotating a secret → Section 6 + the relevant ship-a-deploy step

Last updated: 2026-05-04.

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

### Ship a frontend deploy

```powershell
# Assumes the change is committed on main.
git push origin main:production

# Watch the Action; it usually finishes in ~40s.
gh run watch -R navid-farjad/lingo_Chatul --exit-status

# Verify
curl -sI https://app.lingochatul.com | head -1
```

If the Action fails, the most common causes are documented under "Quirks" below. If it's the **first** time `production` is being created, GitHub fires `CreateEvent` (not `PushEvent`) and the workflow won't auto-trigger — kick it off manually with `gh workflow run deploy-web.yml -R navid-farjad/lingo_Chatul --ref production`.

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

### Ship a backend deploy

Preferred path is to run the steps inline so you can react to errors,
rather than firing `infra/deploy.ps1` blind:

```powershell
$key = "$env:USERPROFILE\.ssh\lingo_chatul"

# 1. Make sure the change is on origin/main.
git status              # clean? if not, commit first
git push origin main

# 2. Pull on Hetzner, rebuild, recreate only what changed.
ssh -i $key root@49.12.247.57 @'
set -e
cd /opt/lingo && git fetch origin main && git reset --hard origin/main
cd infra
docker compose -f docker-compose.prod.yml --env-file ../.env build app
docker compose -f docker-compose.prod.yml --env-file ../.env up -d
docker compose -f docker-compose.prod.yml --env-file ../.env ps
'@

# 3. Verify.
Invoke-WebRequest -Uri "https://api.lingochatul.com/up" -UseBasicParsing -TimeoutSec 30
```

Caddy and Postgres stay up across deploys; Caddy keeps its issued cert.
Only the `app` container is recreated when its image changes.

If the `app` image fails to build, check that any new file under
`api/bin/` has the executable bit set in git (`git update-index --chmod=+x api/bin/<name>`); Windows checkouts strip it.

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

### Gotchas burned in previous sessions

- **Windows-stripped exec bit.** `api/bin/*` scripts must be mode 0755 in the git index. After adding any new binstub, run `git update-index --chmod=+x api/bin/<name> && git commit -m "fix: mark <name> executable"`. If you forget, the `app` container dies at startup with `exec: "/rails/bin/docker-entrypoint": permission denied`.
- **PowerShell `>` mangles UTF-8.** When piping a pgdump or any other text into a file from PowerShell, use `[System.IO.File]::WriteAllLines($path, $content, (New-Object System.Text.UTF8Encoding $false))`. Plain `>` writes UTF-16 LE which Postgres rejects with `ERROR: invalid byte sequence for encoding "UTF8": 0xff`.
- **Cloudflare API token reuse.** A single token (`CLOUDFLARE_DNS_TOKEN` in `.env`) handles DNS, R2, **and** Workers Scripts. The name is misleading — it has zone-edit + workers-scripts-edit + worker-routes-edit scopes. Don't create separate tokens; rotate this one.
- **No Kamal.** Earlier sessions tried and abandoned Kamal. The deploy is plain docker compose; do not reintroduce Kamal even when "rolling restart" looks tempting.
- **First-time `production` branch creation does not trigger the GitHub Action.** GitHub fires `CreateEvent` instead of `PushEvent`; the `paths:` filter doesn't match. Use `gh workflow run` once after creating, then subsequent pushes work normally.

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
├── ai-docs/
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

The Hetzner backend is **not** wired to a GitHub Action — agent sessions
deploy it directly via SSH (Section 3, "Ship a backend deploy"). Future
work could wire this into Actions if a CI runner gets the Hetzner SSH
key as a secret, but right now the simpler model is: user asks the
agent → agent runs the SSH commands → agent verifies.

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

### Rotating a secret

```powershell
$key = "$env:USERPROFILE\.ssh\lingo_chatul"

# 1. Edit .env locally (replace the value).
# 2. Rebuild the production .env on Hetzner from local .env + master.key.
$envLocal = Get-Content "$PWD\.env" -Raw
$masterKey = (Get-Content "$PWD\api\config\master.key" -Raw).Trim()
$hetznerEnv = $envLocal.TrimEnd() + "`n`nRAILS_MASTER_KEY=$masterKey`n"
$tmp = New-TemporaryFile; [System.IO.File]::WriteAllText($tmp, $hetznerEnv)
scp -i $key $tmp root@49.12.247.57:/opt/lingo/.env
Remove-Item $tmp
ssh -i $key root@49.12.247.57 'chmod 600 /opt/lingo/.env'

# 3. Restart the app to pick up the new env.
ssh -i $key root@49.12.247.57 'cd /opt/lingo/infra && docker compose -f docker-compose.prod.yml --env-file ../.env up -d app'

# 4. For GitHub-side secrets, also run:
#    gh secret set <NAME> -R navid-farjad/lingo_Chatul
```

---

## 7. Adding card data to production

`/api/v1/languages` returns `[]` until the production DB has cards. Two
paths, in order of preference:

**A) Push a pgdump from local dev (fast, free):**
```powershell
$key = "$env:USERPROFILE\.ssh\lingo_chatul"
$dump = "$env:TEMP\lingo_seed.sql"

# Note: pipe into [System.IO.File]::WriteAllLines, NOT `>`, to avoid UTF-16 BOM.
$sql = docker exec lingo_chatul_db pg_dump -U lingo_chatul -d lingo_chatul_development `
  --data-only --table=languages --table=words --table=cards
[System.IO.File]::WriteAllLines($dump, $sql, (New-Object System.Text.UTF8Encoding $false))

scp -i $key $dump root@49.12.247.57:/tmp/lingo_seed.sql
Remove-Item $dump

ssh -i $key root@49.12.247.57 @'
cd /opt/lingo/infra
docker compose -f docker-compose.prod.yml --env-file ../.env exec -T db \
  psql -U api -d api_production -v ON_ERROR_STOP=1 < /tmp/lingo_seed.sql
docker compose -f docker-compose.prod.yml --env-file ../.env exec -T db \
  psql -U api -d api_production -c "SELECT (SELECT COUNT(*) FROM languages) AS langs, (SELECT COUNT(*) FROM words) AS words, (SELECT COUNT(*) FROM cards) AS cards;"
rm /tmp/lingo_seed.sql
'@

Invoke-WebRequest -Uri "https://api.lingochatul.com/api/v1/languages" -UseBasicParsing
```

The image and audio URLs in the dump point at the same R2 bucket dev uses, so they work in prod with no rewriting. The dump contains data only; schema is already migrated by `db:prepare` on container start. **Note:** seeding clobbers existing rows on PK collision — for a true incremental update, use path B.

**B) Run the content pipeline against production:** copy CSV decks to the box, then `docker compose exec app bin/rails content:generate[deck_name]`. Hits AI services live, slow, costs API credits, but creates net-new cards rather than overwriting. Use this when adding a new language deck after the first launch.

---

## 8. Costs to keep in mind

- Cloudflare Workers Static Assets — free tier covers the SPA traffic
- Cloudflare R2 — pay per GB-stored, egress is free; expect a few cents/month
- Hetzner CX22 (or whatever the box is) — ~€4-6/mo
- Anthropic / Fal / ElevenLabs — pay-as-you-go, only triggered offline by `bin/rails content:generate`
