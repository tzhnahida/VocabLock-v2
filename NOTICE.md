# Third-Party Data & Tools

VocabLock uses the following external data and tools. None are included in
the main source tree — they are installed by users or community contributors.

## Dictionary Data

### jamdict.db
- **Source**: JamDict (Japanese-Multilingual Dictionary)
- **URL**: https://github.com/neocl/jamdict
- **License**: CC BY-SA 4.0 (inherited from JMdict/EDICT)
- **Contained data**: JMdict kanji/kana/gloss/POS (English glosses)
- **Usage**: `dict/ja/jamdict.db` — queried by `dict/ja_lookup.py`

### jlpt.csv
- **Source**: JLPT word-level classification
- **URL**: https://github.com/stephenmk/jlpt-vocab-list (derived from tanos.co.uk JLPT lists)
- **License**: CC BY 4.0
- **Usage**: `dict/ja/jlpt.csv` — cross-referenced by `dict/ja_lookup.py`

## Pronunciation Assessment

### Julius (pronounce-test/)
- **Source**: Julius — Open-Source Large Vocabulary Continuous Speech Recognition Engine
- **URL**: https://github.com/julius-speech/julius
- **License**: MIT License
- **Models**:
  - `kit/model/phone_m/` — JNAS triphone HMM (Japanese Newspaper Article Sentences)
  - `kit/model/lang_m/` — BCCWJ 60K dictionary + language model (Balanced Corpus of Contemporary Written Japanese)
  - `kit/model/dnn/` — DNN layers (backup, not enabled)
- **Usage**: `pronounce-test/bin/pronounce-julius.py` wraps Julius for pronunciation scoring

## Text-to-Speech

### Edge TTS
- **Source**: Microsoft Edge TTS (cloud service)
- **URL**: https://learn.microsoft.com/en-us/azure/cognitive-services/speech-service/
- **License**: Free for non-commercial use via Edge browser infrastructure
- **Usage**: `tts/ms_edge_tts.py` — thin wrapper calling Edge TTS API

## Notes

- All external binaries and data are kept outside the main source tree
  (in `dict/`, `tts/`, `pronounce-test/` under `test/` or user-provided paths).
- VocabLock itself does not distribute these files — users must obtain them
  separately from their respective sources.
- Community plugin protocol: any TTS/dict/pronounce binary following the
  protocol (CLI args → stdout JSON → exit codes) works without Go changes.
