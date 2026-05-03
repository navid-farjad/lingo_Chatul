# lingo_Chatul — project guide for Claude

> A language-learning app that combines **image-mnemonic stories** with the **Leitner spaced-repetition system**. Words are anchored in long-term memory through **realistic, photographic cat scenes** ("chatul" = cat in Hebrew) tied to each word's sound and meaning.
>
> Greek-first; more languages added over time.

> **Note for the next agent.** The deploy story is "the user asks an AI agent and the AI deploys" — there is no human runbook. When the user says "deploy the API" or "ship this", **execute the steps in [infra/DEPLOY.md](infra/DEPLOY.md) directly**. The doc is written for you, not for a human; it includes exact PowerShell commands, secrets paths on disk, the Hetzner SSH key location, and the gotchas already burned by previous sessions. Read [infra/DEPLOY.md](infra/DEPLOY.md) and [ai-docs/](ai-docs/) before doing infra work — they capture state from previous sessions that won't be obvious from `git log`.

---

## The idea (do not lose sight of this)

Two techniques, combined:

1. **Leitner box** — 5-box spaced repetition. Cards move up on correct answers, back to box 1 on wrong. Intervals: 1 / 2 / 4 / 8 / 16 days.
2. **Image-mnemonic stories** — Claude writes a 1-2 sentence mnemonic that anchors the foreign word's sound to its meaning via a vivid scene featuring a cat. Fal AI nano-banana renders that scene as a **realistic photo** (not cartoon). ElevenLabs adds native pronunciation.

**Example.** καλημέρα ("kalimera" = good morning) → "A cat in a tiny bathrobe slaps a CALI-style sunrise poster on the fridge and yowls 'MERA mera mera!'"

The **realistic, photographic style is non-negotiable** — humor comes from the absurdity of the *situation*, not from a cartoon art style.

---

## Tech stack

| Layer | Choice | Why |
|---|---|---|
| Backend | **Rails 8 API** (Ruby 3.3) | Fast scaffolding, Solid Cache/Queue/Cable, Kamal for deploy |
| Database | **Postgres 16** | JSONB for `generation_metadata`, full-text later |
| Frontend | **React 19 + Vite + TS** | Fast HMR, fits Capacitor |
| Mobile | **Capacitor** wrap of the web app | One codebase → iOS + Android. NOT React Native. |
| Storage | **Cloudflare R2** (S3-compat) | Cheap, no egress fees |
| Story gen | **Anthropic Claude** (sonnet-4-6) | Best quality stories, JSON-mode responses |
| Image gen | **Fal AI nano-banana** (Gemini 2.5 Flash Image) | Photorealistic, fast |
| TTS | **ElevenLabs** (`eleven_multilingual_v2`) | Native-sounding pronunciation in many languages |
| Hosting | **Hetzner Cloud** + Kamal | Cheap, simple |
| DNS / CDN | **Cloudflare** (`lingochatul.com`) | Already where R2 lives |

---

## Repo layout

```
lingo_chatul/
├── api/                            # Rails 8 API
│   ├── app/
│   │   ├── controllers/api/v1/     # cards, sessions, reviews
│   │   ├── models/                 # Language, Word, Card, User, UserCardState
│   │   └── services/content_pipeline/
│   │       ├── story_generator.rb  # Claude
│   │       ├── image_generator.rb  # Fal AI nano-banana
│   │       ├── audio_generator.rb  # ElevenLabs
│   │       ├── r2_uploader.rb      # Cloudflare R2
│   │       └── orchestrator.rb     # Reads CSV, runs the full pipeline per word
│   └── lib/tasks/content.rake      # `bin/rails content:generate[deck_name]`
│
├── web/                            # Vite + React + TS
│   └── src/
│       ├── App.tsx                 # Routing between Review / Gallery views
│       ├── Card.tsx                # Flippable card component
│       ├── api.ts                  # Fetch wrapper + useSession hook
│       └── App.css
│
├── content-pipeline/seeds/         # CSV decks (greek_starter.csv, …)
├── infra/
│   ├── README.md                   # Pointer to DEPLOY.md
│   ├── DEPLOY.md                   # ⭐ HOW PROD IS DEPLOYED (CF Worker + Hetzner)
│   ├── docker-compose.prod.yml     # Production stack: db + app + caddy
│   ├── Caddyfile                   # api.lingochatul.com → app:80
│   └── deploy.ps1                  # ssh + git pull + docker compose build + up
├── .github/workflows/
│   └── deploy-web.yml              # Auto-deploys web/ on push to `production`
├── ai-docs/
│   └── add-content.md              # ⭐ HOW TO ADD WORDS OR LANGUAGES
├── docker-compose.yml              # Postgres + Rails dev container
├── scripts/bootstrap.ps1           # One-time scaffold (Rails + Vite via Docker)
├── .env / .env.example             # Local secrets (gitignored)
└── CLAUDE.md                       # This file
```

---

## Data model

```
Language (code, name, enabled)
  └─ Word (native, romanization, english, part_of_speech, notes)
       └─ Card (story_text, image_url, audio_url, generation_metadata, generated_at)
            └─ UserCardState (leitner_box, next_review_at, correct_count, …)

User (email?, password_digest?, device_token, tier: anonymous|free|paid, name?)
```

- **Anonymous** users get a `device_token` saved in `localStorage`. No account needed.
- A user can later add an email + password to the same record (tier becomes `free` or `paid`).
- All cards in `Card.ready` scope (i.e. with image+audio+story) are servable to the frontend.

---

## Key conventions

1. **Small batches first.** When generating AI content for a new language or expanding a deck, **always start with ≤20 words** and have the human review the output before scaling. The first deck for any new language should be `<lang>_smoke.csv` (1 word) or `<lang>_starter.csv` (~20 words). See [ai-docs/add-content.md](ai-docs/add-content.md).
2. **Realistic cat photography.** Every image prompt ends with `photorealistic, professional photography, hyperrealistic, natural lighting, 4k, sharp focus`. The cat must be central. No cartoon styling.
3. **Pre-generated content, not live.** AI calls happen offline in the rake task, NOT during user requests. The Rails API only serves pre-generated CDN URLs from the `cards` table.
4. **Idempotent pipeline.** Re-running `content:generate[deck]` skips words whose `Card` already has `image_url` and `audio_url`. Safe to re-run.
5. **Freemium tiers.** Anonymous: starter deck, local progress only. Free account: same deck, synced. Paid: full decks + new languages + advanced features. Don't gate the core loop behind payment.
6. **`X-Device-Token` header** is how the frontend authenticates. No JWTs in v1.

---

## Local development

```powershell
# One-time scaffold (only needed on a fresh clone, before first run)
./scripts/bootstrap.ps1            # generates api/ and web/ via Docker

# Daily
docker compose up -d                # Postgres + Rails API on :3000
npm --prefix web run dev            # Vite dev server on :5173
```

Then open http://localhost:5173.

---

## Adding content (READ THIS BEFORE GENERATING)

For any task involving **adding a new language, expanding a deck, regenerating a card, or tuning the AI prompt**, read **[ai-docs/add-content.md](ai-docs/add-content.md)**. It documents:

- CSV file naming and column conventions
- The two flows (new language vs more words for existing language)
- Where to source words (Anki shared decks, frequency lists, CEFR vocab)
- The validation gate (smoke → starter → full deck) — never skip this
- Voice configuration per language for ElevenLabs

---

## Deploy

Both halves are live. **The agent (you) is the deploy operator.** When the user says "deploy" or "ship", execute [infra/DEPLOY.md](infra/DEPLOY.md) — that doc is your runbook, not a human's reference.

TL;DR of what's already wired:
- **Frontend** at <https://app.lingochatul.com> — Cloudflare Worker `lingo-chatul-web`, auto-deploys on push to the `production` branch via [.github/workflows/deploy-web.yml](.github/workflows/deploy-web.yml). To ship a frontend change: `git push origin main:production` and watch the Action with `gh run watch`.
- **Backend** at <https://api.lingochatul.com> — plain docker compose stack on Hetzner `49.12.247.57` (Caddy → Rails → Postgres) defined in [infra/docker-compose.prod.yml](infra/docker-compose.prod.yml). To ship a backend change: commit to `main`, push, then SSH in to `git pull && docker compose build && up`. The exact PowerShell sequence is in [infra/deploy.ps1](infra/deploy.ps1) — preferred path is to invoke that script's contents directly, not run the script (so you can stream output and react to errors).
- Production secrets live in `/opt/lingo/.env` on Hetzner (mode 0600). Local copy at repo root (gitignored). When rotating, update both.
- SSH key for Hetzner: `~/.ssh/lingo_chatul`, user `root`.

---

## Don'ts

- **Don't** call the AI services from inside HTTP request handlers. They belong in the offline rake pipeline only.
- **Don't** generate images in cartoon, anime, or illustration style. Always photorealistic.
- **Don't** scale to a full deck without a human review pass on the smoke/starter batch first.
- **Don't** commit `.env`, `node_modules/`, or `api/log/` (already gitignored, just don't bypass).
- **Don't** introduce React Native, Expo, or another mobile framework. The plan is web + Capacitor.
