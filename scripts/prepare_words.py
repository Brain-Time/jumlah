#!/usr/bin/env python3
"""CSV -> words.json Pipeline fuer Jumlah (Task A1).

Liest eine CSV-Datei mit den Spalten arabic, german, root, frequency_rank,
validiert und normalisiert die Eintraege und schreibt sie sortiert nach
frequency_rank als JSON-Array nach assets/data/words.json.
"""

import argparse
import csv
import json
import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

REQUIRED_COLUMNS = ("arabic", "german", "root", "frequency_rank", "transliteration")
# Optionale Spalten: nur bei Verben gefuellt (Masdar/Verbalnomen), bei
# Nomen/Adjektiven/Partikeln leer.
OPTIONAL_COLUMNS = ("masdar", "masdar_transliteration", "masdar_german")

# Arabischer Unicode-Block (Buchstaben + Harakat/Tashkil)
ARABIC_WORD_RE = re.compile(r"^[؀-ۿ\s]+$")
# Wurzel: arabische Buchstaben, durch "-" getrennt (z.B. ك-ت-ب)
ARABIC_ROOT_RE = re.compile(r"^[؀-ۿ]+(-[؀-ۿ]+)*$")
# Harakat/Tashkil-Zeichen (Fatha, Damma, Kasra, Sukun, Tanwin, Shadda, Alif Khanjariya)
HARAKAT_RE = re.compile(r"[ً-ْٰ]")

GROUP_RANGES = (
    ("A1", 1, 500),
    ("A2", 501, 1000),
    ("B1", 1001, 2000),
    ("B2", 2001, 3000),
    ("C1", 3001, float("inf")),
)


def strip_harakat(text: str) -> str:
    return HARAKAT_RE.sub("", text)


def assign_group(frequency_rank: int) -> str:
    for group, lo, hi in GROUP_RANGES:
        if lo <= frequency_rank <= hi:
            return group
    raise ValueError(f"Kein Gruppenbereich fuer Rang {frequency_rank}")


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--input",
        default="scripts/sample_words.csv",
        help="Pfad zur Quell-CSV (Spalten: arabic, german, root, frequency_rank)",
    )
    parser.add_argument(
        "--output",
        default="assets/data/words.json",
        help="Pfad zur Ziel-JSON-Datei",
    )
    return parser.parse_args(argv)


def load_rows(input_path: Path) -> list[dict]:
    with input_path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in REQUIRED_COLUMNS if c not in (reader.fieldnames or [])]
        if missing:
            sys.exit(f"Fehlende Spalten in {input_path}: {', '.join(missing)}")
        return list(reader)


def process_rows(rows: list[dict]) -> tuple[list[dict], Counter]:
    skipped = Counter()
    seen = set()
    valid = []

    for row in rows:
        arabic = (row.get("arabic") or "").strip()
        german = (row.get("german") or "").strip()
        root_raw = (row.get("root") or "").strip()
        rank_raw = (row.get("frequency_rank") or "").strip()
        transliteration = (row.get("transliteration") or "").strip()
        masdar = unicodedata.normalize("NFC", (row.get("masdar") or "").strip())
        masdar_transliteration = (row.get("masdar_transliteration") or "").strip()
        masdar_german = (row.get("masdar_german") or "").strip()

        if not arabic or not german or not root_raw or not rank_raw or not transliteration:
            skipped["leeres Feld"] += 1
            continue

        if not rank_raw.isdigit() or int(rank_raw) < 1:
            skipped["ungueltiger Rang"] += 1
            continue
        frequency_rank = int(rank_raw)

        arabic = unicodedata.normalize("NFC", arabic)
        if not ARABIC_WORD_RE.match(arabic):
            skipped["ungueltige arabische Zeichen"] += 1
            continue

        root_raw = unicodedata.normalize("NFC", root_raw)
        if not ARABIC_ROOT_RE.match(root_raw):
            skipped["ungueltige Wurzel"] += 1
            continue
        root = strip_harakat(root_raw)

        dup_key = (arabic, frequency_rank)
        if dup_key in seen:
            skipped["Duplikat"] += 1
            continue
        seen.add(dup_key)

        valid.append(
            {
                "arabic": arabic,
                "german": german,
                "root": root,
                "frequency_rank": frequency_rank,
                "transliteration": transliteration,
                "masdar": masdar,
                "masdar_transliteration": masdar_transliteration,
                "masdar_german": masdar_german,
            }
        )

    return valid, skipped


def build_words(valid: list[dict]) -> list[dict]:
    valid.sort(key=lambda w: w["frequency_rank"])
    words = []
    for new_id, entry in enumerate(valid, start=1):
        words.append(
            {
                "id": new_id,
                "arabic": entry["arabic"],
                "german": entry["german"],
                "root": entry["root"],
                "group": assign_group(entry["frequency_rank"]),
                "frequency_rank": entry["frequency_rank"],
                "transliteration": entry["transliteration"],
                "masdar": entry["masdar"],
                "masdar_transliteration": entry["masdar_transliteration"],
                "masdar_german": entry["masdar_german"],
            }
        )
    return words


def print_stats(rows_read: int, words: list[dict], skipped: Counter) -> None:
    per_group = Counter(w["group"] for w in words)
    print(f"Eingelesene Zeilen:   {rows_read}")
    print(f"Gueltige Woerter:     {len(words)}")
    if skipped:
        print("Uebersprungen:")
        for reason, count in skipped.most_common():
            print(f"  - {reason}: {count}")
    else:
        print("Uebersprungen:        0")
    print("Woerter pro Gruppe:")
    for group, _, _ in GROUP_RANGES:
        print(f"  - {group}: {per_group.get(group, 0)}")


def main(argv=None) -> None:
    args = parse_args(argv)
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        sys.exit(f"Eingabedatei nicht gefunden: {input_path}")

    rows = load_rows(input_path)
    valid, skipped = process_rows(rows)
    words = build_words(valid)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(words, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print_stats(len(rows), words, skipped)
    print(f"Geschrieben: {output_path}")


if __name__ == "__main__":
    main()
