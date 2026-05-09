# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project State

This is a **from-scratch rewrite** of VocabLock (v1 was Wails v2: Go + React/WebView2). v2 splits into **Flutter desktop UI + Go HTTP API service**. The full architecture specification is in `glistening-roaming-galaxy.md` — read it before any implementation work. No code has been written yet; the repo is at Phase 1 (Go backend).

## Build / Run / Test (expected)

Go modules haven't been initialized yet. Once `backend/` exists:

```bash
# Run all Go tests
go test ./...

# Run a specific test
go test ./internal/engine/ -v -run TestSM2

# Build the Go binary
go build -o vocablock.exe ./cmd/server/

# Run with mock mode (no AI, no SQLite, no external processes)
./vocablock.exe --mock

# Flutter (once frontend/ exists)
cd frontend && flutter pub get && flutter run -d windows
```

## Architecture

### Process model (2 processes)

```
VocabLock.exe (Go)
  ├── HTTP REST server (goroutine, random port)
  ├── Lock screen (goroutine, Win32 TOPMOST fullscreen window)
  ├── System tray (goroutine, dedicated OS thread)
  └── Spawns Flutter UI (child process, receives --api-port + --auth-token)
```

Flutter ↔ Go communicate via HTTP JSON on localhost. Go defines the API (OpenAPI 3.0). Flutter never imports Go, Go never imports Flutter. This allows swapping frontends without touching backend.

### Startup handshake

```
Go starts → picks random port → generates auth token → spawns Flutter
  → Flutter calls GET /health with token to confirm readiness
```

### Health monitoring (bidirectional)

- Flutter → Go: `GET /health` every 3s, 2 consecutive timeouts → recovery flow
- Go → Flutter: process liveness check every 5s, dead → auto-unlock + log

### Recovery (3 crash scenarios)

| Scenario | Lock window | User state | Recovery |
|----------|-------------|-------------|----------|
| Go panic (process alive) | Active, HTTP dead | Locked | Flutter shows "service interrupted" + force quit button → `taskkill /F /PID <go-pid>` |
| Go hard crash (OS kills) | Destroyed | Unlocked | Flutter shows "restart the app" |
| Go hung (unresponsive) | Active, HTTP timeout | Locked | Same as panic |

### Lock-screen UI escape (3-layer)

When the lock screen's TOPMOST window obscures Flutter during a hang:
1. **Ctrl+Shift+Q global hotkey** — Flutter registers via `RegisterHotKey` (user32.dll through Dart FFI), OS-level delivery bypasses TOPMOST
2. **Go dead-man switch** — Go's window thread ticks every 10s, checks own HTTP health, 3 consecutive failures → draws countdown + "Exit" button on the lock screen itself
3. **Ctrl+Alt+Del** — Windows SAS, always available, user kills process manually

### Directory layout (planned)

```
backend/
├── cmd/server/main.go
├── internal/
│   ├── api/               # HTTP handlers + middleware + routing
│   │   └── mock/          # Mock handlers for --mock mode
│   ├── engine/            # SM-2, question generation, word expansion, scheduler
│   │   └── judge/         # Answer judging: exact → regex → AI (3-tier with fallback)
│   ├── ai/                # DeepSeek client, prompt loading, response parsing
│   ├── tts/               # TTS provider dispatch + LRU cache (external binaries)
│   ├── dict/              # Dictionary provider dispatch (external binaries)
│   ├── db/                # SQLite (models, migrations, queries)
│   ├── system/            # OS-level: lock screen, tray, single instance, auto-start
│   └── config/            # YAML config loading + startup validation
├── configs/
│   ├── app.yaml           # Main config
│   ├── tts.yaml           # TTS provider definitions
│   ├── dict.yaml          # Dictionary provider definitions
│   ├── languages/         # Per-language definitions (ja.yaml, en.yaml, zh.yaml...)
│   └── prompts/           # AI prompt templates (embedded via go:embed, NOT shipped as files)
├── tts/                   # External TTS binaries
├── dict/                  # External dictionary binaries
└── data/                  # Runtime: SQLite DB, audio cache, logs

frontend/
├── lib/
│   ├── main.dart / app.dart
│   ├── api/               # Dio HTTP client, per-resource files
│   ├── models/            # Data classes
│   ├── screens/           # Lock screen, onboarding, completion, escape
│   ├── widgets/           # Question cards, audio player, reading view, word list...
│   ├── providers/         # State management
│   └── utils/             # Audio playback, error handling
└── pubspec.yaml
```

### API routes

```
QUIZ:    GET/POST /api/v1/quiz/*
WORDS:   CRUD    /api/v1/words/*   + expand, import, export, reset
AI:      /api/v1/ai/chat, profile
TTS:     /api/v1/tts/word/:id, text
STATS:   /api/v1/stats/heatmap, streak, daily-report
SYSTEM:  /api/v1/system/status, lock, unlock, passive-q, passive-submit, quit
CONFIG:  /api/v1/config, /api/v1/config/:key, /api/v1/config/password
```

### External binary protocol (TTS & Dictionary)

Go does NOT implement TTS or dictionary lookup — it only dispatches external binaries and manages caching.

**TTS**: args `[--voice {voice} --text {text} --write-media {output}]`, writes audio to output path, exit 0=success. Cache key is `MD5(provider:voice:text)`, 500-file LRU cache in `data/audio/`.

**Dictionary**: args `[--word {word}]`, stdout is one-line JSON (`{"found":true, "word":"...", "reading":"...", "meaning":"...", "pos":"..."}` or `{"found":false}`), exit 0=hit, 1=miss, 2+=error.

New providers that follow the protocol = zero Go code changes. Providers with different CLI signatures = write a wrapper script, still no Go changes.

**Command injection prevention**: YAML `command` is NOT a shell string. It's `binary` + `args[]` array. Go uses `exec.Command(binary, args...)` which goes directly to `CreateProcessW` — never through `cmd.exe`. User input like `{text}` or `{word}` is always a literal argument value.

**Zombie process prevention** (Windows): Job Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` — closing the job handle kills the entire process tree.

### Configuration: 3-layer YAML + startup validation

`tts.yaml` and `dict.yaml` define global provider lists. `languages/*.yaml` reference provider names. Adding a language = add voice to `tts.yaml` + add provider to `dict.yaml` + write `languages/xx.yaml`. Hot-switch via `PUT /api/v1/config` updating `active_lang` — no restart needed.

`config/validator.go` validates ALL configs at startup. Validation failure → abort with specific stderr errors. Runtime never sees config errors.

### AI fault tolerance

Core vocabulary question types (choice/fill/spelling/reading) have **zero AI dependency** — local template generation + exact/regex judging. If AI is down:
- Listening/reading/grammar questions stop generating; their proportion shifts to vocabulary questions
- AI word expansion stops (existing word bank unaffected)
- AI judging falls back to regex
- User can always complete daily target

AI timeout budget: judge 8s, generate 30s, expand 30s, chat 30s.

### SM-2 + study-before-test

"Preview" (study-before-test) is independent of SM-2 — showing word cards never alters SM-2 state. SM-2 `first_review` triggers on first answer submission, regardless of how many times the user previewed. New words have `next_review_at = NULL`, which `getReviewWords` prioritizes via `ORDER BY next_review_at ASC NULLS FIRST`.

### Mock mode

`--mock` flag enables mock handlers in `api/mock/` — no AI calls, no SQLite, no external process execution. Returns preset JSON. Designed for Flutter Phase 3 development without a working Go backend.

### Platform-specific code

`internal/system/` uses Go build tags (`//go:build windows`, `//go:build darwin`, `//go:build linux`) to select platform implementations of the `SystemProvider` interface (lock screen, tray, single instance, auto-start).

### Prompt templates

Embedded via `//go:embed prompts/*.yaml` into the Go binary — not shipped as readable files. Language configs (`languages/*.yaml`) are NOT embedded — users can edit these. Prompt files carry `version: "X.Y"` for traceability.
