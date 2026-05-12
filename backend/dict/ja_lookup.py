#!/usr/bin/env python3
"""VocabLock Dict provider: Japanese-Chinese thesaurus.

Data source: https://github.com/lxl66566/Japanese-Chinese-thesaurus
Download final.json from Releases, point JADICT_PATH to it.

Protocol:
  --word {word}
  stdout: {"found":true, "word":"...", "reading":"...", "meaning":"...", "pos":"..."}
  stdout: {"found":false}
  Exit: 0=hit, 1=miss, 2+=error.

Value format (regular words):
  （kana）pitch【POS】meaning
  e.g.  食べる → （たべる）②【他动2】吃

Key format (grammar patterns, only ~49 entries):
  (kana)pattern
  e.g.  (～が)欲しいです
"""

import argparse
import json
import os
import re
import sys

DICT_FILE = os.environ.get("JADICT_PATH", "dict/ja/final.json")

# Full-width： U+FF08  U+FF09  【 U+3010  】 U+3011
_RE_READING = re.compile(r"（(.+?)）")
_RE_POS = re.compile(r"【(.+?)】")
# Circled numbers / pitch: ⓪①②③④⑤⑥⑦⑧⑨
_RE_PITCH = re.compile(r"[⓪①-⑨⑨]︎?")


def load_dict(path: str) -> dict:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"dict file not found: {path}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as e:
        print(f"dict file parse error: {e}", file=sys.stderr)
        sys.exit(2)
    return data


def parse_entry(key: str, value: str) -> dict:
    """Parse a single dict entry into {reading, pos, meaning}."""
    reading = ""
    pos = ""
    meaning = ""

    if not isinstance(value, str):
        value = str(value)

    # 1. Extract reading from value: （kana）
    m = _RE_READING.search(value)
    if m:
        reading = m.group(1)

    # 2. If no reading in value, try extracting from key: (kana)...
    if not reading and "(" in key:
        m = re.search(r"\((.+?)\)", key)
        if m:
            reading = m.group(1)

    # 3. Extract POS from value: 【POS】
    m = _RE_POS.search(value)
    if m:
        pos = m.group(1)

    # 4. Clean up value to get meaning: strip reading, pitch, POS markers
    meaning = value
    meaning = _RE_READING.sub("", meaning)  # remove （kana）
    meaning = _RE_PITCH.sub("", meaning)    # remove pitch numbers
    meaning = _RE_POS.sub("", meaning)      # remove 【POS】
    meaning = meaning.strip()

    # If value only had metadata and meaning is empty, use the whole value
    if not meaning:
        meaning = value.strip()

    return {
        "reading": reading,
        "pos": pos,
        "meaning": meaning,
    }


def lookup(word: str, data: dict) -> dict | None:
    # 1. Exact key match
    value = data.get(word)
    if value is not None:
        parsed = parse_entry(word, value)
        return {"found": True, "word": word, **parsed}

    # 2. Search for (kana)word — grammar patterns like (～が)欲しいです
    #    where the query might be just "欲しいです"
    for key, value in data.items():
        if key.endswith(word) and key.startswith("("):
            parsed = parse_entry(key, value)
            return {"found": True, "word": key, **parsed}

    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--word", required=True)
    args = parser.parse_args()

    data = load_dict(DICT_FILE)
    result = lookup(args.word, data)

    if result:
        json.dump(result, sys.stdout, ensure_ascii=False)
        sys.exit(0)
    else:
        json.dump({"found": False}, sys.stdout, ensure_ascii=False)
        sys.exit(1)


if __name__ == "__main__":
    main()
