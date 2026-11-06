#!/usr/bin/env python3
"""Erzeugt MP3-Audios fuer die B1-Quiz-Story-Saetze (word_id >= 1001).

Liest die Story-Saetze direkt aus lib/providers/quiz_provider.dart
(Muster `wordId: N,` + `arabic: '...'`) und speichert je Satz
assets/audio/story/<word_id>.mp3 (Stimme/Tempo wie scripts/test_first_10.py).
Bereits vorhandene, nicht leere Dateien werden uebersprungen.

Aufruf:  scripts/.venv/bin/python scripts/generate_story_audio.py [--first 1001 --last 2000]
"""
import argparse, asyncio, re
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'lib/providers/quiz_provider.dart'
OUT = ROOT / 'assets/audio/story'
VOICE = 'ar-SA-HamedNeural'


def story_sentences(first, last):
    s = SRC.read_text(encoding='utf-8')
    found = {}
    for m in re.finditer(r"wordId:\s*(\d+),\s*arabic:\s*'([^']*)'", s):
        wid = int(m.group(1))
        if first <= wid <= last:
            found[wid] = m.group(2)
    return found


async def one(sem, wid, text):
    path = OUT / f'{wid}.mp3'
    if path.exists() and path.stat().st_size > 2048:
        return True
    async with sem:
        for attempt in range(4):
            try:
                await edge_tts.Communicate(text, VOICE, rate='-40%').save(str(path))
                if path.stat().st_size > 2048:
                    return True
            except Exception as exc:  # noqa: BLE001
                print(f'{wid}: Versuch {attempt + 1} fehlgeschlagen: {exc}', flush=True)
            await asyncio.sleep(2 * (attempt + 1))
    path.unlink(missing_ok=True)
    return False


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--first', type=int, default=1001)
    ap.add_argument('--last', type=int, default=2000)
    a = ap.parse_args()
    sents = story_sentences(a.first, a.last)
    print(f'{len(sents)} Story-Saetze', flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    sem = asyncio.Semaphore(4)
    res = await asyncio.gather(*(one(sem, w, t) for w, t in sorted(sents.items())))
    bad = [w for (w, _), ok in zip(sorted(sents.items()), res) if not ok]
    print(f'fertig: {len(res) - len(bad)} ok, {len(bad)} fehlgeschlagen {bad}')

asyncio.run(main())
