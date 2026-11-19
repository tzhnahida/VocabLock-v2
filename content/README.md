# content packs

Content lives outside the framework. A pack is just a directory; drop it into
`content/packs/<id>/` and the server loads it at start-up (or after
`POST /api/v1/content/reload`). No Go code changes needed to add a dictionary,
a personal word list, or a graded list.

## Pack layout

```
content/packs/<id>/
  manifest.json   # required
  entries.jsonl   # required (or entries.jsonl.gz), one entry per line
  NOTICE.md       # optional attribution / license text
  media/          # optional audio files referenced by entry.audio
```

### manifest.json

```json
{
  "schema": 1,
  "id": "ja-jmdict-sample",
  "name": "JMdict common words (sample)",
  "language": "ja",
  "gloss_lang": "en",
  "version": "1.0.0",
  "license": "CC BY-SA 4.0",
  "attribution": "JMdict © EDRDG, via jmdict-simplified",
  "priority": 10
}
```

`priority` decides which pack wins when several packs define the same lemma:
higher priority supplies the display reading/POS, lower ones contribute extra
senses. Senses are merged, never silently dropped.

### entries.jsonl

```json
{"word":"泳ぐ","reading":"およぐ","pos":["v5g"],"senses":[{"glosses":["to swim"],"examples":[{"text":"毎日泳ぐ。","source":"user"}]}],"source":"jmdict","license":"CC BY-SA 4.0","frequency":0}
```

Only `word` is strictly required. `reading`, `pos`, `senses`, `source`,
`license` and `frequency` are optional; missing values fall back to the next
pack or to the AI provider.

## Merge rules

1. Lemma key = word with surrounding whitespace stripped, case-folded.
2. Packs are visited by descending `priority`.
3. The first pack with the key supplies `reading`, `pos` and the display gloss.
4. Every matching pack contributes its senses, deduplicated by gloss text; the
   originating pack id/license is kept on each sense.
5. If no pack has the word, the framework falls back to the configured external
   dictionary provider, then to AI (marked medium confidence).

## Sample packs

- `ja-jlpt-open` — 7,811 Japanese words tagged N5–N1 (OpenJLPT, CC BY-SA 4.0)
  with readings, POS and Tatoeba examples; rebuild with
  `content/tools/build-jlpt-pack.py`.
- `ja-jmdict-sample` — 108 common Japanese words from JMdict (English glosses,
  CC BY-SA 4.0), sample only.
- `ja-user-sample` — a tiny hand-written Chinese glossary that overlaps the
  other packs' lemmas, to demonstrate merging (priority 20 wins display).