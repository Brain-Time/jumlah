#!/usr/bin/env python3
"""Prueft neue B1-Wort-Kandidaten automatisch gegen die bestehenden 1000
A1/A2-Woerter (assets/data/words.json), die bisherigen cand. (alle Etappen)
und die lokale Lane's-Lexicon-DB (assets/LexiconDatabase/lexicon.sqlite).

Kriterien (identisch mit docs/b1-wortkandidaten.md):
1. Keine A1/A2-Ueberschneidung: exaktes Wort, Wortgeruest (ohne Harakat)
   und hamza-normalisierte Form (أ/إ/آ -> ا) -> 0 Treffer.
2. Keine internen Duplikate innerhalb der Kandidatenliste.
3. Lexikon-Beleg in Lane's DB: exakte Wortform (entry.word ohne Hamza-
   Normalisierung) oder Wurzel (entry.root in Lane's-Orthografie, z.B.
   قوى statt قوي) - sonst "Online" (manuell zu entscheiden).

Eingabe: Kandidaten als CSV (utf-8) mit Spalten
  arabic,transliteration,german,root,masdar optional
Aufruf: python scripts/verify_b1_candidates.py <kandidaten.csv>
Ausgabe: Pruefbericht + Markdown-Tabellenteil (CSV-Eingabe).
"""

from __future__ import annotations

import csv
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDS_PATH = ROOT / "assets" / "data" / "words.json"
LEXICON_PATH = ROOT / "assets" / "LexiconDatabase" / "lexicon.sqlite"


def strip_harakat(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFC", s) if not unicodedata.combining(c))


def hamza_normalize(s: str) -> str:
    t = strip_harakat(s)
    return (
        t.replace("أ", "ا")
        .replace("إ", "ا")
        .replace("آ", "ا")
        .replace("ى", "ي")
        .replace("ة", "ه")
        .replace("ؤ", "و")
        .replace("ئ", "ي")
    )


def load_existing_words() -> set[tuple[str, str, str]]:
    """Returns set of (exact, skeleton, hamza-normalized) for 1000 A1/A2 words
    plus the already fixed B1 candidates (Etappe 1) parsed from the doc."""
    import json
    import re

    words = json.loads(WORDS_PATH.read_text(encoding="utf-8"))
    items = {(w["arabic"], strip_harakat(w["arabic"]), hamza_normalize(w["arabic"])) for w in words}

    # Bereits fixierte B1-Kandidaten (ALLE Etappen) aus docs/b1-wortkandidaten.md
    doc_path = ROOT / "docs" / "b1-wortkandidaten.md"
    if doc_path.exists():
        in_etappe = False
        for ln in doc_path.read_text(encoding="utf-8").splitlines():
            if ln.startswith("## Etappe"):
                in_etappe = True
                continue
            if in_etappe and ln.startswith("|") and not ln.startswith("|---"):
                cells = [c.strip() for c in ln.strip("|").split("|")]
                if len(cells) >= 2 and any("\u0600" <= ch <= "\u06FF" for ch in cells[0]):
                    a = cells[0]
                    items.add((a, strip_harakat(a), hamza_normalize(a)))
    return items



def lane_shape_for_root(root: str) -> list[str]:
    """Lane's-Orthografie-Varianten einer Wurzel (Buchstabenfolge).

    Lane's Lexicon schreibt Geminate-/verdoppelte Wurzeln mit nur zwei
    Buchstaben (z.B. `مد` fuer م-د-د, `ضر` fuer ض-ر-ر), Alif Maqsura
    als ى (z.B. `قوى` fuer ق-و-ي) und normalisiert fuehrende/finale
    Hamza-Varianten auf ا (z.B. `اخر` fuer أ-خ-ر)."""
    bare = root.replace("-", "")
    candidates = {bare}
    # Yaa vs. Alif Maqsura
    if bare.endswith("ي"):
        candidates.add(bare[:-1] + "ى")
    # geminate: 2. == 3. -> Lane laesst dritten weg
    if len(bare) == 3 and bare[1] == bare[2]:
        candidates.add(bare[:2])
    # Hamza-Normalisierung (أ/إ/آ -> ا) fuer einen evtl. besseren DB-Treffer
    hamz = bare.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
    if hamz != bare:
        candidates.add(hamz)
    return sorted(candidates)



def verify_in_lexicon(conn: sqlite3.Connection, arabic: str, root: str) -> str:
    """Returns 'Wortform', 'Wurzel' or 'Online'."""
    cur = conn.cursor()
    # 1) exakte Wortform (mit Harakat wie im Kandidat)
    row = cur.execute(
        "SELECT word FROM entry WHERE word = ? LIMIT 1", (arabic,)
    ).fetchone()
    if row:
        return "Lane's-DB (Wortform) ✓"
    # 2) ohne Schluss-Harakat-Fall (Lane markiert Nomen mit ٌ / Verben ohne)
    stripped = strip_harakat(arabic)
    row = cur.execute(
        "SELECT word FROM entry WHERE word = ? LIMIT 1", (stripped,)
    ).fetchone()
    if row:
        return "Lane's-DB (Wortform) ✓"
    # 3) Wurzel in Lane's-Orthografie
    for shape in lane_shape_for_root(root):
        row = cur.execute(
            "SELECT root FROM entry WHERE root = ? LIMIT 1", (shape,)
        ).fetchone()
        if row:
            return "Lane's-DB (Wurzel) ✓"
    return "Online ✓"


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    candidates_path = Path(sys.argv[1])
    existing = load_existing_words()
    conn = sqlite3.connect(LEXICON_PATH)

    rows = list(csv.DictReader(candidates_path.open(encoding="utf-8-sig")))
    seen_exact: dict[str, list[int]] = {}
    seen_skeleton: dict[str, list[int]] = {}
    seen_hamza: dict[str, list[int]] = {}
    conflicts: list[str] = []
    errors = 0

    print("=== Pruefbericht ===")
    for i, row in enumerate(rows, start=1):
        ar, root = row["arabic"], row["root"]
        skel, hamz = strip_harakat(ar), hamza_normalize(ar)
        # gegen A1/A2
        for (ex, sk, hz) in existing:
            if ex == ar:
                conflicts.append(f"Zeile {i}: {ar} exakt in A1/A2 vorhanden")
                errors += 1
            if sk == skel or hz == hamz:
                conflicts.append(f"Zeile {i}: {ar} Wortgeruest/Hamza-Kollision mit {ex}")
                errors += 1
        # intern (exakt / Wortgeruest / Hamza)
        if ar in seen_exact:
            conflicts.append(f"Zeile {i}: {ar} internes Duplikat (vorher Zeile {seen_exact[ar]})")
            errors += 1
        seen_exact.setdefault(ar, []).append(i)
        if skel in seen_skeleton:
            conflicts.append(f"Zeile {i}: {ar} internes Wortgeruest-Duplikat (vorher Zeile {seen_skeleton[skel]})")
            errors += 1
        seen_skeleton.setdefault(skel, []).append(i)
        if hamz in seen_hamza:
            conflicts.append(f"Zeile {i}: {ar} interne Hamza-Kollision (vorher Zeile {seen_hamza[hamz]})")
            errors += 1
        seen_hamza.setdefault(hamz, []).append(i)
        # Beleg
        beleg = verify_in_lexicon(conn, ar, root)
        row["beleg"] = beleg
        if beleg == "Online ✓":
            print(f"  Online-Kandidat: {ar} ({row['german']}, Wurzel {root})")

    print()
    print(f"Kandidaten gesamt: {len(rows)}")
    print(f"Konflikte: {len(conflicts)}")
    for c in conflicts:
        print("  !", c)
    print()
    print("=== Markdown-Tabelle (CSV-Eingabe, ohne Online-Row-Filter) ===")
    for row in rows:
        print(
            f"| {row['arabic']} | {row['transliteration']} | {row['german']} | "
            f"{row['root']} | {row['beleg']} |"
        )
    conn.close()
    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()