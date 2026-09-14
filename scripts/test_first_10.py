#!/usr/bin/env python3
"""Einzelne Lektion (Batch) aus assets/data/sentences.json als MP3 erzeugen.

Nutzt edge-tts mit der natuerlichen arabischen Maennerstimme
ar-SA-HamedNeural und speichert pro Satz eine MP3 in assets/audio/.

Eine Lektion entspricht einem Batch zu learnBatchSize (10) Wörtern (stimmt mit
lib/core/word_groups.dart + lib/screens/home/batch_list_screen.dart überein).
Lektion N enthält alle Sätze zu den word_ids (N-1)*10+1 .. N*10. Die Dateien
werden je Lektion in einem Unterordner assets/audio/lektion_N/ fortlaufend
nummeriert (Reihenfolge der Sätze in sentences.json).

Ausfuehren (im venv, da dort edge-tts installiert ist):
    scripts/.venv/bin/python scripts/test_first_10.py --lesson 1
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

import edge_tts

VOICE = "ar-SA-HamedNeural"
JSON_PATH = Path(__file__).resolve().parent.parent / "assets" / "data" / "sentences.json"
AUDIO_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"
# Anzahl Wörter je Lektion/Batch (stimmt mit lib/core/word_groups.dart überein).
BATCH_SIZE = 10

DEFAULT_LESSON = 1


def lesson_number(word_id):
    """Lektion (1-basiert) für eine word_id: (word_id - 1) // 10 + 1."""
    return (word_id - 1) // BATCH_SIZE + 1


def lesson_word_range(lesson):
    """Lernt die word_ids (einschliesslich), die zu [lesson] gehören."""
    start = (lesson - 1) * BATCH_SIZE + 1
    end = lesson * BATCH_SIZE
    return start, end


def load_sentences_for_lesson(lesson):
    """Liest die JSON-Datei und gibt alle Sätze der Lektion zurück."""
    if not JSON_PATH.exists():
        sys.exit(f"JSON-Datei nicht gefunden: {JSON_PATH}")

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, dict):
        sys.exit(
            "Die JSON-Datei enthaelt ein einzelnes Objekt, keine Liste. "
            "Bitte als JSON-Array von Saetzen bereitstellen."
        )
    if not isinstance(data, list):
        sys.exit("Unerwartetes JSON-Format (weder Liste noch Objekt).")

    start, end = lesson_word_range(lesson)
    sentences = [
        s for s in data
        if isinstance(s, dict)
        and s.get("arabic")
        and isinstance(s.get("word_id"), int)
        and start <= s["word_id"] <= end
    ]
    return sentences


def assign_filenames(sentences, lesson):
    """Nummeriert alle Sätze der Lektion fortlaufend (1.mp3 ... N.mp3)."""
    return [(s, Path(f"lektion_{lesson}") / f"{i}.mp3")
            for i, s in enumerate(sentences, start=1)]


async def generate(sentence, filename, idx, total):
    wid = sentence["word_id"]
    arabic = sentence["arabic"]
    print(
        f"[{idx}/{total}] Generiere ID {wid} -> {filename}: {arabic} ...",
        end=" ",
        flush=True,
    )
    try:
        out_path = AUDIO_DIR / filename
        out_path.parent.mkdir(parents=True, exist_ok=True)
        communicate = edge_tts.Communicate(arabic, VOICE, rate="-40%")
        await communicate.save(str(out_path))
        print("Fertig.")
    except Exception as exc:  # noqa: BLE001 - Fehler pro Satz nicht abfangen
        print(f"FEHLER: {exc}")


async def main():
    parser = argparse.ArgumentParser(description="Sätze einer Lektion als MP3 generieren.")
    parser.add_argument(
        "--lesson",
        type=int,
        default=DEFAULT_LESSON,
        help=f"Lektionsnummer (Standard: {DEFAULT_LESSON}; word_ids "
             f"{(DEFAULT_LESSON-1)*BATCH_SIZE+1}..{DEFAULT_LESSON*BATCH_SIZE}).",
    )
    args = parser.parse_args()

    lesson = args.lesson
    sentences = load_sentences_for_lesson(lesson)
    total = len(sentences)
    print(f"Verarbeite {total} Saetze der Lektion {lesson} "
          f"(word_ids {lesson_word_range(lesson)}) mit Stimme {VOICE} in: {AUDIO_DIR}")

    if total == 0:
        print("Keine Sätze für diese Lektion gefunden.")
        return

    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    lesson_dir = AUDIO_DIR / f"lektion_{lesson}"
    lesson_dir.mkdir(parents=True, exist_ok=True)

    # Alte MP3-Dateien im Lektionsordner entfernen, damit nur die aktuelle
    # Nummerierung übrig bleibt und keine verwaisten Dateien bestehen.
    for old in lesson_dir.glob("*.mp3"):
        old.unlink()

    plan = assign_filenames(sentences, lesson)
    for idx, (sentence, filename) in enumerate(plan, start=1):
        await generate(sentence, filename, idx, total)

    print("\nFertig. Generierte Dateien:")
    for file in sorted(AUDIO_DIR.rglob("*.mp3")):
        print(f"  - {file.relative_to(AUDIO_DIR)}")


if __name__ == "__main__":
    asyncio.run(main())