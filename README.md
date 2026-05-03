# lingo_Chatul

A language-learning app that combines **image-mnemonic stories** with the **Leitner spaced-repetition system**. Words are taught through vivid, AI-generated cat scenes (chatul = cat) that anchor the meaning in long-term memory.

Starts with **Greek**. More languages added over time.

## Architecture

- **Backend:** Rails 8 API + Postgres
- **Frontend:** React + Vite (web)
- **Mobile:** Capacitor wrap of the web app → iOS + Android
- **Storage:** Cloudflare R2 (images + audio)
- **AI pipeline (offline rake task, not in request path):**
  - Stories → Anthropic Claude
  - Images → Fal AI (Google nano-banana)
  - Audio → ElevenLabs TTS
- **Deploy:** Hetzner via Kamal

## Repo layout

```
lingo_chatul/
├── api/                  # Rails 8 API + content pipeline rake tasks
├── web/                  # React + Vite, wrapped with Capacitor for mobile
├── infra/                # Hetzner / Kamal deploy config
├── .env                  # secrets (gitignored)
├── .env.example          # template
└── README.md
```

## Local development

Prerequisites:
- Docker Desktop running
- Git

First-time setup (generates Rails app and React app):
```powershell
# from repo root
Copy-Item .env.example .env       # then fill in real values
./scripts/bootstrap.ps1            # one-time scaffold of api/ and web/
```

Daily development:
```powershell
docker compose up                  # starts Postgres + Rails API on :3000
# in another terminal:
cd web; npm run dev                # starts React dev server on :5173
```

## Tiers

## Tiers

- **Anonymous** — free starter deck, progress saved on device
- **Free account** — same deck, progress synced across web/iOS/Android
- **Paid** — full decks, additional languages, advanced features

## Visual style

Every mnemonic image features **a realistic cat** doing something funny tied to the word's meaning. Realistic — not cartoon. The cat is the anchor that makes the word stick.

## Content pipeline (offline)

The `content-pipeline/` directory holds the rake task that:
1. Reads a CSV of words from `content-pipeline/seeds/` (start with `greek_starter.csv` — 20 essential words)
2. Generates a 1-2 sentence mnemonic story (Anthropic Claude)
3. Generates a realistic cat image illustrating that story (Fal AI nano-banana)
4. Generates pronunciation audio (ElevenLabs)
5. Uploads images and audio to Cloudflare R2
6. Inserts a `Card` row in Postgres

Run as a one-shot Rails task: `docker compose exec api bin/rails content:generate[greek_starter]`
