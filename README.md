> AI-powered language learning. Not a ChatGPT wrapper — AI is the worker, SM-2 is the scheduler, dictionary is the gate, plugins are the ecosystem.

---

## Architecture

```
Go backend (HTTP REST API) ←→ Flutter desktop UI
         │
         ├── AI (DeepSeek) — word expansion, question generation, answer judging, session summary
         ├── SM-2 — spaced repetition scheduling
         ├── SQLite — vocabulary, grammar, review history
         └── External binary plugins:
              ├── Dictionary (community-provided, e.g. jamdict)
              ├── TTS (community-provided, e.g. edge-tts)
              └── Pronunciation assessment (community-provided, e.g. julius)
```

Go defines the plugin protocol; the community provides implementations. Adding a new dictionary, TTS engine, or pronunciation scorer requires zero Go changes.

## Daily Learning Loop

```
Startup → AI study plan generation
    ↓
Daily session:
    1. SM-2 fetches due reviews → if insufficient, AI expands new words
    2. New words → dictionary validation → level filter → insert into DB
    3. Study cards (read aloud, pronunciation scoring)
    4. Question loop (10 types, SM-2 tier progression)
    5. AI summary → update study plan
    ↓
Repeat daily
```

## Question Types

| Type | AI Dependency | Generation | Judging |
|------|:---:|------|------|
| choice | No | Local template | Exact match |
| fill | Minimal | Local template + sentence cloze | Exact → Regex → AI fallback |
| spelling | No | Local template | Exact match |
| pronounce | No | See word, type reading | Exact match |
| meaning | No | See word, type translation | Exact → AI fallback |
| read\_word | No | Read word aloud | External pron. scorer |
| read\_sentence | High | AI-generated sentence | External pron. scorer |
| grammar | High | AI-generated | AI judge |
| listening | High | AI-generated | AI judge |
| reading\_comp | High | AI-generated | AI judge |

Core vocabulary types (choice, fill, spelling, pronounce, meaning) have **zero AI dependency** — the daily target can always be completed even if AI is down.

## SM-2 Tier Progression

```
New word (NULL)        → tier 0: choice, pronounce, meaning, read_word
First review (≤3d)     → tier 1: same types, with review history
Mid-stage              → tier 2: fill, pronounce, meaning, spelling, read_word
Long-term (>14d, ≥4x)  → tier 3: all types including AI-generated
Wrong answer           → reset to tier 1, interval=1d
```

EF < 1.5 drops one tier. Sense expansion unlocks at tier 3 (new dissimilar meanings as separate SM-2 entries).

## Project Structure

```
backend/
├── cmd/server/          # Go entry point
├── configs/             # Config templates (_languages/, providers)
├── frontend/            # Flutter desktop UI
├── internal/
│   ├── ai/              # DeepSeek client + prompt templates
│   ├── api/             # HTTP handlers, router, middleware, mock
│   ├── config/          # YAML config loader + validator
│   ├── db/              # SQLite models, migrations, queries
│   ├── engine/          # SM-2, question types, selection, judging
│   ├── system/          # Lock screen, tray, passive quiz (Windows/Darwin/Linux)
│   ├── tts/             # TTS provider dispatch + LRU cache
│   ├── dict/            # Dictionary provider dispatch
│   └── pronounce/       # Pronunciation assessment dispatch
```

## Plugin Protocol

Community contributors write external binaries following these protocols:

**Dictionary:** `--word {word}` → stdout JSON `{"found":true, "word":"...", "reading":"...", "meaning":"..."}` → exit 0/1

**TTS:** `--voice {voice} --text {text} --write-media {output}` → exit 0

**Pronunciation:** `--audio {path} --text {target}` → stdout JSON `{"score": 0.85, "phonemes": [...]}` → exit 0

## Getting Started

### Prerequisites
- Go 1.22+
- Flutter 3.24+ (Windows desktop)
- SQLite

### Build

```bash
# Go backend
cd backend && go build -o vocablock.exe ./cmd/server/

# Flutter frontend
cd backend/frontend && flutter pub get && flutter build windows --release
```

### Run

```bash
./vocablock.exe            # zero-config mode (built-in language configs)
./vocablock.exe --mock     # mock mode (no AI, no SQLite, no external processes)
```

Set `VOCABLOCK_AI_KEY` environment variable for AI features (DeepSeek API).

### Config

Place provider configs and language files in `configs/`. Built-in defaults support `ja`, `zh`, `en`, `ko` with zero configuration.

## Key Design Decisions

- **Dictionary is the gate, not the source.** AI suggests words; dictionary validates them.
- **SM-2 manages review; AI manages new learning.** Clear separation of concerns.
- **Zero AI degradation.** Core question types work without AI.
- **Plugin protocol.** Community can add TTS/dict/pronounce without touching Go.
- **Zero-config startup.** Four languages built-in; no YAML required.
- **No hardcoding.** Everything is config/l10n except AI prompt English.

## License

MIT
