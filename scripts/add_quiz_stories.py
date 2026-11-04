#!/usr/bin/env python3
"""Fügt B1-Quiz-Stories (Stufe 6) in lib/providers/quiz_provider.dart ein.

Aufruf:  python3 scripts/add_quiz_stories.py scripts/stories_131_140.json

JSON-Format (Liste, je Lektion ein Objekt, aufsteigend ab der nächsten freien Lektion):
  [{"lesson": 131, "title": "...", "desc": "...",
    "sentences": [["arabisch", "deutsch", "umschrift"], ... genau 10 ...]}]
Satz i gehört zu word_id (1000 + (lesson-100)*10 - 9 + i).
"""
import json, re, sys

P = 'lib/providers/quiz_provider.dart'
ONES = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine']
TEENS = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
         'Seventeen', 'Eighteen', 'Nineteen']
TENS = {2: 'Twenty', 3: 'Thirty', 4: 'Forty', 5: 'Fifty', 6: 'Sixty', 7: 'Seventy',
        8: 'Eighty', 9: 'Ninety'}


def name(l):  # Lektion 101 -> 'HundredOne'
    n = l - 100
    if n == 0: return 'Hundred'
    if n < 10: return 'Hundred' + ONES[n]
    if n < 20: return 'Hundred' + TEENS[n - 10]
    if n == 100: return 'TwoHundred'
    return 'Hundred' + TENS[n // 10] + ONES[n % 10]


def main(path):
    stories = json.load(open(path, encoding='utf-8'))
    s = open(P, encoding='utf-8').read()
    prev = name(stories[0]['lesson'] - 1)
    assert f'_lesson{prev}Story' in s, f'Vorgänger _lesson{prev}Story fehlt'
    cases = ''.join(f"      case {x['lesson'] - 1}:\n        return _lesson{name(x['lesson'])}Story;\n" for x in stories)
    s = s.replace(f"        return _lesson{prev}Story;\n", f"        return _lesson{prev}Story;\n{cases}", 1)
    lst = ''.join(f"      _lesson{name(x['lesson'])}Story,\n" for x in stories)
    s = s.replace(f"      _lesson{prev}Story,\n    ];", f"      _lesson{prev}Story,\n{lst}    ];", 1)
    body = ''
    for x in stories:
        l = x['lesson']; assert len(x['sentences']) == 10, l
        lo = 1000 + (l - 100) * 10 - 9
        body += (f"\n/// Lektion {l} (word_ids {lo}–{lo + 9}): „{x['title']}\".\n/// {x['desc']}\n"
                 f"/// Jeder Satz verwendet genau eines der zehn gelernten Wörter.\n"
                 f"final List<Sentence> _lesson{name(l)}Story = [\n")
        for i, (a, g, t) in enumerate(x['sentences']):
            body += (f"  Sentence(\n    wordId: {lo + i},\n    arabic: '{a}',\n    german: '{g}',\n"
                     f"    transliteration: '{t}',\n    wordAnalysis: [],\n    targetIndex: 0,\n  ),\n")
        body += '];\n'
    k = s.index(f'final List<Sentence> _lesson{prev}Story')
    e = s.index('\n];\n', k) + 4
    s = s[:e] + body + s[e:]
    open(P, 'w', encoding='utf-8').write(s)
    print('ok:', [x['lesson'] for x in stories])


main(sys.argv[1])
