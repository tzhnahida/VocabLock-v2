#!/usr/bin/env python3
"""Rebuild the ja-jlpt-open content pack from OpenJLPT.

Usage (from the repo root):
    python content/tools/build-jlpt-pack.py

Downloads the five level JSON files into a temp dir, flattens them into the
content-pack entry format and writes entries.jsonl.gz next to this pack's
manifest. Content is not embedded in the Go binary.
"""
import gzip
import json
import os
import tempfile
import urllib.request
from collections import OrderedDict

LEVELS = ["n5", "n4", "n3", "n2", "n1"]
BASE = "https://cdn.jsdelivr.net/gh/evanclan/openjlpt@main/data/json/vocab/{}.json"
OUT = os.path.join(os.path.dirname(__file__), "..", "packs", "ja-jlpt-open")

seen = OrderedDict()
with tempfile.TemporaryDirectory() as tmp:
    for lv in LEVELS:
        path = os.path.join(tmp, lv + ".json")
        urllib.request.urlretrieve(BASE.format(lv), path)
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for w in data:
            key = (w["word"], w.get("reading", ""))
            if key in seen:
                continue
            examples = [
                {"text": ex["ja"], "source": "tatoeba"}
                for ex in (w.get("examples") or [])[:2]
                if ex.get("ja")
            ]
            glosses = w.get("meanings") or []
            sense = {"glosses": glosses}
            if examples:
                sense["examples"] = examples
            seen[key] = {
                "word": w["word"],
                "reading": w.get("reading", ""),
                "pos": w.get("pos") or [],
                "level": w.get("level") or lv.upper(),
                "senses": [sense] if glosses else [],
                "source": "openjlpt",
                "license": "CC BY-SA 4.0",
                "frequency": 0,
            }

os.makedirs(OUT, exist_ok=True)
raw = b"".join(
    (json.dumps(e, ensure_ascii=False) + "\n").encode("utf-8") for e in seen.values()
)
with gzip.open(os.path.join(OUT, "entries.jsonl.gz"), "wb") as f:
    f.write(raw)
print(f"wrote {len(seen)} entries ({len(raw)/1e6:.2f} MB raw)")
