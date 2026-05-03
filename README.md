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
- Node.js 20+
- Docker Desktop (runs Postgres + Rails containers)
- Git

Setup:
```bash
cp .env.example .env       # then fill in real values
# (folders below are added in subsequent setup steps)
```

## Tiers

- **Anonymous** — free starter deck, progress saved on device
- **Free account** — same deck, progress synced across web/iOS/Android
- **Paid** — full decks, additional languages, advanced features
