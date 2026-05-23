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
_RE_READING_FW = re.compile(r"（(.+?)）")
_RE_POS_FW = re.compile(r"【(.+?)】")
# Half-width fallbacks: (kana) with optional pitch digit
_RE_READING_HW = re.compile(r"\(([ぁ-んァ-ヴー0-9]+?)\)")
# Circled numbers / pitch: ⓪①②③④⑤⑥⑦⑧⑨
_RE_PITCH = re.compile(r"[⓪①-⑨⑨]︎?")

# Known POS tokens for half-width entries (try longest match first)
_POS_TOKENS = [
    "名·自他动3", "名·他动3", "名·自动3",
    "自他动2", "自他动", "他动2", "他动", "自动2", "自动",
    "形容動詞", "形容詞", "形容", "名詞", "名",
    "副詞", "副", "接続詞", "接続", "接", "連体詞", "連体", "連",
    "感動詞", "感", "助動詞", "助詞", "助", "数詞", "数", "代名詞", "代",
    # Chinese-character variants (common in this dictionary)
    "名词", "动词", "形容词", "形容动词", "副词", "接续词", "连体词", "感叹词", "助词",
]


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

    # 1. Extract reading from value: （kana） or (kana)
    m = _RE_READING_FW.search(value)
    if not m:
        m = _RE_READING_HW.search(value)
    if m:
        reading = m.group(1)

    # 2. If no reading in value, try extracting from key: (kana)...
    if not reading and "(" in key:
        m = re.search(r"\((.+?)\)", key)
        if m:
            reading = m.group(1)

    # 3. Extract POS from value: 【POS】 first, then known half-width tokens
    m = _RE_POS_FW.search(value)
    if m:
        pos = m.group(1)
    else:
        for tok in _POS_TOKENS:
            if tok in value:
                pos = tok
                break

    # 4. Clean up value to get meaning
    meaning = value
    meaning = _RE_READING_FW.sub("", meaning)   # remove （kana）
    meaning = _RE_READING_HW.sub("", meaning)    # remove (kana)
    meaning = _RE_PITCH.sub("", meaning)         # remove pitch numbers
    meaning = _RE_POS_FW.sub("", meaning)        # remove 【POS】
    if pos:
        meaning = meaning.replace(pos, "", 1)
    meaning = meaning.strip()

    if not meaning:
        meaning = value.strip()

    # Build detail JSON with derived fields
    detail = {}
    # Syllable count: count kana characters in reading (excluding pitch digits)
    clean_reading = re.sub(r'[0-9]', '', reading)
    if clean_reading:
        detail["syllable_count"] = str(len(clean_reading))

    return {
        "reading": reading,
        "pos": pos,
        "meaning": meaning,
        "detail": json.dumps(detail, ensure_ascii=False) if detail else "",
    }


def lookup(word: str, data: dict) -> dict | None:
    # 1. Exact key match
    value = data.get(word)
    if value is not None:
        parsed = parse_entry(word, value)
        result = {"found": True, "word": word}
        result.update(parsed)
        return result

    # 2. Search for (kana)word — grammar patterns like (～が)欲しいです
    #    where the query might be just "欲しいです"
    for key, value in data.items():
        if key.endswith(word) and key.startswith("("):
            parsed = parse_entry(key, value)
            result = {"found": True, "word": key}
            result.update(parsed)
            return result

    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--word", required=True)
    args = parser.parse_args()

    data = load_dict(DICT_FILE)
    result = lookup(args.word, data)

    if result:
        sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))
        sys.exit(0)
    else:
        sys.stdout.buffer.write(json.dumps({"found": False}, ensure_ascii=False).encode("utf-8"))
        sys.exit(1)


if __name__ == "__main__":
    main()
