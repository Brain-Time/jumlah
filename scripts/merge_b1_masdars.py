#!/usr/bin/env python3
"""Merges the curated masdar TSV into the B1 intake CSV (in place).

The masdar data lives in scripts/b1_masdars_etappe1.tsv (editorially curated,
Lane's-verified where markers were available). This script rewrites
scripts/b1_words_etappe1.csv with the masdar/masdar_transliteration/
masdar_german columns filled for every rank found in the TSV and validates
that all ranks in the CSV range are covered.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "scripts" / "b1_words_etappe1.csv"
TSV_PATH = ROOT / "scripts" / "b1_masdars_etappe1.tsv"


def main() -> int:
    masdars: dict[int, tuple[str, str, str]] = {}
    with TSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            masdars[int(row["rank"])] = (
                row["masdar"],
                row["masdar_transliteration"],
                row["masdar_german"],
            )

    rows = list(csv.DictReader(CSV_PATH.open(encoding="utf-8-sig", newline="")))
    changed = 0
    for row in rows:
        rank = int(row["frequency_rank"])
        m = masdars.get(rank)
        if m:
            row["masdar"], row["masdar_transliteration"], row["masdar_german"] = m
            changed += 1

    expected = sum(1 for r in rows)
    if changed != len(masdars):
        print(f"Fehler: {len(masdars)} Masdar-Eintraege, nur {changed} Zeilen gematcht")
        return 1

    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"ok: {changed} Masdar-Eintraege in {CSV_PATH.name} gemergt ({expected} Zeilen gesamt)")
    return 0


if __name__ == "__main__":
    sys.exit(main())