#!/usr/bin/env python3
"""VocabLock Dict provider: CC-CEDICT (Chinese-English).

Requires: cedict_ts.u8 (download from https://cc-cedict.org/wiki/format:syntax)
Save the file anywhere, point DICT_FILE below to its path.

Protocol:
  --word {word}
  stdout: {"found":true, "word":"...", "reading":"...", "meaning":"...", "pos":"..."}
  stdout: {"found":false}
  Exit: 0=hit, 1=miss, 2+=error.
"""

import argparse
import json
import os
import re
import sys

# Point this to your CC-CEDICT file
DICT_FILE = os.environ.get("CEDICT_PATH", "dict/zh/cedict_ts.u8")

# CEDICT line format: traditional simplified [pin1 yin1] /meaning1/meaning2/...
CEDICT_RE = re.compile(r"(\S+)\s+(\S+)\s+\[(.+?)\]\s+/(.+)/")


def load_dict(path: str) -> list[dict]:
    entries = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("#"):
                    continue
                m = CEDICT_RE.match(line)
                if m:
                    entries.append({
                        "trad": m.group(1),
                        "simp": m.group(2),
                        "pinyin": m.group(3),
                        "meaning": m.group(4).replace("/", "; "),
                    })
    except FileNotFoundError:
        print(f"dict file not found: {path}", file=sys.stderr)
        sys.exit(2)
    return entries


def lookup(word: str, entries: list[dict]) -> dict | None:
    for e in entries:
        if e["simp"] == word or e["trad"] == word:
            return {
                "found": True,
                "word": e["simp"],
                "reading": e["pinyin"],
                "meaning": e["meaning"],
                "pos": "",
            }
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--word", required=True)
    args = parser.parse_args()

    entries = load_dict(DICT_FILE)
    result = lookup(args.word, entries)

    if result:
        sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))
        sys.exit(0)
    else:
        sys.stdout.buffer.write(json.dumps({"found": False}, ensure_ascii=False).encode("utf-8"))
        sys.exit(1)


if __name__ == "__main__":
    main()
