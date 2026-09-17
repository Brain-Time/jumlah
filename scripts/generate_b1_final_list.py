#!/usr/bin/env python3
"""Generate the "Finale B1-Wortliste — Ränge 1001–2000" in docs/b1-wortkandidaten.md.

Mirrors the A2 approach (docs/a2-wortkandidaten.md, section "Finale A2-Wortliste"):
the provisional rank order is read mechanically from the candidate tables in
document order (Etappe 1 -> 5, and within each Etappe: Verben -> Nomen ->
Adjektive -> Adverbien -> Präpositionen -> Ordnungszahl). The final ordering is
refined later during CSV intake.

Since the B1 candidate list fills all 1000 rank slots (1001–2000) exactly, there
is no separate reserve pool (unlike A2, where 515 candidates covered 500 slots).

Idempotent: re-running regenerates the section in place.
"""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "b1-wortkandidaten.md"

ANCHOR = "## Stand & Nächste Schritte"
SECTION_HEADER = "## Finale B1-Wortliste — Ränge 1001–2000 (1000 Wörter)"


def extract_candidates(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for line in text.splitlines():
        if not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 5:
            continue
        if cells[0] in ("Arabisch", "#"):
            continue
        # Accept only rows whose first cell contains Arabic script.
        if any("\u0600" <= ch <= "\u06FF" for ch in cells[0]):
            rows.append(cells)
    return rows


def build_section(rows: list[list[str]], first_rank: int = 1001) -> str:
    lines = [
        SECTION_HEADER,
        "",
        "> Automatisch aus den 1000 Kandidaten abgeleitet (Dokument-Reihenfolge =",
        "> vorläufige Rang-Folge; die Reihenfolge wird bei der CSV-Übernahme final",
        "> gegliedert). Die Kandidatenliste füllt die Ränge 1001–2000 **exakt aus** —",
        "> anders als bei A2 (515 Kandidaten für 500 Ränge) gibt es daher **keine",
        "> separate Reserve**; ein Nachrücker-Pool ist erst nötig, wenn ein",
        "> Hauptlisteneintrag beim Inhalts-Aufbau ausfällt, und wird dann wie in",
        "> A1/A2 dokumentiert einzeln nachgezogen.",
        "",
        "| Rang | Arabisch | Transliteration | Deutsch | Wurzel |",
        "|---|---|---|---|---|",
    ]
    for i, (arabic, translit, german, root, _beleg) in enumerate(rows):
        lines.append(f"| {first_rank + i} | {arabic} | {translit} | {german} | {root} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    text = DOC.read_text(encoding="utf-8")

    if ANCHOR not in text:
        print(f"error: anchor '{ANCHOR}' not found in {DOC}")
        return 1

    rows = extract_candidates(text)
    if len(rows) != 1000:
        print(f"error: expected 1000 candidates, found {len(rows)}")
        return 1

    dup = {k: v for k, v in Counter(r[0] for r in rows).items() if v > 1}
    if dup:
        print(f"error: duplicate candidates {dup}")
        return 1

    section = build_section(rows)

    # Idempotent replace/insert before the anchor.
    pattern = re.compile(
        re.escape(SECTION_HEADER) + r".*?(?=\n" + re.escape(ANCHOR) + r")",
        re.DOTALL,
    )
    if pattern.search(text):
        new_text = pattern.sub(section.rstrip("\n") + "\n\n", text)
    else:
        new_text = text.replace(ANCHOR, section + "\n" + ANCHOR, 1)

    DOC.write_text(new_text, encoding="utf-8")

    by_pos = Counter(r[3] for r in rows)
    print(f"ok: wrote {len(rows)} candidates (ranks 1001–2000)")
    print(f"  arabic forms unique: {len({r[0] for r in rows})}")
    print(f"  distinct roots: {len(by_pos)}")
    # Sanity: root cells use the dashed pattern (R-L-…).
    bad_roots = [r[3] for r in rows if not re.fullmatch(r"[\u0621-\u064A\u0679\u06A0](-\u0621{0,1}[\u0621-\u064A])*", r[3])]
    print(f"  roots matching dashed-letter pattern: {len(rows) - len(bad_roots)}/1000")
    return 0


if __name__ == "__main__":
    sys.exit(main())