# Deploy guide — lingo_Chatul

This document captures **how the app gets to production**, what's already wired,
and what's still in progress. Read this before touching `web/wrangler.jsonc`,
`api/config/deploy.yml`, or any GitHub Actions / Hetzner state.

Last updated: 2026-05-04.

---

## 1. Architecture at a glance

```
┌────────────────────────┐                ┌──────────────────────────┐
│  app.lingochatul.com   │  HTTPS         │ api.lingochatul.com      │
│  (Cloudflare Worker —  │ ─────────────▶ │ (Hetzner box,             │
│   static SPA assets)   │   cross-origin │  Kamal Proxy + Rails +    │
│                        │                │  Postgres accessory)      │
└────────────────────────┘                └──────────────────────────┘
        │                                          │
        │ static assets served from                │ writes images / audio
        │ Cloudflare Workers Static Assets         │ to R2 via S3 API
        ▼                                          ▼
        bundled in the Worker                ┌──────────────────────┐
                                             │ Cloudflare R2 bucket │
                                             │  `lang` (public)     │
                                             └──────────────────────┘
```

### Domains
| Host | Points to | Purpose | Proxied |
|---|---|---|---|
| `app.lingochatul.com` | Cloudflare Worker `lingo-chatul-web` (custom domain attachment) | SPA frontend | n/a (Workers) |
| `api.lingochatul.com` | A record → `49.12.247.57` | Rails API behind Kamal Proxy | DNS-only (proxy off, so Let's Encrypt HTTP-01 challenge works) |

DNS record IDs (in Cloudflare zone `lingochatul.com`, zone ID `89c6ec5aee8eaf2d89195ea7f67e5671`):
- `api` A → `49.12.247.57` — record ID `f4f943e8318a01eb5a0ffe24c8728e79`, proxied=false

### Cloudflare account
- Account ID: `7d3108b03d75422190c487690eff151c`
- R2 endpoint: `https://7d3108b03d75422190c487690eff151c.r2.cloudflarestorage.com`
- R2 public CDN: `https://pub-77b504a173c248358fc3f5e878d7bbf5.r2.dev`
- API token in `.env` as `CLOUDFLARE_DNS_TOKEN` — note this single token now also has Workers Scripts:Edit and Zone:Read scopes (despite the name)

### Hetzner box
- IP `49.12.247.57`, hostname `lingoChatul`, Ubuntu 24.04, Docker 29.4.2 (installed by Kamal)
- SSH: user `root`, key at `~/.ssh/lingo_chatul`
- Currently running:
  - `registry:2` container on `172.17.0.1:5000` (a local Docker registry — see Section 4)
  - `buildx_buildkit_kamal-remote-ssh---root-49-12-247-570` (Kamal's BuildKit container, reusable)
  - **Not yet running:** Postgres accessory, Kamal Proxy, Rails app

---

## 2. Frontend — DEPLOYED ✅

### Stack
- React 19 + Vite 8 + TypeScript, hosted on Cloudflare Workers (Workers Static Assets, *not* Pages)
- Production URL: <https://app.lingochatul.com>
- Worker name: `lingo-chatul-web`

### Files
- [web/wrangler.jsonc](../web/wrangler.jsonc) — Worker config (assets-only, SPA fallback, custom domain `app.lingochatul.com`)
- [web/src/api.ts:3](../web/src/api.ts#L3) — `API_BASE` is read from `import.meta.env.VITE_API_BASE` at build time, falls back to `http://localhost:3000` for dev
- [web/.env.example](../web/.env.example) — documents `VITE_API_BASE`
- [.github/workflows/deploy-web.yml](../.github/workflows/deploy-web.yml) — auto-deploys on push to `production`

### How a production deploy happens
1. Commit changes on `main`.
2. `git push origin main:production` (or merge `main` → `production` in GitHub).
3. The Action triggers because `paths` filter matches `web/**` or the workflow file itself.
4. It runs `npm install && npm run build && wrangler deploy` in `web/`.
5. Cloudflare Workers picks up the new bundle within seconds; custom domain stays attached.

### GitHub repo settings
Stored at <https://github.com/navid-farjad/lingo_Chatul>:

| Type | Name | Value |
|---|---|---|
| Secret | `CLOUDFLARE_API_TOKEN` | The `lingo_Chatul` Cloudflare token (same token as `CLOUDFLARE_DNS_TOKEN` in `.env`) |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | `7d3108b03d75422190c487690eff151c` |
| Variable (not secret) | `VITE_API_BASE` | `https://api.lingochatul.com` |

### Cloudflare API token scopes (for the deploy)
The single `lingo_Chatul` custom token must include at minimum:
- `Account → Workers Scripts → Edit` ← required, deploy fails without it
- `Account → Account Settings → Read`
- `User → User Details → Read`
- `Zone → Zone → Read` + `Zone → Workers Routes → Edit` (for resolving the custom domain to the zone)

R2 / Workers AI / R2 SQL scopes are not needed for the Worker deploy itself.

### Quirks worth knowing
- **First-deploy gotcha:** GitHub fires a `CreateEvent` (not `PushEvent`) when a brand-new branch is created, and a workflow with a `paths:` filter does not run on a `CreateEvent`. The first production run was triggered manually via `gh workflow run deploy-web.yml --ref production`.
- **Lockfile platform skew:** `npm ci` is intolerant of optional native deps that aren't in the lockfile because it was generated on Windows. The workflow uses `npm install --no-audit --no-fund` instead.
- The old Vite scaffold's [web/src/index.css](../web/src/index.css) once contained `#root { width: 1126px; border-inline: 1px solid var(--border); ... }` and a competing `:root` block with a dark-mode override. It's been gutted; layout/theme lives entirely in `App.css`. Don't reintroduce styles there.

---

## 3. Backend — IN PROGRESS 🟡

The Rails 8 API targets `api.lingochatul.com` on Hetzner via Kamal. **Not yet
serving requests as of this writing.** The image builds and pushes; the missing
piece is that Kamal's `docker login` step on the Hetzner host fails for the
ghcr.io registry, so the deploy aborts before booting the Postgres accessory,
the Kamal Proxy, and the app container.

### What's wired
- [api/config/deploy.yml](../api/config/deploy.yml) — Kamal config:
  - Server: `49.12.247.57`
  - Image: `ghcr.io/navid-farjad/lingo-chatul-api`
  - Builder: **remote** on Hetzner via `ssh://root@49.12.247.57` — no local Ruby/Docker needed
  - SSH key explicitly pinned to `/root/.ssh/lingo_chatul` (inside the Kamal container) with `config: false`
  - Proxy: `ssl: true`, `host: api.lingochatul.com`, healthcheck `/up`
  - Postgres accessory: `postgres:16-alpine`, bound to `127.0.0.1:5432:5432`, persistent volume `data:/var/lib/postgresql/data`
  - Env: secrets (RAILS_MASTER_KEY, API_DATABASE_PASSWORD, ANTHROPIC_API_KEY, FAL_KEY, ELEVENLABS_API_KEY, R2 keys) + clear (R2 endpoint/bucket/public URL, DB_HOST, RAILS_LOG_TO_STDOUT)
- [api/.kamal/secrets](../api/.kamal/secrets) — sources `../.env` then re-exports each KEY=value; all production secrets live in `.env` (gitignored). The `RAILS_MASTER_KEY` is read from `config/master.key` (also gitignored). `KAMAL_REGISTRY_PASSWORD` is the GitHub PAT.
- [api/config/initializers/cors.rb](../api/config/initializers/cors.rb) — production allow-list includes `https://app.lingochatul.com`
- [api/config/environments/production.rb](../api/config/environments/production.rb) — `assume_ssl = true`, `force_ssl = true`, `hosts << "api.lingochatul.com"`, ActiveStorage service set to `:r2`
- [api/config/storage.yml](../api/config/storage.yml) — `:r2` service is the AWS S3 adapter pointed at the R2 endpoint
- [bin/kamal.ps1](../bin/kamal.ps1) — Windows PowerShell wrapper that runs `ghcr.io/basecamp/kamal:latest` in Docker because Ruby isn't installed on the host. It:
  - Mounts the repo at `/workdir` and SSH keys at `/host_ssh` (read-only, then copied into `/root/.ssh/` with 0600 perms)
  - Writes `/root/.ssh/config` so OpenSSH and Docker buildx both pick up `lingo_chatul` for `49.12.247.57`
  - Reads `KAMAL_REGISTRY_PASSWORD` from `.env` and stages `/root/.docker/config.json` so buildx can push to ghcr.io without an interactive `docker login`
  - Reads its prep script from [bin/kamal-prep.sh](../bin/kamal-prep.sh) (auto-generated each invocation, with LF line endings) to dodge PowerShell variable-expansion issues

### What's already done on Hetzner
- Docker installed (via `kamal setup`'s `get-docker.sh` step)
- `/root/.docker/config.json` populated with valid ghcr.io auth (we wrote it manually after `docker login` from Kamal's invocation kept failing — see "Known issues" below). Pulls work.
- `registry:2` container running on `172.17.0.1:5000` (started while exploring the local-registry workaround — can be left running or removed; doesn't affect ghcr.io path)
- `buildx_buildkit_kamal-remote-ssh---root-49-12-247-570` BuildKit container is up

### Image already in the registry
- `ghcr.io/navid-farjad/lingo-chatul-api:latest` (digest `sha256:63ed6bdad3601e44e30e79f7b6e7e2f21277e3e0c3371b162d7defa152ada112` at last successful push). Visibility may need to be flipped from private to public via the GitHub Packages UI if you want to skip auth on Hetzner.

### Database password
`API_DATABASE_PASSWORD` was auto-generated at deploy-prep time and is in `.env`. The Postgres accessory and the Rails app reuse the same value (`POSTGRES_PASSWORD=$API_DATABASE_PASSWORD` in [.kamal/secrets](../api/.kamal/secrets)).

### Known blockers — read before retrying

#### A) `docker login ghcr.io` from Kamal returns `denied: denied`
**Symptom.** During `kamal setup`/`kamal deploy`, the build + push step succeeds, then Kamal runs:
```
docker login ghcr.io -u [REDACTED] -p [REDACTED] on 49.12.247.57
```
which dies with `Get "https://ghcr.io/v2/": denied: denied`.

**Root cause.** Kamal's [registry login command](https://github.com/basecamp/kamal/blob/main/lib/kamal/commands/registry.rb) escapes the password via `Kamal::Utils.escape_shell_value`, which calls `String#dump` and wraps it in literal double-quotes. The SSH transport preserves those quotes, so docker on Hetzner sees the password as `"ghp_..."` (with the quote characters in it) and ghcr.io rejects it.

The same PAT works fine when run manually with single quotes (`-p '$pat'`), and `docker pull` continues to work using the credentials we wrote directly into `/root/.docker/config.json`.

**Three escape hatches**, in order of preference:

1. **Make the package public on ghcr.io** (https://github.com/users/navid-farjad/packages/container/lingo-chatul-api/settings → "Change visibility" → Public). Then **remove `username` and `password` from `registry:` in deploy.yml** entirely — Kamal will skip login because there's nothing to log in with, and pull will work unauthenticated. Build push still needs auth, which buildx already gets from `/root/.docker/config.json` staged by the wrapper. **This is the path we recommend trying first.**
2. **Switch to the local Hetzner registry** (already running at `172.17.0.1:5000`). To make Kamal recognize it as local and skip login, the registry server must literally start with the string `localhost` (Kamal's `Configuration::Registry#local?` does `server.match?("^localhost[:$]")`). That requires either binding the registry to `localhost:5000` AND running BuildKit with `--network=host` (Kamal supports `builder.driver_opts` — see `lib/kamal/commands/builder/base.rb:136` — but you also need to ensure the deploy targets reach `localhost:5000`, which works because they share the host).
3. **Patch Kamal in-image.** Mount a one-line replacement of `escape_shell_value` that doesn't wrap in quotes. Brittle; do not pursue.

The user's permission policy already declined a system-wide `/usr/local/bin/docker` wrapper that no-ops `docker login` — don't go down that road.

#### B) Docker Desktop (Windows) credential helper conflicts
Even with valid creds, `docker login ghcr.io` from the Windows host returned `denied: denied` until we fully bypassed the `desktop` credsStore. This doesn't affect the deploy (the build runs remotely on Hetzner) but is annoying for local debugging. If you need to test against ghcr.io from Windows, set `DOCKER_CONFIG` to a clean directory containing `{"auths":{}}` first.

#### C) gh CLI's OAuth token (`gho_…`) is rejected by ghcr.io
The token from `gh auth token` cannot push container images even with `write:packages` scope — ghcr.io requires a classic PAT (`ghp_…`) or fine-grained PAT. Don't try to reuse the gh OAuth token for `KAMAL_REGISTRY_PASSWORD`.

### Next agent's checklist to ship the API

```powershell
# From the repo root.

# 0. Confirm prerequisites are still in place:
ssh -i $env:USERPROFILE\.ssh\lingo_chatul root@49.12.247.57 'docker ps; cat /root/.docker/config.json | head -c 60; echo'
# Expect: registry container running, /root/.docker/config.json contains a valid ghcr.io auth blob

# 1. Decide: public ghcr.io image, or local registry. (Recommend the former.)
#    If public ghcr.io: open the package settings page on GitHub and flip visibility,
#    then EITHER remove `username`+`password` from registry: in api/config/deploy.yml
#    OR keep them — Kamal will still try login, which will still fail; visibility
#    alone doesn't fix the quoting bug.
#    The minimum fix that ships is: comment out username/password under `registry:`.

# 2. Run setup. Image and BuildKit are already cached on Hetzner so this is fast.
./bin/kamal.ps1 setup

# Expected stages after the build:
#   - Ensure kamal-proxy running   (boots basecamp/kamal-proxy on 80/443)
#   - Boot accessory db            (postgres:16-alpine)
#   - Boot app                     (pulls + runs Rails image)
#   - Verify proxy registration    (kamal-proxy fronts api.lingochatul.com)

# 3. Verify
curl -sf https://api.lingochatul.com/up   # → 200 OK from /rails/health#show

# 4. Seed initial card data. The production DB is empty.
./bin/kamal.ps1 app exec --interactive --reuse "bin/rails db:seed"
# OR import a pgdump from local dev:
#   docker exec lingo_chatul_db pg_dump -U lingo_chatul lingo_chatul_development > local.sql
#   scp local.sql root@49.12.247.57:/tmp/
#   ssh root@49.12.247.57 'docker exec -i $(docker ps -qf name=lingo-chatul-api-db) psql -U api api_production < /tmp/local.sql'
```

If `kamal setup` re-trips on `docker login` after you've removed `username`/`password`,
read the kamal-2.11.0 source at `lib/kamal/commands/registry.rb` — `login()` returns
early when `registry_config.local?` is true OR when `username`/`password` are nil.

---

## 4. Why a local registry on Hetzner exists right now

We started [registry:2](https://hub.docker.com/_/registry) on `172.17.0.1:5000`
(bound to the Docker bridge IP, not external) while exploring the workaround in
"Known issues — A". It's currently:
- Bound to the Docker bridge gateway so containers on `bridge` (and BuildKit) can
  reach it; not exposed to the public internet.
- Persisting layers in the named volume `registry_data`.

It's safe to leave running; it costs ~30 MB of RAM. To remove:
```sh
ssh root@49.12.247.57 'docker rm -f registry && docker volume rm registry_data'
```

If we end up using it for real, deploy.yml needs:
```yaml
registry:
  server: 172.17.0.1:5000
  # Kamal will still try to log in here. Either omit username/password, or set
  # both to dummy values; an unauthenticated registry:2 accepts anything.
```
…and the Hetzner Docker daemon needs `/etc/docker/daemon.json` to allow
`172.17.0.1:5000` as an insecure registry, plus BuildKit's container needs
`network=host` so it can reach the bridge IP from inside the BuildKit network
namespace. None of that is configured today.

---

## 5. Repo structure (current, post-deploy work)

```
lingo_chatul/
├── api/                            # Rails 8 API
│   ├── .kamal/
│   │   ├── hooks/                  # Kamal lifecycle hooks (samples only, unused)
│   │   └── secrets                 # Sources ../.env, re-exports for Kamal
│   ├── config/
│   │   ├── deploy.yml              # Kamal target = Hetzner, ghcr.io image, postgres accessory
│   │   ├── database.yml            # Multi-DB (primary, cache, queue, cable) for Solid* gems
│   │   ├── storage.yml             # :r2 ActiveStorage service via S3 adapter
│   │   ├── initializers/cors.rb    # Allows app.lingochatul.com in production
│   │   ├── environments/production.rb  # SSL, allowed hosts, ActiveStorage = :r2
│   │   └── master.key              # Decrypts Rails credentials (gitignored, exists locally)
│   ├── Dockerfile                  # Production multi-stage build (Ruby 3.3, Thruster front)
│   └── Dockerfile.dev              # Dev container used by docker-compose
│
├── web/                            # Vite + React + TS, deployed to Cloudflare Workers
│   ├── wrangler.jsonc              # Worker config (assets, SPA fallback, custom domain)
│   ├── .env.example                # Documents VITE_API_BASE
│   ├── package.json                # `npm run deploy` invokes wrangler
│   └── src/
│       ├── api.ts                  # API_BASE = import.meta.env.VITE_API_BASE ?? localhost:3000
│       ├── App.tsx, Card.tsx, App.css   # See web/ for the actual feature work
│       └── vite-env.d.ts           # Types for VITE_* env vars
│
├── content-pipeline/seeds/         # CSV decks (greek_starter.csv, hebrew_starter.csv, …)
│
├── infra/
│   ├── README.md                   # Pointer to this file
│   └── DEPLOY.md                   # ⭐ this document
│
├── bin/
│   └── kamal.ps1                   # Windows wrapper for the basecamp/kamal Docker image
│   # kamal-prep.sh is generated by kamal.ps1 at runtime — do not edit by hand
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

## 6. Branches

| Branch | Purpose | Triggers |
|---|---|---|
| `main` | Day-to-day development | Nothing automatic |
| `production` | Release branch for the web Worker | `paths: web/**` triggers `deploy-web.yml` on push |

The Kamal API deploy is **not** wired to a GitHub Action — it's run from a
developer's machine via `./bin/kamal.ps1 deploy`. There's no CI for the API
yet; setting one up would require provisioning Docker + BuildKit + ssh keys
in the runner, and a way to push to ghcr.io without `docker login` (i.e. it
hits the same Section 3.A blocker, but with a fresh runner each time).

---

## 7. Where secrets live

| Secret | Local (gitignored) | GitHub | Hetzner |
|---|---|---|---|
| Cloudflare API token (Workers + DNS + Zone) | `.env` → `CLOUDFLARE_DNS_TOKEN` | Repo secret `CLOUDFLARE_API_TOKEN` | n/a |
| Cloudflare account ID | n/a (public-ish) | Repo secret `CLOUDFLARE_ACCOUNT_ID` | n/a |
| GitHub PAT (`write:packages`) | `.env` → `KAMAL_REGISTRY_PASSWORD` | n/a (only used from local Kamal runs) | `/root/.docker/config.json` (base64 user:pass) |
| Anthropic API key | `.env` → `ANTHROPIC_API_KEY` | n/a | Injected into Rails container via Kamal env secrets |
| Fal AI key | `.env` → `FAL_KEY` | n/a | Same |
| ElevenLabs key | `.env` → `ELEVENLABS_API_KEY` | n/a | Same |
| R2 access key / secret | `.env` → `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | n/a | Same |
| Rails master key | `api/config/master.key` (gitignored, 32 bytes) | n/a | Same (secret env `RAILS_MASTER_KEY`) |
| Postgres password | `.env` → `API_DATABASE_PASSWORD` (auto-generated) | n/a | Postgres accessory env `POSTGRES_PASSWORD` |

When rotating any of these, update `.env` first; the Kamal pipeline
re-reads it on every deploy. For the GitHub-side secrets, use
`gh secret set <NAME> -R navid-farjad/lingo_Chatul`.

---

## 8. Costs to keep in mind

- Cloudflare Workers Static Assets: free tier covers the SPA traffic
- Cloudflare R2: pay per GB-stored + egress is free; expect a few cents/month for the current deck size
- Hetzner CX22 (or whatever the box is): roughly €4-6/mo
- ghcr.io: free for public packages; private packages get 500 MB free per user, then $0.25/GB/month
- Anthropic / Fal / ElevenLabs: pay-as-you-go, usage capped by the offline pipeline (`bin/rails content:generate`)
