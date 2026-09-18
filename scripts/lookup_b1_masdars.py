#!/usr/bin/env python3
"""Suggests masdars (verbal nouns) for B1 intake verbs from Lane's lexicon DB.

For each verb in the B1 intake CSV (pos column optional; a word is treated as
a verb candidate if it matches the doc's "Verben" sections), this script
queries assets/LexiconDatabase/lexicon.sqlite for entries whose bare word form
starts with the verb's harakat-stripped form and extracts the "inf. n."
markers from the entry XML (Lane's own marking of the infinitival noun).

Output is a TSV of candidate masdars for editorial curation:
  rank  arabic  root  entry_word  inf_n_markers  xml_snippet

This is only a helper: the final masdar is curated/pasted into the intake CSV
(see docs/todo-list.md note on the 27 August 2026 masdar verification).
"""

from __future__ import annotations

import csv
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEXICON_PATH = ROOT / "assets" / "LexiconDatabase" / "lexicon.sqlite"
DOC = ROOT / "docs" / "b1-wortkandidaten.md"

# "inf. n. <foreign lang="ar">مَصْدَرٌ</foreign>"
INF_N_RE = re.compile(r"inf\. n\.\s*(?:<[^>]+>\s*)*<foreign\s+lang=\"ar\"\s*>([^<]+)</foreign>", re.IGNORECASE)
POS_HEADER = re.compile(r"^### (Verben|Nomen|Adjektive|Adverbien|Präpositionen|Zahlen)\s*\(")

HARAKAT = set("\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652\u0670")


def strip_harakat(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFC", s) if c not in HARAKAT)


def load_verbs(csv_path: Path) -> list[tuple[int, str, str, str]]:
    """Returns (rank, arabic, bare_arabic, root) for verbs only."""
    doc = DOC.read_text(encoding="utf-8")
    pos: dict[str, str] = {}
    current: str | None = None
    for line in doc.splitlines():
        m = POS_HEADER.match(line)
        if m:
            current = m.group(1)
            continue
        # Level-2 headings ("## Etappe …") end the previous POS section.
        if line.startswith("## ") and not line.startswith("### ") and current:
            current = None
            continue
        if current is None or not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 4 or cells[0] in ("Arabisch", "---"):
            continue
        if any("\u0600" <= ch <= "\u06FF" for ch in cells[0]):
            pos[cells[0]] = current

    verbs: list[tuple[int, str, str, str]] = []
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            arabic = row["arabic"]
            if arabic not in pos or pos[arabic] != "Verben":
                continue
            verbs.append(
                (
                    int(row["frequency_rank"]),
                    arabic,
                    strip_harakat(arabic),
                    row["root"],
                )
            )
    return verbs


def find_inf_n_markers(conn: sqlite3.Connection, bare: str, limit: int = 5) -> list[tuple[str, str, list[str]]]:
    try:
        rows = conn.execute(
            "SELECT word, xml FROM entry WHERE word LIKE ? LIMIT ?",
            (f"{bare}%", limit),
        ).fetchall()
    except sqlite3.OperationalError:
        return []
    results = []
    for word, xml in rows:
        markers = list(dict.fromkeys(INF_N_RE.findall(xml or "")))
        results.append((word, markers, xml or ""))
    return results


def main() -> int:
    csv_path = ROOT / "scripts" / "b1_words_etappe1.csv"
    verbs = load_verbs(csv_path)
    print(f"Verben: {len(verbs)}")

    conn = sqlite3.connect(LEXICON_PATH)
    for rank, arabic, bare, root in verbs:
        hits = find_inf_n_markers(conn, bare)
        if not hits:
            print(f"{rank}\t{arabic}\t{root}\t(keine Treffer)")
            continue
        for word, markers, xml in hits[:3]:
            markers_txt = " · ".join(markers[:6]) if markers else "-"
            m = re.search(r"<orth[^>]*>\s*([^<]{3,60})\s*</orth>", xml)
            snippet = m.group(1) if m else ""
            print(f"{rank}\t{arabic}\t{root}\t{word}\t{markers_txt}\t{snippet}")
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())