#!/usr/bin/env python3
"""Builds the B1 intake CSV from docs/b1-wortkandidaten.md (B1 Daten-Aufnahme).

The final B1 word list ("Finale B1-Wortliste — Ränge 1001–2000") is the
authoritative rank order; the Etappe sections provide the part-of-speech per
word. This script merges both sources for a rank range and writes the intake
CSV used by scripts/prepare_words.py (columns identical to sample_words.csv:
arabic,german,root,frequency_rank,transliteration,masdar,masdar_transliteration,
masdar_german).

Masdar (verbal noun) columns are left empty by this script: they are filled
editorially per intake Etappe (verified against Lane's-Lexicon "inf. n."
markers, see docs/todo-list.md, 27 August 2026 task).

Idempotent and reusable: pass --first-rank/--end-rank to extract a later
Etappe of the B1 range.

Example:
    python scripts/generate_b1_intake.py --first-rank 1001 --end-rank 1300 \
        --output scripts/b1_words_etappe1.csv
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "b1-wortkandidaten.md"

FINAL_LIST_HEADER = "## Finale B1-Wortliste — Ränge 1001–2000 (1000 Wörter)"
POS_HEADER = re.compile(r"^### (Verben|Nomen|Adjektive|Adverbien|Präpositionen|Zahlen)\s*\(")


def parse_final_list(text: str) -> list[dict]:
    """Parses the 'Finale B1-Wortliste' table -> rows in document order."""
    rows: list[dict] = []
    in_section = False
    for line in text.splitlines():
        if line.startswith(FINAL_LIST_HEADER):
            in_section = True
            continue
        if in_section:
            if line.startswith("## "):
                break
            if not line.startswith("| "):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) != 5 or cells[0] == "Rang":
                continue
            if cells[0] == "---" or not re.match(r"^\d+$", cells[0]):
                continue
            rank, arabic, translit, german, root = cells
            rows.append(
                {
                    "rank": int(rank),
                    "arabic": arabic,
                    "transliteration": translit,
                    "german": german,
                    "root": root,
                }
            )
    return rows


def parse_pos(text: str) -> dict[str, str]:
    """Parses the Etappe candidate tables -> word -> part of speech."""
    pos: dict[str, str] = {}
    current_pos: str | None = None
    for line in text.splitlines():
        # Level-2 headings ("## Etappe …") end the previous POS section;
        # level-3 headings ("### Verben …") start a new one.
        if line.startswith("## ") and not line.startswith("### "):
            current_pos = None
            continue
        m = POS_HEADER.match(line)
        if m:
            current_pos = m.group(1)
            continue
        if current_pos is None or not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4 or cells[0] in ("Arabisch", "---"):
            continue
        if any("\u0600" <= ch <= "\u06FF" for ch in cells[0]):
            pos.setdefault(cells[0], current_pos)
    return pos


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--first-rank", type=int, default=1001)
    parser.add_argument("--end-rank", type=int, default=1300)
    parser.add_argument("--output", default="scripts/b1_words_etappe1.csv")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    text = DOC.read_text(encoding="utf-8")

    rows = parse_final_list(text)
    if len(rows) != 1000:
        print(f"error: expected 1000 rows in final list, found {len(rows)}", file=sys.stderr)
        return 1

    selected = [r for r in rows if args.first_rank <= r["rank"] <= args.end_rank]
    if len(selected) != (args.end_rank - args.first_rank + 1):
        print(
            f"error: expected {args.end_rank - args.first_rank + 1} rows in range, "
            f"found {len(selected)}",
            file=sys.stderr,
        )
        return 1

    pos = parse_pos(text)

    output = ROOT / args.output
    with output.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "arabic",
                "german",
                "root",
                "frequency_rank",
                "transliteration",
                "masdar",
                "masdar_transliteration",
                "masdar_german",
            ]
        )
        for r in selected:
            p = pos.get(r["arabic"], "")
            if not p:
                print(
                    f"warning: no POS found for {r['arabic']} (rank {r['rank']})",
                    file=sys.stderr,
                )
            writer.writerow(
                [
                    r["arabic"],
                    r["german"],
                    r["root"],
                    r["rank"],
                    r["transliteration"],
                    "",  # masdar
                    "",  # masdar_transliteration
                    "",  # masdar_german
                ]
            )

    verbs = sum(1 for r in selected if pos.get(r["arabic"]) == "Verben")
    nouns = sum(1 for r in selected if pos.get(r["arabic"]) == "Nomen")
    adjs = sum(1 for r in selected if pos.get(r["arabic"]) == "Adjektive")
    advs = sum(1 for r in selected if pos.get(r["arabic"]) == "Adverbien")
    preps = sum(1 for r in selected if pos.get(r["arabic"]) == "Präpositionen")
    nums = sum(1 for r in selected if pos.get(r["arabic"]) == "Zahlen")
    missing_pos = sum(1 for r in selected if not pos.get(r["arabic"]))
    print(f"ok: {len(selected)} Wörter (Ränge {args.first_rank}–{args.end_rank})")
    print(
        f"  Verben: {verbs} · Nomen: {nouns} · Adjektive: {adjs} · Adverbien: {advs} · "
        f"Präpositionen: {preps} · Zahlen: {nums} · ohne POS: {missing_pos}"
    )
    print(f"  unique roots: {len({r['root'] for r in selected})}")
    print(f"Geschrieben: {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())