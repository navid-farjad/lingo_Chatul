# Playbook — adding words or languages

> Read [CLAUDE.md](../CLAUDE.md) first for project context and core conventions.
> This file is the runbook for any content-generation task.

There are two flows. **Always identify which one you're in before starting.**

| Flow | Use when |
|---|---|
| **A. Add words to an existing language** | The language already has a `Card` row in the DB and a CSV in `content-pipeline/seeds/` |
| **B. Add a brand-new language** | First time we're adding any words for this language |

---

## The CSV format (canonical)

Every deck CSV lives at `content-pipeline/seeds/<deck_name>.csv` and has these columns, in this order:

```csv
native,romanization,english,part_of_speech,notes
καλημέρα,kalimera,good morning,interjection,greeting before noon
```

- **`native`** *(required)* — the word in its native script. For Greek, Greek script. For Japanese, kanji/kana. For languages already using Latin alphabet (Spanish, French), this is just the word.
- **`romanization`** *(optional but recommended)* — Latin transliteration so English speakers can sound it out. For Spanish, leave the same as `native` or empty. For Japanese, romaji.
- **`english`** *(required)* — the English meaning. Keep it short — one phrase, no parenthetical alternatives.
- **`part_of_speech`** *(optional)* — `noun`, `verb`, `adjective`, `interjection`, etc. Helps Claude pick a fitting scene.
- **`notes`** *(optional)* — anything that helps the story-writer (gender, etymology, common confusions, register). **Avoid double-quotes inside notes** — they break CSV parsing. Use plain text or apostrophes.

### Deck naming convention

`<language_lowercase>_<purpose>.csv`. Examples:
- `greek_smoke.csv` — 1-word smoke test for a new language or after a prompt change
- `greek_starter.csv` — ~20-word validation batch (CEFR A1)
- `greek_a1.csv` — full A1 deck (~500 words)
- `greek_a2.csv`, `greek_b1.csv`, …

The orchestrator parses the language from the **prefix before the first underscore** and looks it up in `LANGUAGE_BY_CODE` (in `api/app/services/content_pipeline/orchestrator.rb`).

---

## Flow A — adding more words to an existing language

1. **Find a source.** Don't hand-write 500 words. Sources, in order of preference:
   - **CEFR vocabulary lists** (A1 ≈ 500–700 words, A2 ≈ 1000–1500). Authoritative for what learners need first.
   - **Anki shared decks** at https://ankiweb.net/shared/decks — most are CC-licensed. Filter for the language. Export to `.txt` or use Anki's CSV export.
   - **Frequency lists** (e.g. Wiktionary's frequency lists, OpenSubtitles corpora). Top-1000 most common words is a strong default.

2. **Convert to our CSV format.** Map columns. Drop duplicates. Hand-pick if the source is huge — quality over quantity.

3. **Save to** `content-pipeline/seeds/<language>_<deck>.csv`.

4. **Smoke test (mandatory).** Pick 1–3 representative words from the new batch, save as `<language>_smoke.csv`, run:
   ```powershell
   docker compose run --rm api bin/rails "content:generate[<language>_smoke]"
   ```
   Open the generated images and check: realistic? cat is central? story memorable? audio correct? **If anything's off, don't scale** — fix the prompt, voice, or deck content first.

5. **Run the full deck:**
   ```powershell
   docker compose run --rm api bin/rails "content:generate[<language>_<deck>]"
   ```
   The pipeline is idempotent — words with complete cards are skipped.

6. **Review at least 10 random cards** in the gallery before declaring the batch done.

---

## Flow B — adding a brand-new language

Do these in order. **Don't skip step 1.**

### 1. Register the language code

Edit `api/app/services/content_pipeline/orchestrator.rb`:

- Add to `LANGUAGE_BY_CODE`:
  ```ruby
  "es" => { name: "Spanish" },
  ```
- Add to the `detect_language_code` mapping:
  ```ruby
  "spanish" => "es",
  ```

(For most major languages this is **already done** — check before editing.)

### 2. Pick the right ElevenLabs voice (if needed)

Default is **Bella** (`EXAVITQu4vr4xnSDxMaL`) with `eleven_multilingual_v2`, which works well for European languages and most major Asian/Middle-Eastern languages. If quality is poor for the target language, swap by passing `voice_id:` to `AudioGenerator.new`. ElevenLabs voice library: https://elevenlabs.io/app/voice-library.

Languages where the default voice may need replacing:
- Mandarin / Cantonese — try a native voice
- Arabic — try a native voice
- Tonal or non-Latin-script languages — review the smoke test very carefully

### 3. Build a smoke deck (1 word)

Create `content-pipeline/seeds/<language>_smoke.csv` with 1 well-known word. For Spanish:
```csv
native,romanization,english,part_of_speech,notes
hola,hola,hello,interjection,casual greeting
```

Run:
```powershell
docker compose run --rm api bin/rails "content:generate[<language>_smoke]"
```

Review the output. Is the cat scene memorable? Is the story cleverly tied to the word's sound? Is pronunciation correct?

### 4. Build a starter deck (~20 words)

Use CEFR A1 essentials — greetings, yes/no, water/food/house, basic verbs (be, have, want), numbers 1–5. Create `<language>_starter.csv`. Run pipeline. **Have the human review** before scaling further. This is the rule per [the small-batches convention](../CLAUDE.md#key-conventions).

### 5. Scale up

Only after starter deck is approved, build `<language>_a1.csv`, `<language>_a2.csv`, etc. using sources from Flow A.

### 6. Enable the language in the API

In a Rails console, ensure the `Language` row has `enabled: true`:
```ruby
Language.find_by(code: "es").update!(enabled: true)
```

(The orchestrator creates Language rows enabled by default, so this is usually a no-op — but verify.)

---

## What "good" looks like

Use these as the bar when reviewing generated cards:

| Aspect | Good | Bad |
|---|---|---|
| **Image style** | Realistic photo, natural lighting, soft focus background | Cartoon, anime, illustration, oil painting |
| **Cat presence** | A cat is the obvious subject of the scene | Cat is tiny in background, or absent |
| **Story → sound link** | The mnemonic capitalizes the syllable from the foreign word that the imagery is hooking into ("**CALI**-style sunrise") | Story doesn't reference the foreign word's sound at all |
| **Story length** | 1–2 sentences, vivid, surprising | Long paragraph, generic, "a cat does a thing" |
| **Audio** | Native pronunciation, clear, single word | Robotic, English-accented, distorted |
| **English meaning** | Short — "good morning", "thank you" | Long — "a polite expression used when greeting someone in the morning" |

---

## When the AI gets it wrong

If a card is bad, **don't manually edit the DB record**. Instead:

1. Delete the bad card so the orchestrator regenerates it on the next run:
   ```ruby
   # in Rails console
   Card.joins(:word).where(words: { native: "καλημέρα" }).destroy_all
   ```
2. Tune the prompt or voice settings in `api/app/services/content_pipeline/<service>.rb` if the issue is systematic.
3. Re-run `content:generate[<deck>]` — only the deleted cards regenerate.

If a whole batch came out bad (style drift, off-tone), revert the service file and re-run the smoke deck before retrying the full batch.

---

## Tuning the prompts

The two places worth tuning:

- **`story_generator.rb` `SYSTEM_PROMPT`** — controls story tone, syllable-capitalization style, and image-prompt format. Edit here if mnemonics feel weak across many words.
- **`image_generator.rb`** — currently passes the prompt straight through. If you want a global style override (e.g. "all images at golden hour"), edit the `prompt:` line to append style modifiers.

After any prompt change, **re-run the smoke deck and have a human review** before regenerating production cards.
