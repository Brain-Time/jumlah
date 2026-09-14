#!/usr/bin/env python3
"""words.json + root_definitions.csv -> roots.json Pipeline fuer Jumlah (Task A3).

Gruppiert die Woerter aus assets/data/words.json nach ihrer Drei-Buchstaben-
Wurzel und reichert jede Wurzel-Gruppe mit einer kuratierten klassischen
Definition aus scripts/root_definitions.csv an (Hybrid-Ansatz: Frequenz-
Lernpfad bleibt, zusaetzlich Wurzel-Cluster wie in Lane's Lexicon /
arabiclexicon.hawramani.com).

hawramani.com bietet keine API - Definitionen werden redaktionell in
root_definitions.csv gepflegt, nicht automatisiert gescraped.
"""

import argparse
import csv
import json
import re
import sys
import unicodedata
from pathlib import Path

ARABIC_ROOT_RE = re.compile(r"^[؀-ۿ]+(-[؀-ۿ]+)*$")

# Nomen enden in diesem Datensatz konsequent auf Tanwin (indefinit), Verben
# (Perfekt 3. Pers. Sg.) nicht - siehe Task-Notiz zu "Wurzel-Nomen in
# Arabischer Schrift" (Nutzer-Vorgabe, 27. August 2026). Darueber laesst
# sich zuverlaessig ein Beispiel-Nomen je Wurzel finden, ohne neue Daten zu
# erfinden, wenn ein solches Wort bereits in words.json existiert.
#
# Der frueher hier genutzte automatisierte Fallback (scripts/
# lookup_root_nouns.py, "kuerzestes tanwin-endendes Wort der lokalen
# Lane's-Lexicon-DB fuer diese Wurzel") wurde entfernt (Nutzer-Vorgabe,
# 27. August 2026): er lieferte haeufig ein voellig unverwandtes Homograph
# statt eines echten Masdars (z.B. قَرْءٌ "Menstruationszyklus" statt des
# Masdars قِرَاءَة von قَرَأَ). Fuer Verben zeigt die App jetzt stattdessen
# den echten, einzeln verifizierten Masdar direkt am Wort (`Word.masdar`,
# siehe scripts/prepare_words.py) statt eines geratenen Wurzel-Nomens.
TANWIN_ENDING_RE = re.compile(r"[ً-ٍ]$")


def example_noun_arabic(group_words: list[dict]) -> str:
    nouns = [w["arabic"] for w in group_words if TANWIN_ENDING_RE.search(w["arabic"])]
    return " / ".join(dict.fromkeys(nouns))


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--words",
        default="assets/data/words.json",
        help="Pfad zu words.json (liefert die Wurzel-Zuordnung)",
    )
    parser.add_argument(
        "--definitions",
        default="scripts/root_definitions.csv",
        help="Pfad zur CSV mit klassischen Definitionen je Wurzel",
    )
    parser.add_argument(
        "--output",
        default="assets/data/roots.json",
        help="Pfad zur Ziel-JSON-Datei",
    )
    return parser.parse_args(argv)


def load_words(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def load_definitions(path: Path) -> dict[str, dict]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in ("root", "classical_definition", "source") if c not in (reader.fieldnames or [])]
        if missing:
            sys.exit(f"Fehlende Spalten in {path}: {', '.join(missing)}")

        definitions = {}
        for row in reader:
            root = unicodedata.normalize("NFC", (row.get("root") or "").strip())
            definition = (row.get("classical_definition") or "").strip()
            source = (row.get("source") or "").strip()
            if not root or not definition or not source:
                continue
            if not ARABIC_ROOT_RE.match(root):
                continue
            fallback_noun = unicodedata.normalize(
                "NFC", (row.get("example_noun_arabic") or "").strip()
            )
            definitions[root] = {
                "classical_definition": definition,
                "source": source,
                "fallback_noun_arabic": fallback_noun,
            }
        return definitions


def group_by_root(words: list[dict]) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = {}
    for word in words:
        root = unicodedata.normalize("NFC", word["root"])
        groups.setdefault(root, []).append(word)
    return groups


def build_roots(groups: dict[str, list[dict]], definitions: dict[str, dict]) -> tuple[list[dict], list[str], list[str]]:
    roots = []
    missing_definitions = []

    for root, group_words in groups.items():
        definition = definitions.get(root)
        if definition is None:
            missing_definitions.append(root)
            continue
        related_word_ids = sorted(w["id"] for w in group_words)
        min_rank = min(w["frequency_rank"] for w in group_words)
        noun = example_noun_arabic(group_words)
        roots.append(
            {
                "root": root,
                "classical_definition": definition["classical_definition"],
                "source": definition["source"],
                "related_word_ids": related_word_ids,
                "example_noun_arabic": noun,
                "_sort_rank": min_rank,
            }
        )

    roots.sort(key=lambda r: r["_sort_rank"])
    for r in roots:
        del r["_sort_rank"]

    unused_definitions = sorted(set(definitions) - set(groups))
    return roots, missing_definitions, unused_definitions


def main(argv=None) -> None:
    args = parse_args(argv)
    words_path = Path(args.words)
    definitions_path = Path(args.definitions)
    output_path = Path(args.output)

    if not words_path.exists():
        sys.exit(f"words.json nicht gefunden: {words_path}")
    if not definitions_path.exists():
        sys.exit(f"Definitions-CSV nicht gefunden: {definitions_path}")

    words = load_words(words_path)
    definitions = load_definitions(definitions_path)
    groups = group_by_root(words)
    roots, missing_definitions, unused_definitions = build_roots(groups, definitions)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(roots, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Woerter eingelesen:        {len(words)}")
    print(f"Wurzel-Gruppen (words):    {len(groups)}")
    print(f"Definitionen (CSV):        {len(definitions)}")
    print(f"Roots geschrieben:         {len(roots)}")
    with_noun = sum(1 for r in roots if r["example_noun_arabic"])
    print(f"Davon mit Beispiel-Nomen:  {with_noun} / {len(roots)}")
    if missing_definitions:
        print(f"Ohne Definition (uebersprungen): {len(missing_definitions)}")
        for root in missing_definitions:
            print(f"  - {root}")
    if unused_definitions:
        print(f"Ungenutzte Definitionen (kein Wort mit dieser Wurzel): {len(unused_definitions)}")
        for root in unused_definitions:
            print(f"  - {root}")
    print(f"Geschrieben: {output_path}")


if __name__ == "__main__":
    main()
