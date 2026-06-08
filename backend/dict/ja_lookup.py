#!/usr/bin/env python3
"""VocabLock Dict provider: Japanese (JamDict + JLPT).

Data sources:
  - dict/ja/jamdict.db   JamDict SQLite (kanji, kana, Chinese gloss, POS)
  - dict/ja/jlpt.csv      JLPT word-level classification

Protocol:
  --word {word}
  stdout: {"found":true, "word":"...", "reading":"...", "meaning":"...", "pos":"...", "level":"N1", "detail":"{}"}
  stdout: {"found":false}
  Exit: 0=hit, 1=miss, 2+=error.
"""

import argparse
import csv
import json
import os
import sqlite3
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.environ.get("JAMDICT_PATH", os.path.join(SCRIPT_DIR, "ja", "jamdict.db"))
JLPT_PATH = os.environ.get("JLPT_PATH", os.path.join(SCRIPT_DIR, "ja", "jlpt.csv"))

# ── JLPT level ────────────────────────────────────────────────

_jlpt: dict[str, str] | None = None


def _load_jlpt() -> dict[str, str]:
    levels: dict[str, str] = {}
    try:
        with open(JLPT_PATH, "r", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                expr = (row.get("expression") or "").strip()
                tags = (row.get("tags") or "").strip()
                if not expr:
                    continue
                for tag in tags.split():
                    if tag.startswith("JLPT_"):
                        levels[expr] = "N" + tag.rsplit("_", 1)[-1]
                        break
    except FileNotFoundError:
        pass
    return levels


def get_level(word: str) -> str:
    global _jlpt
    if _jlpt is None:
        _jlpt = _load_jlpt()
    return _jlpt.get(word, "")


# ── JamDict lookup ────────────────────────────────────────────

# Limit to 3 senses — first sense is the primary meaning. Chinese glosses first.
LOOKUP_SQL = """
SELECT
    kn.text AS kana,
    k.text  AS kanji,
    p.text  AS pos,
    sg.text AS gloss
FROM Entry e
JOIN Kana kn ON kn.idseq = e.idseq
LEFT JOIN Kanji k ON k.idseq = e.idseq
LEFT JOIN Sense s ON s.idseq = e.idseq
LEFT JOIN SenseGloss sg ON sg.sid = s.ID AND sg.lang = 'chn'
LEFT JOIN pos p ON p.sid = s.ID
WHERE k.text = ? OR kn.text = ?
ORDER BY s.ID, sg.lang
LIMIT 6
"""

# Garbage patterns in jamdict that should be filtered out
_GARBAGE_PATTERNS = ["误译", "重复条目", "同上"]

# POS mapping: jamdict English → Chinese
_POS_MAP = {
    "noun (common) (futsuumeishi)": "名词",
    "noun (common)": "名词",
    "noun": "名词",
    "Ichidan verb": "一段动词",
    "Godan verb": "五段动词",
    "transitive verb": "他动词",
    "intransitive verb": "自动词",
    "adjectival nouns or quasi-adjectives (keiyodoshi)": "形容动词",
    "adjectival noun": "形容动词",
    "adjective (keiyoushi)": "形容词",
    "adjective": "形容词",
    "interjection (kandoushi)": "感叹词",
    "interjection": "感叹词",
    "adverb (fukushi)": "副词",
    "adverb": "副词",
    "conjunction": "接续词",
    "particle": "助词",
    "auxiliary verb": "助动词",
    "prefix": "接头词",
    "suffix": "接尾词",
    "counter": "量词",
    "pronoun": "代词",
    "expressions (phrases, clauses, etc.)": "惯用表达",
    "noun or participle which takes the aux. verb suru": "名词/サ変动词",
    "nouns which may take the genitive case particle 'no'": "名词(の)",
    "noun, used as a prefix": "名词(接头)",
    "noun, used as a suffix": "名词(接尾)",
}


def _translate_pos(pos_en: str) -> str:
    """Map English POS from jamdict to Chinese."""
    pos_en = pos_en.strip().rstrip(";")
    for en, cn in _POS_MAP.items():
        if en in pos_en:
            return cn
    return pos_en  # keep original if no match


def _clean_gloss(text: str) -> str:
    """Filter garbage entries. Returns empty string if the gloss is bad data."""
    t = text.strip()
    if not t:
        return ""
    for g in _GARBAGE_PATTERNS:
        if g in t:
            return ""
    return t


def lookup_db(word: str) -> list[dict]:
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cur = conn.cursor()
        cur.execute(LOOKUP_SQL, (word, word))
        rows = [dict(r) for r in cur.fetchall()]
        conn.close()
        return rows
    except sqlite3.Error as e:
        print(f"jamdict error: {e}", file=sys.stderr)
        sys.exit(2)


def build_result(word: str, rows: list[dict]) -> dict | None:
    if not rows:
        return None

    kana = ""
    kanji = ""
    pos = ""
    glosses: list[str] = []
    seen = set()

    for r in rows:
        if not kana:
            kana = (r.get("kana") or "").strip()
        if not kanji:
            kanji = (r.get("kanji") or "").strip()
        if not pos:
            pos = _translate_pos((r.get("pos") or "").strip())

        g = _clean_gloss((r.get("gloss") or "").strip())
        if g and g not in seen:
            glosses.append(g)
            seen.add(g)

    if not kana and not kanji:
        return None

    reading = kana
    display = kanji if kanji else word
    meaning = "; ".join(glosses)

    level = get_level(word) or (get_level(display) if display != word else "")

    return {
        "found": True,
        "word": display,
        "reading": reading,
        "meaning": meaning,
        "pos": pos,
        "level": level,
        "detail": "{}",
    }


# ── Main ──────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--word", required=True)
    args = parser.parse_args()
    word = args.word.strip()

    if not word:
        sys.stdout.buffer.write(json.dumps({"found": False}, ensure_ascii=False).encode("utf-8"))
        sys.exit(1)

    rows = lookup_db(word)
    result = build_result(word, rows)

    if result:
        sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))
        sys.exit(0)
    else:
        sys.stdout.buffer.write(json.dumps({"found": False}, ensure_ascii=False).encode("utf-8"))
        sys.exit(1)


if __name__ == "__main__":
    main()
