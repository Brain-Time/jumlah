#!/usr/bin/env python3
"""Ergaenzt die Spalte `example_noun_arabic` in root_definitions.csv fuer
Wurzeln, die noch kein passendes Nomen als eigene Vokabel besitzen (Task
G4-Folgeaufgabe, Nutzer-Vorgabe 27. August 2026).

Nutzt die lokale Lane's-Lexicon-SQLite-DB (assets/LexiconDatabase/
lexicon.sqlite, echter TEI-XML-Volltext, kostenlos und ohne Rate-Limit
abfragbar - wie schon bei Task A1b) statt neue Arabisch-Daten zu erfinden:
je Wurzel wird unter allen Lexikon-Eintraegen dieser Wurzel das kuerzeste
Wort ausgewaehlt, das auf Tanwin endet (in diesem Projekt die konsequente
Nomen-Markierung, siehe scripts/build_roots.py) und keine Leerzeichen
enthaelt (schliesst mehrwoertige Beispielphrasen aus) - die kuerzeste
Tanwin-Form entspricht meist dem einfachsten/gebraeuchlichsten Verbalnomen-
Muster (فَعْل/فِعْل/فُعْل) statt einer stark abgeleiteten Partizip-Form.

WICHTIG: Partikel-Platzhalter-Wurzeln (Praepositionen/Konjunktionen, deren
`source`-Spalte "Grammatikalische Funktion" erwaehnt) werden bewusst
uebersprungen - ihre Buchstabenfolge ist zufaellig identisch mit echten,
inhaltlich unverwandten Lexikon-Wurzeln (z.B. "من" als Praeposition vs. die
echte Wurzel م-ن-ن "eine Gunst erweisen"); eine automatische Zuordnung
wuerde dort irrefuehrende Nomen zeigen.

Ergebnis manuell stichprobenartig gegen die Definitionen in
root_definitions.csv geprueft (27. August 2026) - die meisten Treffer
entsprechen exakt oder eng verwandt dem in der Definition bereits
genannten transliterierten Nomen (z.B. ذَهْبٌ fuer ذ-ه-ب, "dhahab").
Fuer Wurzeln ganz ohne Tanwin-Treffer in der DB bleibt die Spalte leer -
das ist von `build_roots.py`/`_RootSection` (learn_screen.dart) bereits
als "kein Beispiel-Nomen verfuegbar" vorgesehen.

Erneut ausfuehrbar, ueberschreibt die Spalte fuer alle Zeilen.
"""

from __future__ import annotations

import csv
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFINITIONS_PATH = ROOT / "scripts" / "root_definitions.csv"
LEXICON_PATH = ROOT / "assets" / "LexiconDatabase" / "lexicon.sqlite"

TANWIN_ENDING_RE = re.compile(r"[ً-ٍ]$")
PARTICLE_MARKER = "Grammatikalische Funktion"


def best_noun(cur: sqlite3.Cursor, root: str) -> str:
    bare_root = root.replace("-", "")
    cur.execute("SELECT word FROM entry WHERE root = ?", (bare_root,))
    words = [row[0] for row in cur.fetchall()]
    candidates = sorted(
        {w for w in words if " " not in w and TANWIN_ENDING_RE.search(w)},
        key=len,
    )
    return candidates[0] if candidates else ""


def main() -> None:
    if not LEXICON_PATH.exists():
        raise SystemExit(f"Lane's-Lexicon-DB nicht gefunden: {LEXICON_PATH}")

    with DEFINITIONS_PATH.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    if fieldnames is None or "example_noun_arabic" not in fieldnames:
        raise SystemExit(
            f"Spalte 'example_noun_arabic' fehlt in {DEFINITIONS_PATH} "
            "(sollte bereits vorhanden sein, siehe Task G4)"
        )

    conn = sqlite3.connect(LEXICON_PATH)
    cur = conn.cursor()

    found = 0
    skipped_particle = 0
    no_candidate = 0
    for row in rows:
        if PARTICLE_MARKER in row["source"]:
            row["example_noun_arabic"] = ""
            skipped_particle += 1
            continue
        noun = best_noun(cur, row["root"])
        row["example_noun_arabic"] = noun
        if noun:
            found += 1
        else:
            no_candidate += 1
    conn.close()

    with DEFINITIONS_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Nomen gefunden:              {found}")
    print(f"Partikel-Wurzeln uebersprungen: {skipped_particle}")
    print(f"Ohne DB-Kandidat:            {no_candidate}")
    print(f"Aktualisiert: {DEFINITIONS_PATH}")


if __name__ == "__main__":
    main()
