#!/usr/bin/env python3
"""Julius pronunciation assessment — mini-dict forced alignment.

Protocol:
    pronounce-julius.py --audio <wav> --text <target>
    -> stdout: {"score": 0.85, "aligned": "食べる", "n_score": -26.85}
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KIT_DIR = os.path.join(SCRIPT_DIR, "..", "kit")
JULIUS = os.path.join(KIT_DIR, "julius.exe")
MAIN_JCONF = os.path.join(KIT_DIR, "main.jconf")
AM_JCONF = os.path.join(KIT_DIR, "am-gmm.jconf")
FULL_DICT = os.path.join(KIT_DIR, "model", "lang_m", "bccwj.60k.htkdic")


def lookup_dict(target, dict_path):
    """Find all dictionary entries matching the target text."""
    entries = []
    target_lower = target.lower()
    with open(dict_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if len(parts) < 3:
                continue
            key = parts[0].split('+')[0]
            if key == target or key == target_lower:
                entries.append(line)
    return entries


def parse_state_alignment(text):
    """Parse Julius -salign output for per-phoneme scores.

    State format (triphone HMM, 3 states per phoneme):
        [  73   73]  -32.390381  t+a #1     — phoneme 't', state 1
        [  74   76]  -27.318644  t+a #2     — phoneme 't', state 2
        [  77   80]  -28.922882  t+a #3     — phoneme 't', state 3

    Triphone notation: left-ctx+right-ctx for first, left-ctx-center+right-ctx, etc.
    The center phoneme is extracted from the middle position.
    """
    pattern = re.compile(r'\[\s*(\d+)\s+(\d+)\]\s+([-\d.]+)\s+(\S+)\s+#(\d+)')
    matches = pattern.findall(text)
    if not matches:
        return None, []

    # Group states by phoneme
    phones = {}  # phoneme -> [(score, state_num)]
    for _from, _to, score_str, tri, state_num in matches:
        label = tri.split('-')[-1].split('+')[0] if '-' in tri else tri.split('+')[0]
        score = float(score_str)

        # Skip silence
        if label in ('silB', 'silE'):
            continue

        if label not in phones:
            phones[label] = []
        phones[label].append(abs(score))

    if not phones:
        return None, []

    # Compute per-phoneme normalized scores
    phoneme_scores = []
    all_scores = []
    for ph, scores in phones.items():
        avg = sum(scores) / len(scores)
        # Map n_score to 0-1: more negative -> worse. Range ~20-35
        norm = max(0.0, min(1.0, 1.0 - (avg - 20) / 15))
        phoneme_scores.append({
            "phoneme": ph,
            "score": round(norm, 3),
        })
        all_scores.append(norm)

    overall = round(sum(all_scores) / len(all_scores), 3) if all_scores else 0.0
    return overall, phoneme_scores


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parser = argparse.ArgumentParser(description="Julius pronunciation assessment")
    parser.add_argument("--audio", required=True, help="16kHz mono WAV file")
    parser.add_argument("--text", required=True, help="Target text (kana/kanji)")
    args = parser.parse_args()

    if not os.path.exists(args.audio):
        print(json.dumps({"score": 0, "error": f"audio not found: {args.audio}"}))
        sys.exit(1)
    if not os.path.exists(JULIUS):
        print(json.dumps({"score": 0, "error": "julius.exe not found"}))
        sys.exit(1)

    # Look up target in dictionary
    entries = lookup_dict(args.text, FULL_DICT)
    if not entries:
        print(json.dumps({"score": 0, "error": f"word not in dict: {args.text}"}))
        sys.exit(1)

    with tempfile.TemporaryDirectory() as tmpdir:
        # Mini dictionary: silence + target word only
        dict_path = os.path.join(tmpdir, "mini.dict")
        with open(dict_path, 'w', encoding='utf-8') as f:
            f.write("<s>\t[]\tsilB\n")
            f.write("</s>\t[。]\tsilE\n")
            for e in entries:
                f.write(e + "\n")

        # Filelist
        filelist = os.path.join(tmpdir, "filelist.txt")
        with open(filelist, 'w') as f:
            f.write(os.path.abspath(args.audio) + "\n")

        cmd = [
            JULIUS,
            "-C", MAIN_JCONF,
            "-C", AM_JCONF,
            "-input", "rawfile",
            "-filelist", filelist,
            "-v", dict_path,
            "-forcedict",
            "-salign",
            "-quiet",
        ]

        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True, encoding="utf-8", errors="replace",
                timeout=30,
                cwd=KIT_DIR,
            )
        except subprocess.TimeoutExpired:
            print(json.dumps({"score": 0, "error": "Julius timed out"}))
            sys.exit(1)

        combined = (proc.stdout or "") + "\n" + (proc.stderr or "")

        # Parse recognized sentence
        sentence_pattern = re.compile(r'sentence\d+:\s*(.+)')
        recognized = [m.strip() for m in sentence_pattern.findall(combined)]
        recognized_text = " ".join(recognized)

        score, phonemes = parse_state_alignment(combined)

        result = {
            "score": round(score, 3) if score else 0.0,
            "aligned": recognized_text,
            "phonemes": phonemes,
        }
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
