#!/usr/bin/env python3
"""B1 Daten-Aufnahme Etappe 1 — Sätze für die Ränge 1001–1300 (300 Wörter).

Auf Nutzerwunsch direkt verfasst (wie die A1/A2-Sätze, kein API-Call). Drei
Sätze pro Wort, jeder mit Wort-für-Wort-Analyse; die zugehörige
Wort-für-Wort-Transliteration (DIN 31635, Sonnenbuchstaben-Assimilation wie
im Bestands-Korpus) liegt in B1_TRANSLITERATIONS_ETAPPE1, 1:1 in derselben
Reihenfolge.

`generate_sentences.py` hängt beide Listen an SENTENCES /
SENTENCE_TRANSLITERATIONS an, damit die 1001–1300-Sätze in denselben
Validierungen (word_id-Existenz, genaue Listenlänge, 3 Sätze je Wort)
laufen wie der Bestand (3000 A1/A2-Sätze).
"""

from __future__ import annotations

# (word_id, arabic, german, [(arabisches_wort, uebersetzung), ...])
B1_SENTENCES_ETAPPE1: list[tuple[int, str, str, list[tuple[str, str]]]] = [
    (1001, "حَاوَلَ الرَّجُلُ أَنْ يَفْتَحَ الْبَابَ.", "Der Mann versuchte, die Tür zu öffnen.", [
        ("حَاوَلَ", "versuchte"), ("الرَّجُلُ", "der Mann"), ("أَنْ", "zu"), ("يَفْتَحَ", "öffnen"), ("الْبَابَ", "die Tür"),
    ]),
    (1001, "حَاوَلَ الطَّالِبُ فَهْمَ الدَّرْسِ.", "Der Student versuchte, die Lektion zu verstehen.", [
        ("حَاوَلَ", "versuchte"), ("الطَّالِبُ", "der Student"), ("فَهْمَ", "das Verstehen"), ("الدَّرْسِ", "der Lektion"),
    ]),
    (1001, "حَاوَلْنَا الْخُرُوجَ مِنَ الْبَيْتِ.", "Wir versuchten, das Haus zu verlassen.", [
        ("حَاوَلْنَا", "wir versuchten"), ("الْخُرُوجَ", "das Verlassen"), ("مِنَ", "aus"), ("الْبَيْتِ", "dem Haus"),
    ]),
    (1002, "عَرَضَ الْبَائِعُ الْبَضَائِعَ فِي السُّوقِ.", "Der Verkäufer bot die Waren auf dem Markt an.", [
        ("عَرَضَ", "bot an"), ("الْبَائِعُ", "der Verkäufer"), ("الْبَضَائِعَ", "die Waren"), ("فِي", "auf"), ("السُّوقِ", "dem Markt"),
    ]),
    (1002, "عَرَضَ الْمُدِيرُ خِطَّةً جَدِيدَةً.", "Der Direktor stellte einen neuen Plan vor.", [
        ("عَرَضَ", "stellte vor"), ("الْمُدِيرُ", "der Direktor"), ("خِطَّةً", "einen Plan"), ("جَدِيدَةً", "neuen"),
    ]),
    (1002, "عَرَضَ عَلَيْنَا الْمُعَلِّمُ تَمْرِينًا.", "Der Lehrer zeigte uns eine Übung.", [
        ("عَرَضَ", "zeigte"), ("عَلَيْنَا", "uns"), ("الْمُعَلِّمُ", "der Lehrer"), ("تَمْرِينًا", "eine Übung"),
    ]),
    (1003, "عَزَمَ الرَّجُلُ عَلَى السَّفَرِ غَدًا.", "Der Mann beschloss, morgen zu reisen.", [
        ("عَزَمَ", "beschloss"), ("الرَّجُلُ", "der Mann"), ("عَلَى", "zu"), ("السَّفَرِ", "der Reise"), ("غَدًا", "morgen"),
    ]),
    (1003, "عَزَمَتِ الْمَرْأَةُ عَلَى تَغْيِيرِ عَمَلِهَا.", "Die Frau beabsichtigte, ihre Arbeit zu wechseln.", [
        ("عَزَمَتِ", "beabsichtigte"), ("الْمَرْأَةُ", "die Frau"), ("عَلَى", "zu"), ("تَغْيِيرِ", "dem Wechseln"), ("عَمَلِهَا", "ihrer Arbeit"),
    ]),
    (1003, "عَزَمْنَا عَلَى زِيَارَةِ الْجَدِّ.", "Wir beschlossen, den Großvater zu besuchen.", [
        ("عَزَمْنَا", "wir beschlossen"), ("عَلَى", "zu"), ("زِيَارَةِ", "dem Besuch"), ("الْجَدِّ", "des Großvaters"),
    ]),
    (1004, "رَغِبَ الطَّالِبُ فِي تَعَلُّمِ الْعَرَبِيَّةِ.", "Der Student wünschte, Arabisch zu lernen.", [
        ("رَغِبَ", "wünschte"), ("الطَّالِبُ", "der Student"), ("فِي", "zu"), ("تَعَلُّمِ", "dem Lernen"), ("الْعَرَبِيَّةِ", "des Arabischen"),
    ]),
    (1004, "رَغِبَتِ الْمَرْأَةُ فِي شِرَاءِ الْبَيْتِ.", "Die Frau begehrte, das Haus zu kaufen.", [
        ("رَغِبَتِ", "begehrte"), ("الْمَرْأَةُ", "die Frau"), ("فِي", "zu"), ("شِرَاءِ", "dem Kaufen"), ("الْبَيْتِ", "des Hauses"),
    ]),
    (1004, "رَغِبْنَا فِي مُشَاهَدَةِ الْفِلْمِ.", "Wir wünschten, den Film zu sehen.", [
        ("رَغِبْنَا", "wir wünschten"), ("فِي", "zu"), ("مُشَاهَدَةِ", "dem Sehen"), ("الْفِلْمِ", "des Films"),
    ]),
    (1005, "اِنْفَجَرَتِ الْقُنْبُلَةُ فِي الْمَدِينَةِ.", "Die Bombe explodierte in der Stadt.", [
        ("اِنْفَجَرَتِ", "explodierte"), ("الْقُنْبُلَةُ", "die Bombe"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt"),
    ]),
    (1005, "اِنْفَجَرَ الْإِطَارُ فِي الطَّرِيقِ.", "Der Reifen platzte auf der Straße.", [
        ("اِنْفَجَرَ", "platzte"), ("الْإِطَارُ", "der Reifen"), ("فِي", "auf"), ("الطَّرِيقِ", "der Straße"),
    ]),
    (1005, "اِنْفَجَرَ الْمَصْنَعُ بِسَبَبِ الْحَرِيقِ.", "Die Fabrik explodierte wegen des Feuers.", [
        ("اِنْفَجَرَ", "explodierte"), ("الْمَصْنَعُ", "die Fabrik"), ("بِسَبَبِ", "wegen"), ("الْحَرِيقِ", "des Feuers"),
    ]),
    (1006, "غَرِقَ الرَّجُلُ فِي النَّهْرِ.", "Der Mann ertrank im Fluss.", [
        ("غَرِقَ", "ertrank"), ("الرَّجُلُ", "der Mann"), ("فِي", "im"), ("النَّهْرِ", "Fluss"),
    ]),
    (1006, "غَرِقَتِ السَّفِينَةُ قَرِيبًا مِنَ الشَّاطِئِ.", "Das Schiff sank nahe der Küste.", [
        ("غَرِقَتِ", "sank"), ("السَّفِينَةُ", "das Schiff"), ("قَرِيبًا", "nahe"), ("مِنَ", "von"), ("الشَّاطِئِ", "der Küste"),
    ]),
    (1006, "غَرِقَ الطِّفْلُ فِي الْمَاءِ الْعَمِيقِ.", "Das Kind ertrank im tiefen Wasser.", [
        ("غَرِقَ", "ertrank"), ("الطِّفْلُ", "das Kind"), ("فِي", "im"), ("الْمَاءِ", "Wasser"), ("الْعَمِيقِ", "tiefen"),
    ]),
    (1007, "أَدَّى الطَّالِبُ الْوَظِيفَةَ بِحِذْقٍ.", "Der Student führte die Aufgabe geschickt aus.", [
        ("أَدَّى", "führte aus"), ("الطَّالِبُ", "der Student"), ("الْوَظِيفَةَ", "die Aufgabe"), ("بِحِذْقٍ", "geschickt"),
    ]),
    (1007, "أَدَّى الرَّجُلُ الْأَمَانَةَ كَامِلَةً.", "Der Mann erfüllte das Amt vollständig.", [
        ("أَدَّى", "erfüllte"), ("الرَّجُلُ", "der Mann"), ("الْأَمَانَةَ", "das Amt"), ("كَامِلَةً", "vollständig"),
    ]),
    (1007, "أَدَّى الْجُنْدِيُّ وَاجِبَهُ فِي الْحَرْبِ.", "Der Soldat leistete seine Pflicht im Krieg.", [
        ("أَدَّى", "leistete"), ("الْجُنْدِيُّ", "der Soldat"), ("وَاجِبَهُ", "seine Pflicht"), ("فِي", "im"), ("الْحَرْبِ", "Krieg"),
    ]),
    (1008, "أَعَدَّتِ الْأُمُّ الْعَشَاءَ لِلْعَائِلَةِ.", "Die Mutter bereitete das Abendessen für die Familie zu.", [
        ("أَعَدَّتِ", "bereitete zu"), ("الْأُمُّ", "die Mutter"), ("الْعَشَاءَ", "das Abendessen"), ("لِلْعَائِلَةِ", "für die Familie"),
    ]),
    (1008, "أَعَدَّ الطَّالِبُ نَفْسَهُ لِلِامْتِحَانِ.", "Der Student bereitete sich auf die Prüfung vor.", [
        ("أَعَدَّ", "bereitete vor"), ("الطَّالِبُ", "der Student"), ("نَفْسَهُ", "sich"), ("لِلِامْتِحَانِ", "auf die Prüfung"),
    ]),
    (1008, "أَعَدَّ الرَّجُلُ خِطَّةً لِلْمُسْتَقْبَلِ.", "Der Mann bereitete einen Plan für die Zukunft vor.", [
        ("أَعَدَّ", "bereitete vor"), ("الرَّجُلُ", "der Mann"), ("خِطَّةً", "einen Plan"), ("لِلْمُسْتَقْبَلِ", "für die Zukunft"),
    ]),
    (1009, "سَمَحَ الْأَبُ لِابْنِهِ بِالْخُرُوجِ.", "Der Vater erlaubte seinem Sohn auszugehen.", [
        ("سَمَحَ", "erlaubte"), ("الْأَبُ", "der Vater"), ("لِابْنِهِ", "seinem Sohn"), ("بِالْخُرُوجِ", "auszugehen"),
    ]),
    (1009, "سَمَحَتِ الْمُدِيرَةُ بِالْإِجَازَةِ.", "Die Direktorin gewährte den Urlaub.", [
        ("سَمَحَتِ", "gewährte"), ("الْمُدِيرَةُ", "die Direktorin"), ("بِالْإِجَازَةِ", "den Urlaub"),
    ]),
    (1009, "سَمَحْنَا لِلضَّيْفِ بِالدُّخُولِ.", "Wir erlaubten dem Gast hereinzukommen.", [
        ("سَمَحْنَا", "wir erlaubten"), ("لِلضَّيْفِ", "dem Gast"), ("بِالدُّخُولِ", "hereinzukommen"),
    ]),
    (1010, "اِخْتَلَفَ الرَّجُلَانِ فِي الرَّأْيِ.", "Die beiden Männer waren unterschiedlicher Meinung.", [
        ("اِخْتَلَفَ", "waren verschieden"), ("الرَّجُلَانِ", "die beiden Männer"), ("فِي", "in"), ("الرَّأْيِ", "der Meinung"),
    ]),
    (1010, "اِخْتَلَفَتِ الْأَسْعَارُ مِنْ سُوقٍ إِلَى أُخْرَى.", "Die Preise unterschieden sich von Markt zu Markt.", [
        ("اِخْتَلَفَتِ", "unterschieden sich"), ("الْأَسْعَارُ", "die Preise"), ("مِنْ", "von"), ("سُوقٍ", "Markt"), ("إِلَى", "zu"), ("أُخْرَى", "anderem"),
    ]),
    (1010, "اِخْتَلَفَ الْوَلَدَانِ فِي اللَّعِبِ.", "Die beiden Jungen stritten sich beim Spielen.", [
        ("اِخْتَلَفَ", "stritten sich"), ("الْوَلَدَانِ", "die beiden Jungen"), ("فِي", "beim"), ("اللَّعِبِ", "Spielen"),
    ]),
    (1011, "صَرَفَ الرَّجُلُ الْمَالَ فِي السُّوقِ.", "Der Mann gab das Geld auf dem Markt aus.", [
        ("صَرَفَ", "gab aus"), ("الرَّجُلُ", "der Mann"), ("الْمَالَ", "das Geld"), ("فِي", "auf"), ("السُّوقِ", "dem Markt"),
    ]),
    (1011, "صَرَفَتِ الْمَرْأَةُ وَقْتَهَا فِي الْقِرَاءَةِ.", "Die Frau verbrachte ihre Zeit mit Lesen.", [
        ("صَرَفَتِ", "verbrachte"), ("الْمَرْأَةُ", "die Frau"), ("وَقْتَهَا", "ihre Zeit"), ("فِي", "mit"), ("الْقِرَاءَةِ", "Lesen"),
    ]),
    (1011, "صَرَفْنَا أَمْوَالًا كَثِيرَةً فِي السَّفَرِ.", "Wir gaben viel Geld auf der Reise aus.", [
        ("صَرَفْنَا", "wir gaben aus"), ("أَمْوَالًا", "Geld"), ("كَثِيرَةً", "viel"), ("فِي", "auf"), ("السَّفَرِ", "der Reise"),
    ]),
    (1012, "شَاهَدَ الْوَلَدُ الْفِلْمَ فِي السِّينَمَا.", "Der Junge sah den Film im Kino.", [
        ("شَاهَدَ", "sah"), ("الْوَلَدُ", "der Junge"), ("الْفِلْمَ", "den Film"), ("فِي", "im"), ("السِّينَمَا", "Kino"),
    ]),
    (1012, "شَاهَدْنَا الْمُبَارَاةَ فِي الْمَسَاءِ.", "Wir schauten dem Spiel am Abend zu.", [
        ("شَاهَدْنَا", "wir schauten zu"), ("الْمُبَارَاةَ", "dem Spiel"), ("فِي", "am"), ("الْمَسَاءِ", "Abend"),
    ]),
    (1012, "شَاهَدَ الْجَمْهُورُ الْمَنْظَرَ الْجَمِيلَ.", "Das Publikum sah die schöne Szene.", [
        ("شَاهَدَ", "sah"), ("الْجَمْهُورُ", "das Publikum"), ("الْمَنْظَرَ", "die Szene"), ("الْجَمِيلَ", "schöne"),
    ]),
    (1013, "اِعْتَرَفَ الرَّجُلُ بِخَطَئِهِ.", "Der Mann gab seinen Fehler zu.", [
        ("اِعْتَرَفَ", "gab zu"), ("الرَّجُلُ", "der Mann"), ("بِخَطَئِهِ", "seinen Fehler"),
    ]),
    (1013, "اِعْتَرَفَ اللِّصُّ بِالسَّرِقَةِ.", "Der Dieb gestand den Diebstahl.", [
        ("اِعْتَرَفَ", "gestand"), ("اللِّصُّ", "der Dieb"), ("بِالسَّرِقَةِ", "den Diebstahl"),
    ]),
    (1013, "اِعْتَرَفْنَا بِالْحَقِيقَةِ أَمَامَ الْجَمِيعِ.", "Wir gaben die Wahrheit vor allen zu.", [
        ("اِعْتَرَفْنَا", "wir gaben zu"), ("بِالْحَقِيقَةِ", "die Wahrheit"), ("أَمَامَ", "vor"), ("الْجَمِيعِ", "allen"),
    ]),
    (1014, "اِبْتَدَأَ الدَّرْسُ فِي السَّاعَةِ الثَّامِنَةِ.", "Der Unterricht begann um acht Uhr.", [
        ("اِبْتَدَأَ", "begann"), ("الدَّرْسُ", "der Unterricht"), ("فِي", "um"), ("السَّاعَةِ", "Uhr"), ("الثَّامِنَةِ", "acht"),
    ]),
    (1014, "اِبْتَدَأَ الْعَامِلُ الْعَمَلَ الْجَدِيدَ.", "Der Arbeiter begann die neue Arbeit.", [
        ("اِبْتَدَأَ", "begann"), ("الْعَامِلُ", "der Arbeiter"), ("الْعَمَلَ", "die Arbeit"), ("الْجَدِيدَ", "neue"),
    ]),
    (1015, "أَعْلَنَتِ الْحُكُومَةُ قَرَارًا جَدِيدًا.", "Die Regierung kündigte eine neue Entscheidung an.", [
        ("أَعْلَنَتِ", "kündigte an"), ("الْحُكُومَةُ", "die Regierung"), ("قَرَارًا", "eine Entscheidung"), ("جَدِيدًا", "neue"),
    ]),
    (1015, "أَعْلَنَ الْمُدَرِّبُ اسْمَ الْفَائِزِ.", "Der Trainer gab den Namen des Siegers bekannt.", [
        ("أَعْلَنَ", "gab bekannt"), ("الْمُدَرِّبُ", "der Trainer"), ("اسْمَ", "den Namen"), ("الْفَائِزِ", "des Siegers"),
    ]),
    (1015, "أَعْلَنَ الرَّئِيسُ بَدْءَ الِاجْتِمَاعِ.", "Der Vorsitzende verkündete den Beginn der Sitzung.", [
        ("أَعْلَنَ", "verkündete"), ("الرَّئِيسُ", "der Vorsitzende"), ("بَدْءَ", "den Beginn"), ("الِاجْتِمَاعِ", "der Sitzung"),
    ]),
    (1016, "اِقْتَرَحَ الطَّالِبُ فِكْرَةً جَدِيدَةً.", "Der Student schlug eine neue Idee vor.", [
        ("اِقْتَرَحَ", "schlug vor"), ("الطَّالِبُ", "der Student"), ("فِكْرَةً", "eine Idee"), ("جَدِيدَةً", "neue"),
    ]),
    (1016, "اِقْتَرَحَ الْمُدِيرُ تَغْيِيرَ الْجَدْوَلِ.", "Der Direktor schlug die Änderung des Plans vor.", [
        ("اِقْتَرَحَ", "schlug vor"), ("الْمُدِيرُ", "der Direktor"), ("تَغْيِيرَ", "die Änderung"), ("الْجَدْوَلِ", "des Plans"),
    ]),
    (1016, "اِقْتَرَحْنَا السَّفَرَ إِلَى الْجَبَلِ.", "Wir schlugen die Reise in die Berge vor.", [
        ("اِقْتَرَحْنَا", "wir schlugen vor"), ("السَّفَرَ", "die Reise"), ("إِلَى", "in"), ("الْجَبَلِ", "die Berge"),
    ]),
    (1017, "شَارَكَ الْعَامِلُ فِي الِاجْتِمَاعِ.", "Der Arbeiter nahm an der Versammlung teil.", [
        ("شَارَكَ", "nahm teil"), ("الْعَامِلُ", "der Arbeiter"), ("فِي", "an"), ("الِاجْتِمَاعِ", "der Versammlung"),
    ]),
    (1017, "شَارَكَتِ الطِّفْلَةُ فِي الْأَلْعَابِ.", "Das Mädchen nahm an den Spielen teil.", [
        ("شَارَكَتِ", "nahm teil"), ("الطِّفْلَةُ", "das Mädchen"), ("فِي", "an"), ("الْأَلْعَابِ", "den Spielen"),
    ]),
    (1018, "أَضَافَ الطَّبَّاخُ الْمِلْحَ إِلَى الطَّعَامِ.", "Der Koch fügte dem Essen Salz hinzu.", [("أَضَافَ", "fügte hinzu"), ("الطَّبَّاخُ", "der Koch"), ("الْمِلْحَ", "Salz"), ("إِلَى", "zu"), ("الطَّعَامِ", "dem Essen")]),
    (1018, "أَضَافَتِ الْمَرْأَةُ فِكْرَةً إِلَى الْكَلَامِ.", "Die Frau fügte dem Gespräch einen Gedanken hinzu.", [("أَضَافَتِ", "fügte hinzu"), ("الْمَرْأَةُ", "die Frau"), ("فِكْرَةً", "einen Gedanken"), ("إِلَى", "zu"), ("الْكَلَامِ", "dem Gespräch")]),
    (1018, "أَضَفْنَا اسْمًا جَدِيدًا إِلَى الْقَائِمَةِ.", "Wir fügten der Liste einen neuen Namen hinzu.", [("أَضَفْنَا", "wir fügten hinzu"), ("اسْمًا", "einen Namen"), ("جَدِيدًا", "neuen"), ("إِلَى", "zu"), ("الْقَائِمَةِ", "der Liste")]),
    (1019, "اِسْتَفَادَ الطَّالِبُ مِنَ الدَّرْسِ.", "Der Student zog Nutzen aus der Lektion.", [("اِسْتَفَادَ", "zog Nutzen"), ("الطَّالِبُ", "der Student"), ("مِنَ", "aus"), ("الدَّرْسِ", "der Lektion")]),
    (1019, "اِسْتَفَادَتِ الشَّرِكَةُ مِنَ الْمَشْرُوعِ.", "Die Firma profitierte von dem Projekt.", [("اِسْتَفَادَتِ", "profitierte"), ("الشَّرِكَةُ", "die Firma"), ("مِنَ", "von"), ("الْمَشْرُوعِ", "dem Projekt")]),
    (1019, "اِسْتَفَادَ الْكَثِيرُونَ مِنَ النَّصِيحَةِ.", "Viele zogen Nutzen aus dem Ratschlag.", [("اِسْتَفَادَ", "zogen Nutzen"), ("الْكَثِيرُونَ", "viele"), ("مِنَ", "aus"), ("النَّصِيحَةِ", "dem Ratschlag")]),
    (1020, "هَبَطَ الطَّائِرُ إِلَى الْأَرْضِ.", "Der Vogel stieg zur Erde hinab.", [("هَبَطَ", "stieg hinab"), ("الطَّائِرُ", "der Vogel"), ("إِلَى", "zur"), ("الْأَرْضِ", "Erde")]),
    (1020, "هَبَطَ الرَّجُلُ مِنَ الْجَبَلِ.", "Der Mann stieg vom Berg hinab.", [("هَبَطَ", "stieg hinab"), ("الرَّجُلُ", "der Mann"), ("مِنَ", "vom"), ("الْجَبَلِ", "Berg")]),
    (1020, "هَبَطَتِ الطَّائِرَةُ فِي الْمَغْرِبِ.", "Das Flugzeug landete am Abend.", [("هَبَطَتِ", "landete"), ("الطَّائِرَةُ", "das Flugzeug"), ("فِي", "am"), ("الْمَغْرِبِ", "Abend")]),
    (1021, "يَبِسَتِ الْأَرْضُ بَعْدَ الْجَفَافِ.", "Die Erde trocknete nach der Dürre aus.", [("يَبِسَتِ", "trocknete aus"), ("الْأَرْضُ", "die Erde"), ("بَعْدَ", "nach"), ("الْجَفَافِ", "der Dürre")]),
    (1021, "يَبِسَ الثَّوْبُ فِي الشَّمْسِ.", "Das Kleidungsstück trocknete in der Sonne.", [("يَبِسَ", "trocknete"), ("الثَّوْبُ", "das Kleidungsstück"), ("فِي", "in"), ("الشَّمْسِ", "der Sonne")]),
    (1021, "يَبِسَتِ الْأَشْجَارُ فِي الْخَرِيفِ.", "Die Bäume trockneten im Herbst aus.", [("يَبِسَتِ", "trockneten aus"), ("الْأَشْجَارُ", "die Bäume"), ("فِي", "im"), ("الْخَرِيفِ", "Herbst")]),
    (1022, "اِمْتَلَأَ الْكَأْسُ بِالْمَاءِ.", "Das Glas füllte sich mit Wasser.", [("اِمْتَلَأَ", "füllte sich"), ("الْكَأْسُ", "das Glas"), ("بِالْمَاءِ", "mit Wasser")]),
    (1022, "اِمْتَلَأَتِ السُّوقُ بِالنَّاسِ.", "Der Markt füllte sich mit Menschen.", [("اِمْتَلَأَتِ", "füllte sich"), ("السُّوقُ", "der Markt"), ("بِالنَّاسِ", "mit Menschen")]),
    (1022, "اِمْتَلَأَ الْبَيْتُ بِالضَّوْءِ.", "Das Haus füllte sich mit Licht.", [("اِمْتَلَأَ", "füllte sich"), ("الْبَيْتُ", "das Haus"), ("بِالضَّوْءِ", "mit Licht")]),
    (1023, "اِسْتَحَقَّ الطَّالِبُ الْجَائِزَةَ.", "Der Student verdiente den Preis.", [("اِسْتَحَقَّ", "verdiente"), ("الطَّالِبُ", "der Student"), ("الْجَائِزَةَ", "den Preis")]),
    (1023, "اِسْتَحَقَّ الرَّجُلُ الِاحْتِرَامَ.", "Der Mann war des Respekts würdig.", [("اِسْتَحَقَّ", "war würdig"), ("الرَّجُلُ", "der Mann"), ("الِاحْتِرَامَ", "des Respekts")]),
    (1023, "اِسْتَحَقَّتِ الْمَرْأَةُ الْمَدْحَ بِعَمَلِهَا.", "Die Frau verdiente das Lob für ihre Arbeit.", [("اِسْتَحَقَّتِ", "verdiente"), ("الْمَرْأَةُ", "die Frau"), ("الْمَدْحَ", "das Lob"), ("بِعَمَلِهَا", "für ihre Arbeit")]),
    (1024, "اِنْقَطَعَ الْحَبْلُ فِي الْمُنْتَصَفِ.", "Das Seil riss in der Mitte ab.", [("اِنْقَطَعَ", "riss ab"), ("الْحَبْلُ", "das Seil"), ("فِي", "in"), ("الْمُنْتَصَفِ", "der Mitte")]),
    (1024, "اِنْقَطَعَ الْكَهْرَبَاءُ فِي الْبَلْدَةِ.", "Der Strom fiel im Dorf aus.", [("اِنْقَطَعَ", "fiel aus"), ("الْكَهْرَبَاءُ", "der Strom"), ("فِي", "im"), ("الْبَلْدَةِ", "Dorf")]),
    (1025, "تَغَيَّرَ الْجَوُّ فِي الْمَسَاءِ.", "Das Wetter änderte sich am Abend.", [("تَغَيَّرَ", "änderte sich"), ("الْجَوُّ", "das Wetter"), ("فِي", "am"), ("الْمَسَاءِ", "Abend")]),
    (1025, "تَغَيَّرَتِ الْحَيَاةُ فِي الْقَرْيَةِ.", "Das Leben im Dorf veränderte sich.", [("تَغَيَّرَتِ", "veränderte sich"), ("الْحَيَاةُ", "das Leben"), ("فِي", "im"), ("الْقَرْيَةِ", "Dorf")]),
    (1025, "تَغَيَّرَ رَأْيُ الرَّجُلِ بَعْدَ الْحِوَارِ.", "Die Meinung des Mannes änderte sich nach dem Dialog.", [("تَغَيَّرَ", "änderte sich"), ("رَأْيُ", "die Meinung"), ("الرَّجُلِ", "des Mannes"), ("بَعْدَ", "nach"), ("الْحِوَارِ", "dem Dialog")]),
    (1026, "رَفَضَ الرَّجُلُ الِاقْتِرَاحَ.", "Der Mann lehnte den Vorschlag ab.", [("رَفَضَ", "lehnte ab"), ("الرَّجُلُ", "der Mann"), ("الِاقْتِرَاحَ", "den Vorschlag")]),
    (1026, "رَفَضَتِ الْمَرْأَةُ الْمُعَامَلَةَ الظَّالِمَةَ.", "Die Frau lehnte die ungerechte Behandlung ab.", [("رَفَضَتِ", "lehnte ab"), ("الْمَرْأَةُ", "die Frau"), ("الْمُعَامَلَةَ", "die Behandlung"), ("الظَّالِمَةَ", "ungerechte")]),
    (1026, "رَفَضْنَا الْقَرَارَ بِالْإِجْمَاعِ.", "Wir lehnten die Entscheidung einstimmig ab.", [("رَفَضْنَا", "wir lehnten ab"), ("الْقَرَارَ", "die Entscheidung"), ("بِالْإِجْمَاعِ", "einstimmig")]),
    (1027, "اِنْكَسَرَ الزُّجَاجُ عَلَى الْأَرْضِ.", "Das Glas zerbrach auf dem Boden.", [("اِنْكَسَرَ", "zerbrach"), ("الزُّجَاجُ", "das Glas"), ("عَلَى", "auf"), ("الْأَرْضِ", "dem Boden")]),
    (1027, "اِنْكَسَرَتْ رِجْلُ الطِّفْلِ.", "Das Bein des Kindes brach.", [("اِنْكَسَرَتْ", "brach"), ("رِجْلُ", "das Bein"), ("الطِّفْلِ", "des Kindes")]),
    (1027, "اِنْكَسَرَ الْقَلَمُ فِي الْحَقِيبَةِ.", "Der Stift zerbrach in der Tasche.", [("اِنْكَسَرَ", "zerbrach"), ("الْقَلَمُ", "der Stift"), ("فِي", "in"), ("الْحَقِيبَةِ", "der Tasche")]),
    (1028, "اِعْتَنَى الطَّبِيبُ بِالْمَرِيضِ.", "Der Arzt kümmerte sich um den Kranken.", [("اِعْتَنَى", "kümmerte sich"), ("الطَّبِيبُ", "der Arzt"), ("بِالْمَرِيضِ", "um den Kranken")]),
    (1028, "اِعْتَنَتِ الْأُمُّ بِتَرْبِيَةِ أَوْلَادِهَا.", "Die Mutter kümmerte sich um die Erziehung ihrer Kinder.", [("اِعْتَنَتِ", "kümmerte sich"), ("الْأُمُّ", "die Mutter"), ("بِتَرْبِيَةِ", "um die Erziehung"), ("أَوْلَادِهَا", "ihrer Kinder")]),
    (1028, "اِعْتَنَى الرَّجُلُ بِالْعَمَلِ الدَّقِيقِ.", "Der Mann widmete sich der genauen Arbeit.", [("اِعْتَنَى", "widmete sich"), ("الرَّجُلُ", "der Mann"), ("بِالْعَمَلِ", "der Arbeit"), ("الدَّقِيقِ", "genauen")]),
    (1029, "هَدَّدَ الرَّجُلُ اللِّصَّ بِالشُّرْطَةِ.", "Der Mann drohte dem Dieb mit der Polizei.", [("هَدَّدَ", "drohte"), ("الرَّجُلُ", "der Mann"), ("اللِّصَّ", "dem Dieb"), ("بِالشُّرْطَةِ", "mit der Polizei")]),
    (1029, "هَدَّدَتِ الْعَاصِفَةُ الْقَرْيَةَ.", "Der Sturm bedrohte das Dorf.", [("هَدَّدَتِ", "bedrohte"), ("الْعَاصِفَةُ", "der Sturm"), ("الْقَرْيَةَ", "das Dorf")]),
    (1029, "هَدَّدَ الْمُدِيرُ الْعَامِلَ بِالْفَصْلِ.", "Der Direktor drohte dem Arbeiter mit der Entlassung.", [("هَدَّدَ", "drohte"), ("الْمُدِيرُ", "der Direktor"), ("الْعَامِلَ", "dem Arbeiter"), ("بِالْفَصْلِ", "mit der Entlassung")]),
    (1030, "أَنْجَزَ الْعَامِلُ الْعَمَلَ فِي الْوَقْتِ.", "Der Arbeiter erledigte die Arbeit rechtzeitig.", [("أَنْجَزَ", "erledigte"), ("الْعَامِلُ", "der Arbeiter"), ("الْعَمَلَ", "die Arbeit"), ("فِي", "in"), ("الْوَقْتِ", "der Zeit")]),
    (1030, "أَنْجَزَتِ الشَّرِكَةُ الْمَشْرُوعَ الْكَبِيرَ.", "Die Firma vollbrachte das große Projekt.", [("أَنْجَزَتِ", "vollbrachte"), ("الشَّرِكَةُ", "die Firma"), ("الْمَشْرُوعَ", "das Projekt"), ("الْكَبِيرَ", "große")]),
    (1031, "اِسْتَكْمَلَ الطَّالِبُ تَعْلِيمَهُ فِي الْخَارِجِ.", "Der Student vervollständigte seine Ausbildung im Ausland.", [("اِسْتَكْمَلَ", "vervollständigte"), ("الطَّالِبُ", "der Student"), ("تَعْلِيمَهُ", "seine Ausbildung"), ("فِي", "im"), ("الْخَارِجِ", "Ausland")]),
    (1031, "اِسْتَكْمَلَتِ الْمَرْأَةُ شِرَاءَ الْحَوَائِجِ.", "Die Frau ergänzte den Einkauf der Bedarfsgüter.", [("اِسْتَكْمَلَتِ", "ergänzte"), ("الْمَرْأَةُ", "die Frau"), ("شِرَاءَ", "den Einkauf"), ("الْحَوَائِجِ", "der Bedarfsgüter")]),
    (1031, "اِسْتَكْمَلَ الْفَرِيقُ الْعَدَدَ الْمَطْلُوبَ.", "Die Mannschaft vervollständigte die geforderte Zahl.", [("اِسْتَكْمَلَ", "vervollständigte"), ("الْفَرِيقُ", "die Mannschaft"), ("الْعَدَدَ", "die Zahl"), ("الْمَطْلُوبَ", "geforderte")]),
    (1032, "أَثَّرَ الطَّقْسُ فِي الصِّحَّةِ.", "Das Wetter beeinflusste die Gesundheit.", [("أَثَّرَ", "beeinflusste"), ("الطَّقْسُ", "das Wetter"), ("فِي", "die"), ("الصِّحَّةِ", "Gesundheit")]),
    (1032, "أَثَّرَتِ الْكَلِمَةُ فِي الْجَمِيعِ.", "Das Wort beeindruckte alle.", [("أَثَّرَتِ", "beeindruckte"), ("الْكَلِمَةُ", "das Wort"), ("فِي", "die"), ("الْجَمِيعِ", "alle")]),
    (1032, "أَثَّرَ الْقَرَارُ فِي مُسْتَقْبَلِ الْبَلَدِ.", "Die Entscheidung wirkte sich auf die Zukunft des Landes aus.", [("أَثَّرَ", "wirkte aus"), ("الْقَرَارُ", "die Entscheidung"), ("فِي", "auf"), ("مُسْتَقْبَلِ", "die Zukunft"), ("الْبَلَدِ", "des Landes")]),
    (1033, "عَالَجَ الطَّبِيبُ الْمَرِيضَ بِمَهَارَةٍ.", "Der Arzt behandelte den Kranken geschickt.", [("عَالَجَ", "behandelte"), ("الطَّبِيبُ", "der Arzt"), ("الْمَرِيضَ", "den Kranken"), ("بِمَهَارَةٍ", "geschickt")]),
    (1033, "عَالَجَتِ الْمُؤَسَّسَةُ الْمَشْكِلَةَ بِهُدُوءٍ.", "Die Einrichtung behandelte das Problem ruhig.", [("عَالَجَتِ", "behandelte"), ("الْمُؤَسَّسَةُ", "die Einrichtung"), ("الْمَشْكِلَةَ", "das Problem"), ("بِهُدُوءٍ", "ruhig")]),
    (1033, "عَالَجْنَا الْمَوْضُوعَ فِي الِاجْتِمَاعِ.", "Wir behandelten das Thema in der Sitzung.", [("عَالَجْنَا", "wir behandelten"), ("الْمَوْضُوعَ", "das Thema"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1034, "اِمْتَحَنَ الْمُعَلِّمُ الطُّلَّابَ فِي الْعَرَبِيَّةِ.", "Der Lehrer prüfte die Schüler in Arabisch.", [("اِمْتَحَنَ", "prüfte"), ("الْمُعَلِّمُ", "der Lehrer"), ("الطُّلَّابَ", "die Schüler"), ("فِي", "in"), ("الْعَرَبِيَّةِ", "Arabisch")]),
    (1034, "اِمْتَحَنَتِ الشَّرِكَةُ الْمُوَظَّفَ الْجَدِيدَ.", "Die Firma prüfte den neuen Angestellten.", [("اِمْتَحَنَتِ", "prüfte"), ("الشَّرِكَةُ", "die Firma"), ("الْمُوَظَّفَ", "den Angestellten"), ("الْجَدِيدَ", "neuen")]),
    (1034, "اِمْتَحَنَ الرَّجُلُ قُوَّتَهُ فِي الرِّيَاضَةِ.", "Der Mann testete seine Kraft im Sport.", [("اِمْتَحَنَ", "testete"), ("الرَّجُلُ", "der Mann"), ("قُوَّتَهُ", "seine Kraft"), ("فِي", "im"), ("الرِّيَاضَةِ", "Sport")]),
    (1035, "أَوْضَحَ الْمُعَلِّمُ الْقَاعِدَةَ لِلطُّلَّابِ.", "Der Lehrer erklärte den Schülern die Regel.", [("أَوْضَحَ", "erklärte"), ("الْمُعَلِّمُ", "der Lehrer"), ("الْقَاعِدَةَ", "die Regel"), ("لِلطُّلَّابِ", "den Schülern")]),
    (1035, "أَوْضَحَتِ الْمَرْأَةُ مَوْقِفَهَا بِكَلِمَاتٍ قَلِيلَةٍ.", "Die Frau stellte ihre Haltung mit wenigen Worten klar.", [("أَوْضَحَتِ", "stellte klar"), ("الْمَرْأَةُ", "die Frau"), ("مَوْقِفَهَا", "ihre Haltung"), ("بِكَلِمَاتٍ", "mit Worten"), ("قَلِيلَةٍ", "wenigen")]),
    (1036, "الْمَصِيرُ مَجْهُولٌ لِلْإِنْسَانِ.", "Das Schicksal ist dem Menschen unbekannt.", [("الْمَصِيرُ", "das Schicksal"), ("مَجْهُولٌ", "ist unbekannt"), ("لِلْإِنْسَانِ", "dem Menschen")]),
    (1036, "مَصِيرُ الْبَلَدِ فِي أَيْدِي الشَّعْبِ.", "Das Schicksal des Landes liegt in den Händen des Volkes.", [("مَصِيرُ", "das Schicksal"), ("الْبَلَدِ", "des Landes"), ("فِي", "in"), ("أَيْدِي", "den Händen"), ("الشَّعْبِ", "des Volkes")]),
    (1036, "لَا أَحَدَ يَعْرِفُ الْمَصِيرَ.", "Niemand kennt das Schicksal.", [("لَا", "niemand"), ("أَحَدَ", "jemand"), ("يَعْرِفُ", "kennt"), ("الْمَصِيرَ", "das Schicksal")]),
    (1037, "الثَّرْوَةُ لَا تَشْتَرِي السَّعَادَةَ.", "Reichtum kauft kein Glück.", [("الثَّرْوَةُ", "der Reichtum"), ("لَا", "nicht"), ("تَشْتَرِي", "kauft"), ("السَّعَادَةَ", "das Glück")]),
    (1037, "ثَرْوَةُ الرَّجُلِ مِنْ عَمَلِهِ.", "Das Vermögen des Mannes kommt von seiner Arbeit.", [("ثَرْوَةُ", "das Vermögen"), ("الرَّجُلِ", "des Mannes"), ("مِنْ", "von"), ("عَمَلِهِ", "seiner Arbeit")]),
    (1037, "الْبَلَدُ غَنِيٌّ بِالثَّرْوَةِ الطَّبِيعِيَّةِ.", "Das Land ist reich an natürlichen Reichtümern.", [("الْبَلَدُ", "das Land"), ("غَنِيٌّ", "ist reich"), ("بِالثَّرْوَةِ", "an Reichtümern"), ("الطَّبِيعِيَّةِ", "natürlichen")]),
    (1038, "الْوِظِيفَةُ مُنَاسِبَةٌ لِلْمُوَظَّفِ.", "Die Arbeitsstelle passt zum Angestellten.", [("الْوِظِيفَةُ", "die Arbeitsstelle"), ("مُنَاسِبَةٌ", "passt"), ("لِلْمُوَظَّفِ", "zum Angestellten")]),
    (1038, "بَحَثَ الرَّجُلُ عَنْ وِظِيفَةٍ جَدِيدَةٍ.", "Der Mann suchte eine neue Arbeitsstelle.", [("بَحَثَ", "suchte"), ("الرَّجُلُ", "der Mann"), ("عَنْ", "eine"), ("وِظِيفَةٍ", "Arbeitsstelle"), ("جَدِيدَةٍ", "neue")]),
    (1038, "وَظِيفَتُهُ فِي الْمَصْنَعِ.", "Seine Arbeit ist in der Fabrik.", [("وَظِيفَتُهُ", "seine Arbeit"), ("فِي", "in"), ("الْمَصْنَعِ", "der Fabrik")]),
    (1039, "الْحُدُودُ بَيْنَ الْبَلَدَيْنِ طَوِيلَةٌ.", "Die Grenze zwischen den beiden Ländern ist lang.", [("الْحُدُودُ", "die Grenze"), ("بَيْنَ", "zwischen"), ("الْبَلَدَيْنِ", "den beiden Ländern"), ("طَوِيلَةٌ", "ist lang")]),
    (1039, "الْحُدُودُ مَفْتُوحَةٌ فِي الصَّبَاحِ.", "Die Grenze ist am Morgen offen.", [("الْحُدُودُ", "die Grenze"), ("مَفْتُوحَةٌ", "ist offen"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1039, "وَقَفَ الْجُنْدِيُّ عَلَى حُدُودِ الْبَلَدِ.", "Der Soldat stand an der Grenze des Landes.", [("وَقَفَ", "stand"), ("الْجُنْدِيُّ", "der Soldat"), ("عَلَى", "an"), ("حُدُودِ", "der Grenze"), ("الْبَلَدِ", "des Landes")]),
    (1040, "الْمُسَابَقَةُ كَانَتْ قَوِيَّةً.", "Der Wettbewerb war stark.", [("الْمُسَابَقَةُ", "der Wettbewerb"), ("كَانَتْ", "war"), ("قَوِيَّةً", "stark")]),
    (1040, "فَازَ الْفَرِيقُ فِي الْمُسَابَقَةِ.", "Die Mannschaft gewann im Wettbewerb.", [("فَازَ", "gewann"), ("الْفَرِيقُ", "die Mannschaft"), ("فِي", "im"), ("الْمُسَابَقَةِ", "Wettbewerb")]),
    (1041, "الدَّلِيلُ يُرِي السَّيَّاحَ الطَّرِيقَ.", "Der Führer zeigt dem Touristen den Weg.", [("الدَّلِيلُ", "der Führer"), ("يُرِي", "zeigt"), ("السَّيَّاحَ", "dem Touristen"), ("الطَّرِيقَ", "den Weg")]),
    (1041, "هَذَا دَلِيلٌ قَوِيٌّ عَلَى صِدْقِهِ.", "Das ist ein starker Beweis für seine Ehrlichkeit.", [("هَذَا", "das ist"), ("دَلِيلٌ", "ein Beweis"), ("قَوِيٌّ", "starker"), ("عَلَى", "für"), ("صِدْقِهِ", "seine Ehrlichkeit")]),
    (1041, "اِشْتَرَيْنَا دَلِيلَ الْمَدِينَةِ.", "Wir kauften den Stadtführer.", [("اِشْتَرَيْنَا", "wir kauften"), ("دَلِيلَ", "den Führer"), ("الْمَدِينَةِ", "der Stadt")]),
    (1042, "السَّفِيرُ يُمَثِّلُ بَلَدَهُ فِي الْخَارِجِ.", "Der Botschafter vertritt sein Land im Ausland.", [("السَّفِيرُ", "der Botschafter"), ("يُمَثِّلُ", "vertritt"), ("بَلَدَهُ", "sein Land"), ("فِي", "im"), ("الْخَارِجِ", "Ausland")]),
    (1042, "السَّفِيرُ جَدِيدٌ فِي هَذِهِ الدَّوْلَةِ.", "Der Botschafter ist neu in diesem Land.", [("السَّفِيرُ", "der Botschafter"), ("جَدِيدٌ", "ist neu"), ("فِي", "in"), ("هَذِهِ", "diesem"), ("الدَّوْلَةِ", "Land")]),
    (1042, "اجْتَمَعَ السُّفَرَاءُ فِي الْمَدِينَةِ.", "Die Botschafter trafen sich in der Stadt.", [("اجْتَمَعَ", "trafen sich"), ("السُّفَرَاءُ", "die Botschafter"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1043, "الرَّأْيُ الْعَامُّ مُهِمٌّ فِي الدِّيمُقْرَاطِيَّةِ.", "Die öffentliche Meinung ist wichtig in der Demokratie.", [("الرَّأْيُ", "die Meinung"), ("الْعَامُّ", "öffentliche"), ("مُهِمٌّ", "ist wichtig"), ("فِي", "in"), ("الدِّيمُقْرَاطِيَّةِ", "der Demokratie")]),
    (1043, "لِي رَأْيٌ آخَرُ فِي هَذِهِ الْمَسْأَلَةِ.", "Ich habe eine andere Meinung zu dieser Angelegenheit.", [("لِي", "ich habe"), ("رَأْيٌ", "eine Meinung"), ("آخَرُ", "andere"), ("فِي", "zu"), ("هَذِهِ", "dieser"), ("الْمَسْأَلَةِ", "Angelegenheit")]),
    (1043, "تَغَيَّرَ رَأْيِي بَعْدَ النَّقْشِ.", "Meine Meinung änderte sich nach der Diskussion.", [("تَغَيَّرَ", "änderte sich"), ("رَأْيِي", "meine Meinung"), ("بَعْدَ", "nach"), ("النَّقْشِ", "der Diskussion")]),
    (1044, "الشُّرْطَةُ تَحْمِي الْمَدِينَةَ.", "Die Polizei schützt die Stadt.", [("الشُّرْطَةُ", "die Polizei"), ("تَحْمِي", "schützt"), ("الْمَدِينَةَ", "die Stadt")]),
    (1044, "الشُّرْطَةُ قَرِيبَةٌ مِنَ الْبَيْتِ.", "Die Polizei ist in der Nähe des Hauses.", [("الشُّرْطَةُ", "die Polizei"), ("قَرِيبَةٌ", "ist in der Nähe"), ("مِنَ", "von"), ("الْبَيْتِ", "dem Haus")]),
    (1044, "نَادَى الرَّجُلُ الشُّرْطَةَ لِلنَّجْدَةِ.", "Der Mann rief die Polizei um Hilfe.", [("نَادَى", "rief"), ("الرَّجُلُ", "der Mann"), ("الشُّرْطَةَ", "die Polizei"), ("لِلنَّجْدَةِ", "um Hilfe")]),
    (1045, "الْمُوَظَّفُ يَعْمَلُ فِي الْمَكْتَبِ.", "Der Angestellte arbeitet im Büro.", [("الْمُوَظَّفُ", "der Angestellte"), ("يَعْمَلُ", "arbeitet"), ("فِي", "im"), ("الْمَكْتَبِ", "Büro")]),
    (1045, "الْمُوَظَّفُ مُجْتَهِدٌ فِي عَمَلِهِ.", "Der Angestellte ist fleißig in seiner Arbeit.", [("الْمُوَظَّفُ", "der Angestellte"), ("مُجْتَهِدٌ", "ist fleißig"), ("فِي", "in"), ("عَمَلِهِ", "seiner Arbeit")]),
    (1046, "الطَّبِيعَةُ جَمِيلَةٌ فِي الرَّبِيعِ.", "Die Natur ist im Frühling schön.", [("الطَّبِيعَةُ", "die Natur"), ("جَمِيلَةٌ", "ist schön"), ("فِي", "im"), ("الرَّبِيعِ", "Frühling")]),
    (1046, "نُحِبُّ الطَّبِيعَةَ وَأَشْجَارَهَا.", "Wir lieben die Natur und ihre Bäume.", [("نُحِبُّ", "wir lieben"), ("الطَّبِيعَةَ", "die Natur"), ("وَأَشْجَارَهَا", "und ihre Bäume")]),
    (1046, "الطَّبِيعَةُ تُعْطِينَا الْهَوَاءَ النَّظِيفَ.", "Die Natur gibt uns die saubere Luft.", [("الطَّبِيعَةُ", "die Natur"), ("تُعْطِينَا", "gibt uns"), ("الْهَوَاءَ", "die Luft"), ("النَّظِيفَ", "saubere")]),
    (1047, "الْحَيَوَانُ يَأْكُلُ الْعُشْبَ فِي الْحَقْلِ.", "Das Tier frisst das Gras auf dem Feld.", [("الْحَيَوَانُ", "das Tier"), ("يَأْكُلُ", "frisst"), ("الْعُشْبَ", "das Gras"), ("فِي", "auf"), ("الْحَقْلِ", "dem Feld")]),
    (1047, "الْحَيَوَانُ وَلِيدٌ فِي الْحَظِيرَةِ.", "Das Tier ist ein Junges im Stall.", [("الْحَيَوَانُ", "das Tier"), ("وَلِيدٌ", "ist ein Junges"), ("فِي", "im"), ("الْحَظِيرَةِ", "Stall")]),
    (1047, "حَيَوَانُ الْغَابَةِ كَبِيرٌ وَقَوِيٌّ.", "Das Waldtier ist groß und stark.", [("حَيَوَانُ", "das Tier"), ("الْغَابَةِ", "des Waldes"), ("كَبِيرٌ", "ist groß"), ("وَقَوِيٌّ", "und stark")]),
    (1048, "النَّبَاتُ يَحْتَاجُ إِلَى الْمَاءِ.", "Die Pflanze braucht Wasser.", [("النَّبَاتُ", "die Pflanze"), ("يَحْتَاجُ", "braucht"), ("إِلَى", "das"), ("الْمَاءِ", "Wasser")]),
    (1048, "نَبَاتُ الْحَدِيقَةِ أَخْضَرُ فِي الصَّيْفِ.", "Die Gartenpflanze ist im Sommer grün.", [("نَبَاتُ", "die Pflanze"), ("الْحَدِيقَةِ", "des Gartens"), ("أَخْضَرُ", "ist grün"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1048, "غَرَسَ الْفَلَّاحُ النَّبَاتَ فِي الْأَرْضِ.", "Der Bauer pflanzte die Pflanze in die Erde.", [("غَرَسَ", "pflanzte"), ("الْفَلَّاحُ", "der Bauer"), ("النَّبَاتَ", "die Pflanze"), ("فِي", "in"), ("الْأَرْضِ", "die Erde")]),
    (1049, "الْمُسْتَشْفَى بَعِيدٌ عَنِ الْمَدِينَةِ.", "Das Krankenhaus ist weit von der Stadt entfernt.", [("الْمُسْتَشْفَى", "das Krankenhaus"), ("بَعِيدٌ", "ist weit entfernt"), ("عَنِ", "von"), ("الْمَدِينَةِ", "der Stadt")]),
    (1049, "الْمُسْتَشْفَى مَلِيءٌ بِالْمَرْضَى.", "Das Krankenhaus ist voll mit Kranken.", [("الْمُسْتَشْفَى", "das Krankenhaus"), ("مَلِيءٌ", "ist voll"), ("بِالْمَرْضَى", "mit Kranken")]),
    (1049, "ذَهَبْنَا إِلَى الْمُسْتَشْفَى فِي الصَّبَاحِ.", "Wir gingen am Morgen ins Krankenhaus.", [("ذَهَبْنَا", "wir gingen"), ("إِلَى", "ins"), ("الْمُسْتَشْفَى", "Krankenhaus"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1050, "الْحَدِيثُ وَسِيلَةٌ لِلْفَهْمِ.", "Das Gespräch ist ein Mittel zum Verstehen.", [("الْحَدِيثُ", "das Gespräch"), ("وَسِيلَةٌ", "ist ein Mittel"), ("لِلْفَهْمِ", "zum Verstehen")]),
    (1050, "الْوَسِيلَةُ أَسْرَعُ مِنَ الْقِطَارِ.", "Das Verkehrsmittel ist schneller als der Zug.", [("الْوَسِيلَةُ", "das Verkehrsmittel"), ("أَسْرَعُ", "ist schneller"), ("مِنَ", "als"), ("الْقِطَارِ", "der Zug")]),
    (1051, "الطَّرِيقَةُ سَهْلَةٌ لِلتَّعَلُّمِ.", "Die Methode ist einfach zum Lernen.", [("الطَّرِيقَةُ", "die Methode"), ("سَهْلَةٌ", "ist einfach"), ("لِلتَّعَلُّمِ", "zum Lernen")]),
    (1051, "طَرِيقَةُ التَّدْرِيسِ مُهِمَّةٌ.", "Die Unterrichtsmethode ist wichtig.", [("طَرِيقَةُ", "die Methode"), ("التَّدْرِيسِ", "des Unterrichts"), ("مُهِمَّةٌ", "ist wichtig")]),
    (1051, "بَحَثْنَا عَنْ طَرِيقَةٍ أَفْضَلَ.", "Wir suchten nach einer besseren Methode.", [("بَحَثْنَا", "wir suchten"), ("عَنْ", "nach"), ("طَرِيقَةٍ", "einer Methode"), ("أَفْضَلَ", "besseren")]),
    (1052, "الْعِلَاقَةُ بَيْنَهُمَا قَوِيَّةٌ.", "Die Beziehung zwischen den beiden ist stark.", [("الْعِلَاقَةُ", "die Beziehung"), ("بَيْنَهُمَا", "zwischen den beiden"), ("قَوِيَّةٌ", "ist stark")]),
    (1052, "عِلَاقَةُ الصَّدَاقَةِ تَدُومُ.", "Die Freundschaftsbeziehung dauert an.", [("عِلَاقَةُ", "die Beziehung"), ("الصَّدَاقَةِ", "der Freundschaft"), ("تَدُومُ", "dauert an")]),
    (1052, "حَسَّنَتِ الْعِلَاقَةُ بَيْنَ الْجِيرَانِ.", "Die Beziehung zwischen den Nachbarn verbesserte sich.", [("حَسَّنَتِ", "verbesserte sich"), ("الْعِلَاقَةُ", "die Beziehung"), ("بَيْنَ", "zwischen"), ("الْجِيرَانِ", "den Nachbarn")]),
    (1053, "الصَّدَاقَةُ ثَمِينَةٌ فِي الْحَيَاةِ.", "Die Freundschaft ist wertvoll im Leben.", [("الصَّدَاقَةُ", "die Freundschaft"), ("ثَمِينَةٌ", "ist wertvoll"), ("فِي", "im"), ("الْحَيَاةِ", "Leben")]),
    (1053, "الصَّدَاقَةُ بَيْنَ الطُّلَّابِ قَوِيَّةٌ.", "Die Freundschaft zwischen den Schülern ist stark.", [("الصَّدَاقَةُ", "die Freundschaft"), ("بَيْنَ", "zwischen"), ("الطُّلَّابِ", "den Schülern"), ("قَوِيَّةٌ", "ist stark")]),
    (1053, "نَبَنِي الصَّدَاقَةَ عَلَى الثِّقَةِ.", "Wir bauen die Freundschaft auf Vertrauen.", [("نَبَنِي", "wir bauen"), ("الصَّدَاقَةَ", "die Freundschaft"), ("عَلَى", "auf"), ("الثِّقَةِ", "Vertrauen")]),
    (1054, "الْعَدَاوَةُ ضَارَّةٌ لِلْجَمِيعِ.", "Die Feindschaft ist für alle schädlich.", [("الْعَدَاوَةُ", "die Feindschaft"), ("ضَارَّةٌ", "ist schädlich"), ("لِلْجَمِيعِ", "für alle")]),
    (1054, "الْعَدَاوَةُ بَيْنَ الْعَائِلَتَيْنِ قَدِيمَةٌ.", "Die Feindschaft zwischen den beiden Familien ist alt.", [("الْعَدَاوَةُ", "die Feindschaft"), ("بَيْنَ", "zwischen"), ("الْعَائِلَتَيْنِ", "den beiden Familien"), ("قَدِيمَةٌ", "ist alt")]),
    (1054, "اِنْتَهَتِ الْعَدَاوَةُ بَعْدَ الصُّلْحِ.", "Die Feindschaft endete nach der Versöhnung.", [("اِنْتَهَتِ", "endete"), ("الْعَدَاوَةُ", "die Feindschaft"), ("بَعْدَ", "nach"), ("الصُّلْحِ", "der Versöhnung")]),
    (1055, "الْمُنْتَجُ جَدِيدٌ فِي السُّوقِ.", "Das Produkt ist neu auf dem Markt.", [("الْمُنْتَجُ", "das Produkt"), ("جَدِيدٌ", "ist neu"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1055, "انْتَجَتِ الشَّرِكَةُ مُنْتَجًا جَيِّدًا.", "Die Firma stellte ein gutes Produkt her.", [("انْتَجَتِ", "stellte her"), ("الشَّرِكَةُ", "die Firma"), ("مُنْتَجًا", "ein Produkt"), ("جَيِّدًا", "gutes")]),
    (1055, "الْمُنْتَجُ يُبَاعُ فِي كُلِّ الْمَحَالِّ.", "Das Produkt wird in allen Läden verkauft.", [("الْمُنْتَجُ", "das Produkt"), ("يُبَاعُ", "wird verkauft"), ("فِي", "in"), ("كُلِّ", "allen"), ("الْمَحَالِّ", "Läden")]),
    (1056, "الْهَاتِفُ يَرِنُّ فِي الصَّبَاحِ.", "Das Telefon klingelt am Morgen.", [("الْهَاتِفُ", "das Telefon"), ("يَرِنُّ", "klingelt"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1056, "الْهَاتِفُ جَدِيدٌ وَسَرِيعٌ.", "Das Telefon ist neu und schnell.", [("الْهَاتِفُ", "das Telefon"), ("جَدِيدٌ", "ist neu"), ("وَسَرِيعٌ", "und schnell")]),
    (1057, "الِاخْتِبَارُ سَهْلٌ هَذِهِ الْمَرَّةَ.", "Der Test ist dieses Mal einfach.", [("الِاخْتِبَارُ", "der Test"), ("سَهْلٌ", "ist einfach"), ("هَذِهِ", "dieses"), ("الْمَرَّةَ", "Mal")]),
    (1057, "اِخْتِبَارُ اللُّغَةِ طَوِيلٌ.", "Der Sprachniveau-Test ist lang.", [("اِخْتِبَارُ", "der Test"), ("اللُّغَةِ", "der Sprache"), ("طَوِيلٌ", "ist lang")]),
    (1057, "نَجَحْنَا فِي الِاخْتِبَارِ بِجَهْدٍ كَبِيرٍ.", "Wir bestanden den Test mit großer Anstrengung.", [("نَجَحْنَا", "wir bestanden"), ("فِي", "in"), ("الِاخْتِبَارِ", "dem Test"), ("بِجَهْدٍ", "mit Anstrengung"), ("كَبِيرٍ", "großer")]),
    (1058, "النَّصِيحَةُ مُفِيدَةٌ لِلطَّالِبِ.", "Der Ratschlag ist dem Studenten nützlich.", [("النَّصِيحَةُ", "der Ratschlag"), ("مُفِيدَةٌ", "ist nützlich"), ("لِلطَّالِبِ", "dem Studenten")]),
    (1058, "نَصِيحَةُ الطَّبِيبِ مُهِمَّةٌ.", "Der Rat des Arztes ist wichtig.", [("نَصِيحَةُ", "der Rat"), ("الطَّبِيبِ", "des Arztes"), ("مُهِمَّةٌ", "ist wichtig")]),
    (1058, "أَخَذْنَا بِالنَّصِيحَةِ فِي الْوَقْتِ.", "Wir folgten dem Ratschlag rechtzeitig.", [("أَخَذْنَا", "wir folgten"), ("بِالنَّصِيحَةِ", "dem Ratschlag"), ("فِي", "zur"), ("الْوَقْتِ", "Zeit")]),
    (1059, "الصَّحِيفَةُ تَصْدُرُ كُلَّ يَوْمٍ.", "Die Zeitung erscheint jeden Tag.", [("الصَّحِيفَةُ", "die Zeitung"), ("تَصْدُرُ", "erscheint"), ("كُلَّ", "jeden"), ("يَوْمٍ", "Tag")]),
    (1059, "الصَّحِيفَةُ الْجَدِيدَةُ مُهِمَّةٌ.", "Die neue Zeitung ist wichtig.", [("الصَّحِيفَةُ", "die Zeitung"), ("الْجَدِيدَةُ", "neue"), ("مُهِمَّةٌ", "ist wichtig")]),
    (1059, "قَرَأْنَا الْأَخْبَارَ فِي الصَّحِيفَةِ.", "Wir lasen die Nachrichten in der Zeitung.", [("قَرَأْنَا", "wir lasen"), ("الْأَخْبَارَ", "die Nachrichten"), ("فِي", "in"), ("الصَّحِيفَةِ", "der Zeitung")]),
    (1060, "الْمَجْلِسُ يَجْتَمِعُ فِي الْمَدِينَةِ.", "Der Rat versammelt sich in der Stadt.", [("الْمَجْلِسُ", "der Rat"), ("يَجْتَمِعُ", "versammelt sich"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1060, "مَجْلِسُ الْبَلَدِيَّةِ قَرِيبٌ مِنَ السُّوقِ.", "Der Gemeinderat ist in der Nähe des Marktes.", [("مَجْلِسُ", "der Rat"), ("الْبَلَدِيَّةِ", "der Gemeinde"), ("قَرِيبٌ", "ist in der Nähe"), ("مِنَ", "von"), ("السُّوقِ", "dem Markt")]),
    (1060, "اجْتَمَعَ الْمَجْلِسُ فِي الْقَاعَةِ.", "Der Rat versammelte sich im Saal.", [("اجْتَمَعَ", "versammelte sich"), ("الْمَجْلِسُ", "der Rat"), ("فِي", "im"), ("الْقَاعَةِ", "Saal")]),
    (1061, "الِاجْتِمَاعُ كَانَ طَوِيلًا الْيَوْمَ.", "Die Versammlung war heute lang.", [("الِاجْتِمَاعُ", "die Versammlung"), ("كَانَ", "war"), ("طَوِيلًا", "lang"), ("الْيَوْمَ", "heute")]),
    (1061, "اِجْتِمَاعُ الْعَائِلَةِ فِي الْبَيْتِ.", "Die Familientreff ist im Haus.", [("اِجْتِمَاعُ", "die Versammlung"), ("الْعَائِلَةِ", "der Familie"), ("فِي", "im"), ("الْبَيْتِ", "Haus")]),
    (1062, "الْمُوَاطِنُ يَدْفَعُ الضَّرِيبَةَ.", "Der Bürger zahlt die Steuer.", [("الْمُوَاطِنُ", "der Bürger"), ("يَدْفَعُ", "zahlt"), ("الضَّرِيبَةَ", "die Steuer")]),
    (1062, "الْمُوَاطِنُونَ يُحِبُّونَ بَلَدَهُمْ.", "Die Bürger lieben ihr Land.", [("الْمُوَاطِنُونَ", "die Bürger"), ("يُحِبُّونَ", "lieben"), ("بَلَدَهُمْ", "ihr Land")]),
    (1062, "الْمُوَاطِنُ الصَّالِحُ يَنْصَحُ غَيْرَهُ.", "Der gute Bürger rät den anderen.", [("الْمُوَاطِنُ", "der Bürger"), ("الصَّالِحُ", "gute"), ("يَنْصَحُ", "rät"), ("غَيْرَهُ", "den anderen")]),
    (1063, "الدَّعْوَةُ إِلَى الْعُرْسِ قَدِيمَةٌ.", "Die Einladung zur Hochzeit ist alt.", [("الدَّعْوَةُ", "die Einladung"), ("إِلَى", "zur"), ("الْعُرْسِ", "Hochzeit"), ("قَدِيمَةٌ", "ist alt")]),
    (1063, "دَعْوَةُ الصَّدِيقِ جَاءَتْ أَمْسِ.", "Die Einladung des Freundes kam gestern.", [("دَعْوَةُ", "die Einladung"), ("الصَّدِيقِ", "des Freundes"), ("جَاءَتْ", "kam"), ("أَمْسِ", "gestern")]),
    (1063, "قَبِلْنَا الدَّعْوَةَ بِلَا تَرَدُّدٍ.", "Wir nahmen die Einladung ohne Zögern an.", [("قَبِلْنَا", "wir nahmen an"), ("الدَّعْوَةَ", "die Einladung"), ("بِلَا", "ohne"), ("تَرَدُّدٍ", "Zögern")]),
    (1064, "الْعَشَاءُ جَاهِزٌ فِي الْمَطْبَخِ.", "Das Abendessen ist in der Küche fertig.", [("الْعَشَاءُ", "das Abendessen"), ("جَاهِزٌ", "ist fertig"), ("فِي", "in"), ("الْمَطْبَخِ", "der Küche")]),
    (1064, "عَشَاءُ الْعَائِلَةِ فِي السَّابِعَةِ.", "Das Abendessen der Familie ist um sieben.", [("عَشَاءُ", "das Abendessen"), ("الْعَائِلَةِ", "der Familie"), ("فِي", "um"), ("السَّابِعَةِ", "sieben")]),
    (1064, "أَعَدَّتِ الْأُمُّ الْعَشَاءَ بِسُرْعَةٍ.", "Die Mutter bereitete das Abendessen schnell zu.", [("أَعَدَّتِ", "bereitete zu"), ("الْأُمُّ", "die Mutter"), ("الْعَشَاءَ", "das Abendessen"), ("بِسُرْعَةٍ", "schnell")]),
    (1065, "الْفُطُورُ فِي الصَّبَاحِ البَاكِرِ.", "Das Frühstück ist am frühen Morgen.", [("الْفُطُورُ", "das Frühstück"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen"), ("البَاكِرِ", "frühen")]),
    (1065, "فُطُورُ الْأَطْفَالِ فِي الْمَدْرَسَةِ.", "Das Frühstück der Kinder ist in der Schule.", [("فُطُورُ", "das Frühstück"), ("الْأَطْفَالِ", "der Kinder"), ("فِي", "in"), ("الْمَدْرَسَةِ", "der Schule")]),
    (1065, "أَكَلْنَا الْفُطُورَ مَعًا.", "Wir aßen das Frühstück zusammen.", [("أَكَلْنَا", "wir aßen"), ("الْفُطُورَ", "das Frühstück"), ("مَعًا", "zusammen")]),
    (1066, "الْحَفْلَةُ فِي نِهَايَةِ الْأُسْبُوعِ.", "Die Feier ist am Wochenende.", [("الْحَفْلَةُ", "die Feier"), ("فِي", "am"), ("نِهَايَةِ", "Ende"), ("الْأُسْبُوعِ", "der Woche")]),
    (1066, "حَفْلَةُ عِيدِ الْمِيلَادِ جَمِيلَةٌ.", "Die Geburtstagsfeier ist schön.", [("حَفْلَةُ", "die Feier"), ("عِيدِ", "des Fests"), ("الْمِيلَادِ", "der Geburt"), ("جَمِيلَةٌ", "ist schön")]),
    (1067, "الْعُرْسُ فِي قَرْيَةٍ جَمِيلَةٍ.", "Die Hochzeit ist in einem schönen Dorf.", [("الْعُرْسُ", "die Hochzeit"), ("فِي", "in"), ("قَرْيَةٍ", "einem Dorf"), ("جَمِيلَةٍ", "schönen")]),
    (1067, "عُرْسُ الْأَخِ قَدِيمٌ وَمُبَارَكٌ.", "Die Hochzeit des Bruders ist alt und gesegnet.", [("عُرْسُ", "die Hochzeit"), ("الْأَخِ", "des Bruders"), ("قَدِيمٌ", "ist alt"), ("وَمُبَارَكٌ", "und gesegnet")]),
    (1067, "كَانَ الْعُرْسُ فِي شَهْرِ الصَّيْفِ.", "Die Hochzeit war im Sommermonat.", [("كَانَ", "war"), ("الْعُرْسُ", "die Hochzeit"), ("فِي", "im"), ("شَهْرِ", "Monat"), ("الصَّيْفِ", "des Sommers")]),
    (1068, "السِّكِّينُ حَادٌّ فِي الْمَطْبَخِ.", "Das Messer ist in der Küche scharf.", [("السِّكِّينُ", "das Messer"), ("حَادٌّ", "ist scharf"), ("فِي", "in"), ("الْمَطْبَخِ", "der Küche")]),
    (1068, "سِكِّينُ الْخُبْزِ كَبِيرٌ.", "Das Brotmesser ist groß.", [("سِكِّينُ", "das Messer"), ("الْخُبْزِ", "des Brots"), ("كَبِيرٌ", "ist groß")]),
    (1068, "قَطَعْنَا الْخُبْزَ بِالسِّكِّينِ.", "Wir schnitten das Brot mit dem Messer.", [("قَطَعْنَا", "wir schnitten"), ("الْخُبْزَ", "das Brot"), ("بِالسِّكِّينِ", "mit dem Messer")]),
    (1069, "الشَّوْكَةُ وَضِعَتْ عَلَى الطَّبَقِ.", "Die Gabel wurde auf den Teller gelegt.", [("الشَّوْكَةُ", "die Gabel"), ("وَضِعَتْ", "wurde gelegt"), ("عَلَى", "auf"), ("الطَّبَقِ", "den Teller")]),
    (1069, "شَوْكَةُ الْأَكْلِ صَغِيرَةٌ.", "Die Essgabel ist klein.", [("شَوْكَةُ", "die Gabel"), ("الْأَكْلِ", "des Essens"), ("صَغِيرَةٌ", "ist klein")]),
    (1069, "أَكَلْنَا بِالشَّوْكَةِ فِي الْمَطْعَمِ.", "Wir aßen mit der Gabel im Restaurant.", [("أَكَلْنَا", "wir aßen"), ("بِالشَّوْكَةِ", "mit der Gabel"), ("فِي", "im"), ("الْمَطْعَمِ", "Restaurant")]),
    (1070, "الطَّبَقُ مَمْلُوءٌ بِالطَّعَامِ.", "Der Teller ist voll mit Essen.", [("الطَّبَقُ", "der Teller"), ("مَمْلُوءٌ", "ist voll"), ("بِالطَّعَامِ", "mit Essen")]),
    (1070, "طَبَقُ الْفَاكِهَةِ عَلَى الطَّاوِلَةِ.", "Die Obstschale ist auf dem Tisch.", [("طَبَقُ", "die Schale"), ("الْفَاكِهَةِ", "der Früchte"), ("عَلَى", "auf"), ("الطَّاوِلَةِ", "dem Tisch")]),
    (1070, "وَضَعْنَا الطَّبَقَ فِي الْمُغْسَلَةِ.", "Wir stellten den Teller in die Spüle.", [("وَضَعْنَا", "wir stellten"), ("الطَّبَقَ", "den Teller"), ("فِي", "in"), ("الْمُغْسَلَةِ", "die Spüle")]),
    (1071, "الْمِرْوَحَةُ تُبَرِّدُ الْغُرْفَةَ.", "Der Ventilator kühlt das Zimmer.", [("الْمِرْوَحَةُ", "der Ventilator"), ("تُبَرِّدُ", "kühlt"), ("الْغُرْفَةَ", "das Zimmer")]),
    (1071, "مِرْوَحَةُ السَّقْفِ تَدُورُ بِسُرْعَةٍ.", "Der Deckenventilator dreht sich schnell.", [("مِرْوَحَةُ", "der Ventilator"), ("السَّقْفِ", "der Decke"), ("تَدُورُ", "dreht sich"), ("بِسُرْعَةٍ", "schnell")]),
    (1071, "شَغَّلْنَا الْمِرْوَحَةَ فِي الصَّيْفِ.", "Wir schalteten den Ventilator im Sommer ein.", [("شَغَّلْنَا", "wir schalteten ein"), ("الْمِرْوَحَةَ", "den Ventilator"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1072, "الْوَجْبَةُ غَدَاءٌ فِي الظُّهْرِ.", "Die Mahlzeit ist das Mittagessen am Mittag.", [("الْوَجْبَةُ", "die Mahlzeit"), ("غَدَاءٌ", "ist Mittagessen"), ("فِي", "am"), ("الظُّهْرِ", "Mittag")]),
    (1072, "وَجْبَةُ الْمَسَاءِ خَفِيفَةٌ.", "Die Abendmahlzeit ist leicht.", [("وَجْبَةُ", "die Mahlzeit"), ("الْمَسَاءِ", "des Abends"), ("خَفِيفَةٌ", "ist leicht")]),
    (1072, "اِشْتَرَيْنَا وَجْبَةً مِنَ السُّوقِ.", "Wir kauften eine Mahlzeit auf dem Markt.", [("اِشْتَرَيْنَا", "wir kauften"), ("وَجْبَةً", "eine Mahlzeit"), ("مِنَ", "auf"), ("السُّوقِ", "dem Markt")]),
    (1073, "الْفِنْجَانُ صَغِيرٌ وَجَمِيلٌ.", "Die Tasse ist klein und schön.", [("الْفِنْجَانُ", "die Tasse"), ("صَغِيرٌ", "ist klein"), ("وَجَمِيلٌ", "und schön")]),
    (1073, "فِنْجَانُ الْقَهْوَةِ سَاخِنٌ.", "Die Kaffeetasse ist heiß.", [("فِنْجَانُ", "die Tasse"), ("الْقَهْوَةِ", "des Kaffees"), ("سَاخِنٌ", "ist heiß")]),
    (1073, "وَضَعْنَا الْفِنْجَانَ عَلَى الصِّينِيَّةِ.", "Wir stellten die Tasse auf die Untertasse.", [("وَضَعْنَا", "wir stellten"), ("الْفِنْجَانَ", "die Tasse"), ("عَلَى", "auf"), ("الصِّينِيَّةِ", "die Untertasse")]),
    (1074, "الْحَلِيبُ طَازَجٌ فِي الصَّبَاحِ.", "Die Milch ist frisch am Morgen.", [("الْحَلِيبُ", "die Milch"), ("طَازَجٌ", "ist frisch"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1074, "حَلِيبُ الْبَقَرَةِ مُفِيدٌ لِلْأَطْفَالِ.", "Die Kuhmilch ist für Kinder nützlich.", [("حَلِيبُ", "die Milch"), ("الْبَقَرَةِ", "der Kuh"), ("مُفِيدٌ", "ist nützlich"), ("لِلْأَطْفَالِ", "für Kinder")]),
    (1075, "الْعَصِيرُ بَارِدٌ فِي الثَّلَّاجَةِ.", "Der Saft ist kalt im Kühlschrank.", [("الْعَصِيرُ", "der Saft"), ("بَارِدٌ", "ist kalt"), ("فِي", "im"), ("الثَّلَّاجَةِ", "Kühlschrank")]),
    (1075, "عَصِيرُ الْبُرْتُقَالِ لَذِيذٌ.", "Der Orangensaft ist lecker.", [("عَصِيرُ", "der Saft"), ("الْبُرْتُقَالِ", "der Orangen"), ("لَذِيذٌ", "ist lecker")]),
    (1075, "شَرِبْنَا الْعَصِيرَ فِي الصَّيْفِ.", "Wir tranken den Saft im Sommer.", [("شَرِبْنَا", "wir tranken"), ("الْعَصِيرَ", "den Saft"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1076, "الْمَفْهُومُ وَاضِحٌ لَدَى الطُّلَّابِ.", "Der Begriff ist den Schülern klar.", [("الْمَفْهُومُ", "der Begriff"), ("وَاضِحٌ", "ist klar"), ("لَدَى", "den"), ("الطُّلَّابِ", "Schülern")]),
    (1076, "مَفْهُومُ الْحُرِّيَّةِ وَاسِعٌ.", "Der Begriff der Freiheit ist weit.", [("مَفْهُومُ", "der Begriff"), ("الْحُرِّيَّةِ", "der Freiheit"), ("وَاسِعٌ", "ist weit")]),
    (1076, "شَرَحْنَا الْمَفْهُومَ بِأَمْثِلَةٍ.", "Wir erklärten den Begriff mit Beispielen.", [("شَرَحْنَا", "wir erklärten"), ("الْمَفْهُومَ", "den Begriff"), ("بِأَمْثِلَةٍ", "mit Beispielen")]),
    (1077, "الْمَعْلُومَةُ صَحِيحَةٌ وَمُهِمَّةٌ.", "Die Information ist richtig und wichtig.", [("الْمَعْلُومَةُ", "die Information"), ("صَحِيحَةٌ", "ist richtig"), ("وَمُهِمَّةٌ", "und wichtig")]),
    (1077, "مَعْلُومَةُ السَّفَرِ جَاءَتْ مُبَكِّرًا.", "Die Reiseinformation kam früh.", [("مَعْلُومَةُ", "die Information"), ("السَّفَرِ", "der Reise"), ("جَاءَتْ", "kam"), ("مُبَكِّرًا", "früh")]),
    (1077, "جَمَعْنَا الْمَعْلُومَاتِ مِنَ الْإِنْتَرْنِتِ.", "Wir sammelten die Informationen aus dem Internet.", [("جَمَعْنَا", "wir sammelten"), ("الْمَعْلُومَاتِ", "die Informationen"), ("مِنَ", "aus"), ("الْإِنْتَرْنِتِ", "dem Internet")]),
    (1078, "الْخِبْرَةُ مُهِمَّةٌ فِي الْعَمَلِ.", "Die Erfahrung ist wichtig in der Arbeit.", [("الْخِبْرَةُ", "die Erfahrung"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "in"), ("الْعَمَلِ", "der Arbeit")]),
    (1078, "خِبْرَةُ الطَّبِيبِ طَوِيلَةٌ.", "Die Erfahrung des Arztes ist lang.", [("خِبْرَةُ", "die Erfahrung"), ("الطَّبِيبِ", "des Arztes"), ("طَوِيلَةٌ", "ist lang")]),
    (1078, "اِكْتَسَبْنَا الْخِبْرَةَ مِنَ الْعَمَلِ الْيَوْمِيِّ.", "Wir gewannen die Erfahrung durch die tägliche Arbeit.", [("اِكْتَسَبْنَا", "wir gewannen"), ("الْخِبْرَةَ", "die Erfahrung"), ("مِنَ", "durch"), ("الْعَمَلِ", "die Arbeit"), ("الْيَوْمِيِّ", "tägliche")]),
    (1079, "الْقَاعِدَةُ مَكْتُوبَةٌ فِي الْكِتَابِ.", "Die Regel ist im Buch geschrieben.", [("الْقَاعِدَةُ", "die Regel"), ("مَكْتُوبَةٌ", "ist geschrieben"), ("فِي", "im"), ("الْكِتَابِ", "Buch")]),
    (1079, "قَاعِدَةُ النَّحْوِ وَاضِحَةٌ.", "Die Grammatikregel ist klar.", [("قَاعِدَةُ", "die Regel"), ("النَّحْوِ", "der Grammatik"), ("وَاضِحَةٌ", "ist klar")]),
    (1079, "فَهِمْنَا الْقَاعِدَةَ بِمِثَالٍ.", "Wir verstanden die Regel mit einem Beispiel.", [("فَهِمْنَا", "wir verstanden"), ("الْقَاعِدَةَ", "die Regel"), ("بِمِثَالٍ", "mit einem Beispiel")]),
    (1080, "الْمَبْدَأُ أَسَاسُ كُلِّ عَمَلٍ.", "Das Prinzip ist die Grundlage jeder Arbeit.", [("الْمَبْدَأُ", "das Prinzip"), ("أَسَاسُ", "ist die Grundlage"), ("كُلِّ", "jeder"), ("عَمَلٍ", "Arbeit")]),
    (1080, "مَبْدَأُ الْمُدِيرِ وَاضِحٌ لِلْجَمِيعِ.", "Das Prinzip des Direktors ist allen klar.", [("مَبْدَأُ", "das Prinzip"), ("الْمُدِيرِ", "des Direktors"), ("وَاضِحٌ", "ist klar"), ("لِلْجَمِيعِ", "allen")]),
    (1081, "النَّظَرِيَّةُ قَدِيمَةٌ فِي الْعُلُومِ.", "Die Theorie ist alt in den Wissenschaften.", [("النَّظَرِيَّةُ", "die Theorie"), ("قَدِيمَةٌ", "ist alt"), ("فِي", "in"), ("الْعُلُومِ", "den Wissenschaften")]),
    (1081, "نَظَرِيَّةُ التَّعَلُّمِ مُهِمَّةٌ.", "Die Lerntheorie ist wichtig.", [("نَظَرِيَّةُ", "die Theorie"), ("التَّعَلُّمِ", "des Lernens"), ("مُهِمَّةٌ", "ist wichtig")]),
    (1081, "دَرَسْنَا النَّظَرِيَّةَ فِي الْجَامِعَةِ.", "Wir studierten die Theorie an der Universität.", [("دَرَسْنَا", "wir studierten"), ("النَّظَرِيَّةَ", "die Theorie"), ("فِي", "an"), ("الْجَامِعَةِ", "der Universität")]),
    (1082, "التَّجْرِبَةُ نَاجِحَةٌ فِي الْمُخْتَبَرِ.", "Der Versuch ist im Labor erfolgreich.", [("التَّجْرِبَةُ", "der Versuch"), ("نَاجِحَةٌ", "ist erfolgreich"), ("فِي", "im"), ("الْمُخْتَبَرِ", "Labor")]),
    (1082, "تَجْرِبَةُ الْعَمَلِ تُفِيدُ الشَّبَابَ.", "Die Berufserfahrung nützt den Jugendlichen.", [("تَجْرِبَةُ", "die Erfahrung"), ("الْعَمَلِ", "der Arbeit"), ("تُفِيدُ", "nützt"), ("الشَّبَابَ", "den Jugendlichen")]),
    (1082, "خُضْنَا التَّجْرِبَةَ بِشَجَاعَةٍ.", "Wir wagten den Versuch mutig.", [("خُضْنَا", "wir wagten"), ("التَّجْرِبَةَ", "den Versuch"), ("بِشَجَاعَةٍ", "mutig")]),
    (1083, "الدَّرَجَةُ عَالِيَةٌ فِي الِامْتِحَانِ.", "Die Note ist hoch in der Prüfung.", [("الدَّرَجَةُ", "die Note"), ("عَالِيَةٌ", "ist hoch"), ("فِي", "in"), ("الِامْتِحَانِ", "der Prüfung")]),
    (1083, "دَرَجَةُ الْحَرَارَةِ مُرْتَفِعَةٌ الْيَوْمَ.", "Die Temperatur ist heute hoch.", [("دَرَجَةُ", "der Grad"), ("الْحَرَارَةِ", "der Wärme"), ("مُرْتَفِعَةٌ", "ist hoch"), ("الْيَوْمَ", "heute")]),
    (1083, "نَزَلْنَا دَرَجَةً فِي السُّلَّمِ.", "Wir stiegen eine Stufe auf der Treppe hinab.", [("نَزَلْنَا", "wir stiegen hinab"), ("دَرَجَةً", "eine Stufe"), ("فِي", "auf"), ("السُّلَّمِ", "der Treppe")]),
    (1084, "الْمَرْحَلَةُ الْأُولَى مُهِمَّةٌ.", "Die erste Phase ist wichtig.", [("الْمَرْحَلَةُ", "die Phase"), ("الْأُولَى", "erste"), ("مُهِمَّةٌ", "ist wichtig")]),
    (1084, "مَرْحَلَةُ الْمَشْرُوعِ طَوِيلَةٌ.", "Die Projektphase ist lang.", [("مَرْحَلَةُ", "die Phase"), ("الْمَشْرُوعِ", "des Projekts"), ("طَوِيلَةٌ", "ist lang")]),
    (1084, "اِنْتَهَتِ الْمَرْحَلَةُ بِالنَّجَاحِ.", "Die Phase endete mit Erfolg.", [("اِنْتَهَتِ", "endete"), ("الْمَرْحَلَةُ", "die Phase"), ("بِالنَّجَاحِ", "mit Erfolg")]),
    (1085, "الْوِحْدَةُ قَوِيَّةٌ فِي الْعَمَلِ.", "Die Einheit ist stark in der Arbeit.", [("الْوِحْدَةُ", "die Einheit"), ("قَوِيَّةٌ", "ist stark"), ("فِي", "in"), ("الْعَمَلِ", "der Arbeit")]),
    (1085, "وِحْدَةُ الطَّبِّ فِي السُّوقِ.", "Die medizinische Abteilung ist auf dem Markt.", [("وِحْدَةُ", "die Abteilung"), ("الطَّبِّ", "der Medizin"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1086, "النَّوْعُ الْجَدِيدُ مَطْلُوبٌ فِي السُّوقِ.", "Die neue Art ist auf dem Markt gefragt.", [("النَّوْعُ", "die Art"), ("الْجَدِيدُ", "neue"), ("مَطْلُوبٌ", "ist gefragt"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1086, "نَوْعُ الْفَاكِهَةِ لَذِيذٌ.", "Die Obstsorte ist lecker.", [("نَوْعُ", "die Sorte"), ("الْفَاكِهَةِ", "der Früchte"), ("لَذِيذٌ", "ist lecker")]),
    (1086, "مَا هَذَا النَّوْعُ مِنَ الْحَيَوَانَاتِ؟", "Was ist das für eine Tierart?", [("مَا", "was"), ("هَذَا", "das ist"), ("النَّوْعُ", "die Art"), ("مِنَ", "von"), ("الْحَيَوَانَاتِ", "den Tieren")]),
    (1087, "الْمِقْدَارُ مَعْرُوفٌ فِي الْوَثِيقَةِ.", "Die Menge ist im Dokument bekannt.", [("الْمِقْدَارُ", "die Menge"), ("مَعْرُوفٌ", "ist bekannt"), ("فِي", "im"), ("الْوَثِيقَةِ", "Dokument")]),
    (1087, "مِقْدَارُ الْمَالِ كَبِيرٌ.", "Der Geldbetrag ist groß.", [("مِقْدَارُ", "der Betrag"), ("الْمَالِ", "des Geldes"), ("كَبِيرٌ", "ist groß")]),
    (1087, "حَدَّدْنَا الْمِقْدَارَ بِدِقَّةٍ.", "Wir bestimmten die Menge genau.", [("حَدَّدْنَا", "wir bestimmten"), ("الْمِقْدَارَ", "die Menge"), ("بِدِقَّةٍ", "genau")]),
    (1088, "الْعَدَدُ كَبِيرٌ فِي الْأُسْبُوعِ.", "Die Zahl ist groß in der Woche.", [("الْعَدَدُ", "die Zahl"), ("كَبِيرٌ", "ist groß"), ("فِي", "in"), ("الْأُسْبُوعِ", "der Woche")]),
    (1088, "عَدَدُ الطُّلَّابِ يَزِيدُ كُلَّ عَامٍ.", "Die Zahl der Schüler wächst jedes Jahr.", [("عَدَدُ", "die Zahl"), ("الطُّلَّابِ", "der Schüler"), ("يَزِيدُ", "wächst"), ("كُلَّ", "jedes"), ("عَامٍ", "Jahr")]),
    (1088, "أَخْبَرَنَا بِعَدَدِ الْحَاضِرِينَ.", "Er berichtete uns über die Zahl der Anwesenden.", [("أَخْبَرَنَا", "er berichtete uns"), ("بِعَدَدِ", "über die Zahl"), ("الْحَاضِرِينَ", "der Anwesenden")]),
    (1089, "الْمَصْدَرُ مَوْثُوقٌ بِهِ فِي الْخَبَرِ.", "Die Quelle ist in der Nachricht vertrauenswürdig.", [("الْمَصْدَرُ", "die Quelle"), ("مَوْثُوقٌ", "ist vertrauenswürdig"), ("بِهِ", "sie"), ("فِي", "in"), ("الْخَبَرِ", "der Nachricht")]),
    (1089, "مَصْدَرُ الْمَاءِ نَظِيفٌ.", "Die Wasserquelle ist sauber.", [("مَصْدَرُ", "die Quelle"), ("الْمَاءِ", "des Wassers"), ("نَظِيفٌ", "ist sauber")]),
    (1089, "ذَكَرْنَا الْمَصْدَرَ فِي الْبَحْثِ.", "Wir nannten die Quelle in der Forschung.", [("ذَكَرْنَا", "wir nannten"), ("الْمَصْدَرَ", "die Quelle"), ("فِي", "in"), ("الْبَحْثِ", "der Forschung")]),
    (1090, "الْقِيمَةُ مُهِمَّةٌ فِي الْحَيَاةِ.", "Der Wert ist wichtig im Leben.", [("الْقِيمَةُ", "der Wert"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "im"), ("الْحَيَاةِ", "Leben")]),
    (1090, "قِيمَةُ الْكِتَابِ غَالِيَةٌ.", "Der Wert des Buches ist hoch.", [("قِيمَةُ", "der Wert"), ("الْكِتَابِ", "des Buches"), ("غَالِيَةٌ", "ist hoch")]),
    (1091, "السَّقْفُ عَالٍ فِي الْقَاعَةِ.", "Die Decke ist hoch im Saal.", [("السَّقْفُ", "die Decke"), ("عَالٍ", "ist hoch"), ("فِي", "im"), ("الْقَاعَةِ", "Saal")]),
    (1091, "سَقْفُ الْبَيْتِ مُحْكَمٌ.", "Das Hausdach ist fest.", [("سَقْفُ", "das Dach"), ("الْبَيْتِ", "des Hauses"), ("مُحْكَمٌ", "ist fest")]),
    (1091, "طَلَيْنَا السَّقْفَ بِاللَّوْنِ الْأَبْيَضِ.", "Wir strichen die Decke weiß.", [("طَلَيْنَا", "wir strichen"), ("السَّقْفَ", "die Decke"), ("بِاللَّوْنِ", "mit der Farbe"), ("الْأَبْيَضِ", "weißen")]),
    (1092, "الطَّابَقُ الْأَوَّلُ خَاصٌّ بِالْمُوَظَّفِينَ.", "Das erste Stockwerk ist für die Angestellten.", [("الطَّابَقُ", "das Stockwerk"), ("الْأَوَّلُ", "erste"), ("خَاصٌّ", "ist besonders"), ("بِالْمُوَظَّفِينَ", "für die Angestellten")]),
    (1092, "طَابَقُ السُّكْنَى فِي الْعُلُوِّ.", "Das Wohngeschoss ist oben.", [("طَابَقُ", "das Stockwerk"), ("السُّكْنَى", "des Wohnens"), ("فِي", "im"), ("الْعُلُوِّ", "Obergeschoss")]),
    (1092, "نَزَلْنَا إِلَى الطَّابَقِ السُّفْلِيِّ.", "Wir gingen ins untere Stockwerk hinab.", [("نَزَلْنَا", "wir stiegen hinab"), ("إِلَى", "ins"), ("الطَّابَقِ", "Stockwerk"), ("السُّفْلِيِّ", "untere")]),
    (1093, "الِاتِّجَاهُ إِلَى الشَّرْقِ.", "Die Richtung ist nach Osten.", [("الِاتِّجَاهُ", "die Richtung"), ("إِلَى", "nach"), ("الشَّرْقِ", "Osten")]),
    (1093, "اِتِّجَاهُ الرِّيحِ شَمَالِيٌّ الْيَوْمَ.", "Die Windrichtung ist heute nördlich.", [("اِتِّجَاهُ", "die Richtung"), ("الرِّيحِ", "des Windes"), ("شَمَالِيٌّ", "ist nördlich"), ("الْيَوْمَ", "heute")]),
    (1093, "تَغَيَّرَ الِاتِّجَاهُ بَعْدَ الْمَعْرِضِ.", "Die Richtung änderte sich nach der Ausstellung.", [("تَغَيَّرَ", "änderte sich"), ("الِاتِّجَاهُ", "die Richtung"), ("بَعْدَ", "nach"), ("الْمَعْرِضِ", "der Ausstellung")]),
    (1094, "الِارْتِفَاعُ يَزِيدُ فِي الْجَبَلِ.", "Die Höhe nimmt im Berg zu.", [("الِارْتِفَاعُ", "die Höhe"), ("يَزِيدُ", "nimmt zu"), ("فِي", "im"), ("الْجَبَلِ", "Berg")]),
    (1094, "اِرْتِفَاعُ الْبِنَاءِ كَبِيرٌ.", "Die Höhe des Gebäudes ist groß.", [("اِرْتِفَاعُ", "die Höhe"), ("الْبِنَاءِ", "des Gebäudes"), ("كَبِيرٌ", "ist groß")]),
    (1094, "قِسْنَا الِارْتِفَاعَ بالْمِتْرِ.", "Wir maßen die Höhe in Metern.", [("قِسْنَا", "wir maßen"), ("الِارْتِفَاعَ", "die Höhe"), ("بالْمِتْرِ", "in Metern")]),
    (1095, "الْأُفُقُ وَاسِعٌ مِنَ الْجَبَلِ.", "Der Horizont ist weit vom Berg.", [("الْأُفُقُ", "der Horizont"), ("وَاسِعٌ", "ist weit"), ("مِنَ", "vom"), ("الْجَبَلِ", "Berg")]),
    (1095, "أُفُقُ السَّفِينَةِ مُمْتَدٌّ فِي الْبَحْرِ.", "Der Horizont des Schiffes erstreckt sich im Meer.", [("أُفُقُ", "der Horizont"), ("السَّفِينَةِ", "des Schiffes"), ("مُمْتَدٌّ", "erstreckt sich"), ("فِي", "im"), ("الْبَحْرِ", "Meer")]),
    (1095, "رَأَيْنَا الْأُفُقَ مِنَ النَّافِذَةِ.", "Wir sahen den Horizont vom Fenster.", [("رَأَيْنَا", "wir sahen"), ("الْأُفُقَ", "den Horizont"), ("مِنَ", "vom"), ("النَّافِذَةِ", "Fenster")]),
    (1096, "الْفَضَاءُ وَاسِعٌ بِلاَ حَدُودٍ.", "Der Weltraum ist weit ohne Grenzen.", [("الْفَضَاءُ", "der Weltraum"), ("وَاسِعٌ", "ist weit"), ("بِلاَ", "ohne"), ("حَدُودٍ", "Grenzen")]),
    (1096, "فَضَاءُ الْغُرْفَةِ وَاسِعٌ.", "Der Raum des Zimmers ist weit.", [("فَضَاءُ", "der Raum"), ("الْغُرْفَةِ", "des Zimmers"), ("وَاسِعٌ", "ist weit")]),
    (1097, "الْمَعِدَةُ تَقْبَلُ الطَّعَامَ بِهُدُوءٍ.", "Der Magen nimmt das Essen ruhig auf.", [("الْمَعِدَةُ", "der Magen"), ("تَقْبَلُ", "nimmt auf"), ("الطَّعَامَ", "das Essen"), ("بِهُدُوءٍ", "ruhig")]),
    (1097, "مَعِدَةُ الرَّجُلِ قَوِيَّةٌ.", "Der Magen des Mannes ist stark.", [("مَعِدَةُ", "der Magen"), ("الرَّجُلِ", "des Mannes"), ("قَوِيَّةٌ", "ist stark")]),
    (1097, "أَذَتِ الْمَعِدَةُ الرَّجُلَ فِي اللَّيْلِ.", "Der Magen schmerzte den Mann in der Nacht.", [("أَذَتِ", "schmerzte"), ("الْمَعِدَةُ", "der Magen"), ("الرَّجُلَ", "den Mann"), ("فِي", "in"), ("اللَّيْلِ", "der Nacht")]),
    (1098, "الْقُوَّةُ تُسَاعِدُ عَلَى الْعَمَلِ.", "Die Kraft hilft bei der Arbeit.", [("الْقُوَّةُ", "die Kraft"), ("تُسَاعِدُ", "hilft"), ("عَلَى", "bei"), ("الْعَمَلِ", "der Arbeit")]),
    (1098, "قُوَّةُ الْجَيْشِ كَبِيرَةٌ.", "Die Stärke der Armee ist groß.", [("قُوَّةُ", "die Stärke"), ("الْجَيْشِ", "der Armee"), ("كَبِيرَةٌ", "ist groß")]),
    (1098, "اِكْتَسَبْنَا الْقُوَّةَ مِنَ الرِّيَاضَةِ.", "Wir gewannen die Kraft durch den Sport.", [("اِكْتَسَبْنَا", "wir gewannen"), ("الْقُوَّةَ", "die Kraft"), ("مِنَ", "durch"), ("الرِّيَاضَةِ", "den Sport")]),
    (1099, "الْأَلَمُ شَدِيدٌ فِي الْيَدِ.", "Der Schmerz ist stark in der Hand.", [("الْأَلَمُ", "der Schmerz"), ("شَدِيدٌ", "ist stark"), ("فِي", "in"), ("الْيَدِ", "der Hand")]),
    (1099, "أَلَمُ الرَّأْسِ يَمْنَعُ النَّوْمَ.", "Kopfschmerz verhindert den Schlaf.", [("أَلَمُ", "der Schmerz"), ("الرَّأْسِ", "des Kopfes"), ("يَمْنَعُ", "verhindert"), ("النَّوْمَ", "den Schlaf")]),
    (1099, "شَعَرَ الرَّجُلُ بِالْأَلَمِ فِي الْجَنْبِ.", "Der Mann spürte den Schmerz in der Seite.", [("شَعَرَ", "spürte"), ("الرَّجُلُ", "der Mann"), ("بِالْأَلَمِ", "den Schmerz"), ("فِي", "in"), ("الْجَنْبِ", "der Seite")]),
    (1100, "النَّوْمُ مُهِمٌّ لِلصِّحَّةِ.", "Der Schlaf ist wichtig für die Gesundheit.", [("النَّوْمُ", "der Schlaf"), ("مُهِمٌّ", "ist wichtig"), ("لِلصِّحَّةِ", "für die Gesundheit")]),
    (1100, "نَوْمُ الطِّفْلِ عَمِيقٌ فِي اللَّيْلِ.", "Der Schlaf des Kindes ist tief in der Nacht.", [("نَوْمُ", "der Schlaf"), ("الطِّفْلِ", "des Kindes"), ("عَمِيقٌ", "ist tief"), ("فِي", "in"), ("اللَّيْلِ", "der Nacht")]),
    (1100, "اِسْتَرَحْنَا بِالنَّوْمِ الْهَادِئِ.", "Wir erholten uns durch den ruhigen Schlaf.", [("اِسْتَرَحْنَا", "wir erholten uns"), ("بِالنَّوْمِ", "durch den Schlaf"), ("الْهَادِئِ", "ruhigen")]),
    (1101, "الْوِزَارَةُ قَرِيبَةٌ مِنَ السُّوقِ.", "Das Ministerium ist in der Nähe des Marktes.", [("الْوِزَارَةُ", "das Ministerium"), ("قَرِيبَةٌ", "ist in der Nähe"), ("مِنَ", "von"), ("السُّوقِ", "dem Markt")]),
    (1101, "وِزَارَةُ الْخَارِجِيَّةِ تُدِيرُ السِّيَاسَةَ.", "Das Außenministerium leitet die Politik.", [("وِزَارَةُ", "das Ministerium"), ("الْخَارِجِيَّةِ", "des Äußeren"), ("تُدِيرُ", "leitet"), ("السِّيَاسَةَ", "die Politik")]),
    (1102, "الشَّأْنُ الْخَاصُّ لِلْمُوَاطِنِ.", "Die private Angelegenheit gehört dem Bürger.", [("الشَّأْنُ", "die Angelegenheit"), ("الْخَاصُّ", "private"), ("لِلْمُوَاطِنِ", "dem Bürger")]),
    (1102, "شَأْنُ الْبَلَدِ مُهِمٌّ لِلْجَمِيعِ.", "Die Angelegenheit des Landes ist allen wichtig.", [("شَأْنُ", "die Angelegenheit"), ("الْبَلَدِ", "des Landes"), ("مُهِمٌّ", "ist wichtig"), ("لِلْجَمِيعِ", "allen")]),
    (1102, "نَاقَشْنَا الشَّأْنَ فِي الِاجْتِمَاعِ.", "Wir besprachen die Angelegenheit in der Sitzung.", [("نَاقَشْنَا", "wir besprachen"), ("الشَّأْنَ", "die Angelegenheit"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1103, "الصِّفَةُ وَاضِحَةٌ فِي الْكِتَابِ.", "Die Eigenschaft ist klar im Buch.", [("الصِّفَةُ", "die Eigenschaft"), ("وَاضِحَةٌ", "ist klar"), ("فِي", "im"), ("الْكِتَابِ", "Buch")]),
    (1103, "صِفَةُ الْفَرِيقِ قَوِيَّةٌ فِي اللَّعِبِ.", "Die Eigenschaft des Teams ist stark im Spiel.", [("صِفَةُ", "die Eigenschaft"), ("الْفَرِيقِ", "des Teams"), ("قَوِيَّةٌ", "ist stark"), ("فِي", "im"), ("اللَّعِبِ", "Spiel")]),
    (1103, "ذَكَرْنَا الصِّفَةَ فِي الْوَصْفِ.", "Wir nannten die Eigenschaft in der Beschreibung.", [("ذَكَرْنَا", "wir nannten"), ("الصِّفَةَ", "die Eigenschaft"), ("فِي", "in"), ("الْوَصْفِ", "der Beschreibung")]),
    (1104, "الْقَاعَةُ كَبِيرَةٌ فِي الْمَرْكَزِ.", "Der Saal ist groß im Zentrum.", [("الْقَاعَةُ", "der Saal"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "im"), ("الْمَرْكَزِ", "Zentrum")]),
    (1104, "قَاعَةُ الِاجْتِمَاعِ مُضِيئَةٌ.", "Der Sitzungssaal ist hell.", [("قَاعَةُ", "der Saal"), ("الِاجْتِمَاعِ", "der Sitzung"), ("مُضِيئَةٌ", "ist hell")]),
    (1104, "اجْتَمَعْنَا فِي الْقَاعَةِ الْكَبِيرَةِ.", "Wir versammelten uns im großen Saal.", [("اجْتَمَعْنَا", "wir versammelten uns"), ("فِي", "im"), ("الْقَاعَةِ", "Saal"), ("الْكَبِيرَةِ", "großen")]),
    (1105, "الدَّلْوُ مَلِيءٌ بِالْمَاءِ.", "Der Eimer ist voll mit Wasser.", [("الدَّلْوُ", "der Eimer"), ("مَلِيءٌ", "ist voll"), ("بِالْمَاءِ", "mit Wasser")]),
    (1105, "دَلْوُ الْبِئْرِ قَدِيمٌ.", "Der Brunneneimer ist alt.", [("دَلْوُ", "der Eimer"), ("الْبِئْرِ", "des Brunnens"), ("قَدِيمٌ", "ist alt")]),
    (1105, "مَلَأْنَا الدَّلْوَ مِنَ الْبِئْرِ.", "Wir füllten den Eimer aus dem Brunnen.", [("مَلَأْنَا", "wir füllten"), ("الدَّلْوَ", "den Eimer"), ("مِنَ", "aus"), ("الْبِئْرِ", "dem Brunnen")]),
    (1106, "الْمِكْنَسَةُ فِي الزَّاوِيَةِ.", "Der Besen ist in der Ecke.", [("الْمِكْنَسَةُ", "der Besen"), ("فِي", "in"), ("الزَّاوِيَةِ", "der Ecke")]),
    (1106, "مِكْنَسَةُ الطَّرِيقِ جَدِيدَةٌ.", "Der Straßenbesen ist neu.", [("مِكْنَسَةُ", "der Besen"), ("الطَّرِيقِ", "der Straße"), ("جَدِيدَةٌ", "ist neu")]),
    (1107, "الْبَرَدُ كَبِيرٌ فِي الشِّتَاءِ.", "Der Hagel ist groß im Winter.", [("الْبَرَدُ", "der Hagel"), ("كَبِيرٌ", "ist groß"), ("فِي", "im"), ("الشِّتَاءِ", "Winter")]),
    (1107, "بَرَدُ السَّمَاءِ قَوِيٌّ الْيَوْمَ.", "Der Hagel vom Himmel ist heute stark.", [("بَرَدُ", "der Hagel"), ("السَّمَاءِ", "des Himmels"), ("قَوِيٌّ", "ist stark"), ("الْيَوْمَ", "heute")]),
    (1107, "سَقَطَ الْبَرَدُ عَلَى الْأَرْضِ.", "Der Hagel fiel auf die Erde.", [("سَقَطَ", "fiel"), ("الْبَرَدُ", "der Hagel"), ("عَلَى", "auf"), ("الْأَرْضِ", "die Erde")]),
    (1108, "الْفَيَضَانُ خَطِيرٌ فِي الْقَرْيَةِ.", "Die Überschwemmung ist gefährlich im Dorf.", [("الْفَيَضَانُ", "die Überschwemmung"), ("خَطِيرٌ", "ist gefährlich"), ("فِي", "im"), ("الْقَرْيَةِ", "Dorf")]),
    (1108, "فَيَضَانُ النَّهْرِ كَبِيرٌ هَذَا الْعَامَ.", "Die Überschwemmung des Flusses ist groß dieses Jahr.", [("فَيَضَانُ", "die Überschwemmung"), ("النَّهْرِ", "des Flusses"), ("كَبِيرٌ", "ist groß"), ("هَذَا", "dieses"), ("الْعَامَ", "Jahr")]),
    (1108, "اِمْتَدَّ الْفَيَضَانُ إِلَى الْحُقُولِ.", "Die Überschwemmung reichte bis zu den Feldern.", [("اِمْتَدَّ", "reichte"), ("الْفَيَضَانُ", "die Überschwemmung"), ("إِلَى", "bis zu"), ("الْحُقُولِ", "den Feldern")]),
    (1109, "الزِّلْزَالُ قَوِيٌّ فِي الْمَدِينَةِ.", "Das Erdbeben ist stark in der Stadt.", [("الزِّلْزَالُ", "das Erdbeben"), ("قَوِيٌّ", "ist stark"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1109, "زِلْزَالُ الصَّبَاحِ أَخَافَ النَّاسَ.", "Das Erdbeben am Morgen erschreckte die Menschen.", [("زِلْزَالُ", "das Erdbeben"), ("الصَّبَاحِ", "des Morgens"), ("أَخَافَ", "erschreckte"), ("النَّاسَ", "die Menschen")]),
    (1109, "سَجَّلَ الْعُلَمَاءُ الزِّلْزَالَ بِالْأَجْهِزَةِ.", "Die Wissenschaftler zeichneten das Erdbeben mit den Geräten auf.", [("سَجَّلَ", "zeichneten auf"), ("الْعُلَمَاءُ", "die Wissenschaftler"), ("الزِّلْزَالَ", "das Erdbeben"), ("بِالْأَجْهِزَةِ", "mit den Geräten")]),
    (1110, "التَّاجِرُ يَبِيعُ الْبَضَائِعَ فِي السُّوقِ.", "Der Kaufmann verkauft die Waren auf dem Markt.", [("التَّاجِرُ", "der Kaufmann"), ("يَبِيعُ", "verkauft"), ("الْبَضَائِعَ", "die Waren"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1110, "تَاجِرُ الْقَمْحِ غَنِيٌّ.", "Der Weizenkaufmann ist reich.", [("تَاجِرُ", "der Kaufmann"), ("الْقَمْحِ", "des Weizens"), ("غَنِيٌّ", "ist reich")]),
    (1110, "شَرِبَ التَّاجِرُ الْقَهْوَةَ فِي الْمَقْهَى.", "Der Kaufmann trank den Kaffee im Café.", [("شَرِبَ", "trank"), ("التَّاجِرُ", "der Kaufmann"), ("الْقَهْوَةَ", "den Kaffee"), ("فِي", "im"), ("الْمَقْهَى", "Café")]),
    (1111, "الْجَزَّارُ يَقْطَعُ اللَّحْمَ فِي الدُّكَّانِ.", "Der Metzger schneidet das Fleisch im Laden.", [("الْجَزَّارُ", "der Metzger"), ("يَقْطَعُ", "schneidet"), ("اللَّحْمَ", "das Fleisch"), ("فِي", "im"), ("الدُّكَّانِ", "Laden")]),
    (1111, "جَزَّارُ السُّوقِ مَعْرُوفٌ.", "Der Metzger des Marktes ist bekannt.", [("جَزَّارُ", "der Metzger"), ("السُّوقِ", "des Marktes"), ("مَعْرُوفٌ", "ist bekannt")]),
    (1112, "الْجِيرَانُ يَزُورُونَنَا فِي الْعِيدِ.", "Die Nachbarn besuchen uns am Fest.", [("الْجِيرَانُ", "die Nachbarn"), ("يَزُورُونَنَا", "besuchen uns"), ("فِي", "am"), ("الْعِيدِ", "Fest")]),
    (1112, "جِيرَانُ الْبَيْتِ مَرْحَبُونَ.", "Die Hausnachbarn sind freundlich.", [("جِيرَانُ", "die Nachbarn"), ("الْبَيْتِ", "des Hauses"), ("مَرْحَبُونَ", "sind freundlich")]),
    (1112, "نَتَعَاوَنُ مَعَ الْجِيرَانِ فِي الْحَيِّ.", "Wir arbeiten mit den Nachbarn im Viertel zusammen.", [("نَتَعَاوَنُ", "wir arbeiten zusammen"), ("مَعَ", "mit"), ("الْجِيرَانِ", "den Nachbarn"), ("فِي", "im"), ("الْحَيِّ", "Viertel")]),
    (1113, "الرَّفِيقُ وَفِيٌّ فِي الشِّدَّةِ.", "Der Gefährte ist treu in der Not.", [("الرَّفِيقُ", "der Gefährte"), ("وَفِيٌّ", "ist treu"), ("فِي", "in"), ("الشِّدَّةِ", "der Not")]),
    (1113, "رَفِيقُ السَّفَرِ مُمْتِعٌ.", "Der Reisegefährte ist unterhaltsam.", [("رَفِيقُ", "der Gefährte"), ("السَّفَرِ", "der Reise"), ("مُمْتِعٌ", "ist unterhaltsam")]),
    (1113, "عَاشَ الرَّفِيقُ مَعَنَا فِي الْبَيْتِ.", "Der Gefährte lebte mit uns im Haus.", [("عَاشَ", "lebte"), ("الرَّفِيقُ", "der Gefährte"), ("مَعَنَا", "mit uns"), ("فِي", "im"), ("الْبَيْتِ", "Haus")]),
    (1114, "الزَّمِيلُ مَرِيضٌ الْيَوْمَ.", "Der Kollege ist heute krank.", [("الزَّمِيلُ", "der Kollege"), ("مَرِيضٌ", "ist krank"), ("الْيَوْمَ", "heute")]),
    (1114, "زَمِيلُ الْعَمَلِ مُجْتَهِدٌ.", "Der Arbeitskollege ist fleißig.", [("زَمِيلُ", "der Kollege"), ("الْعَمَلِ", "der Arbeit"), ("مُجْتَهِدٌ", "ist fleißig")]),
    (1114, "قَابَلَ الزَّمِيلُ الْمُدِيرَ فِي الصَّبَاحِ.", "Der Kollege traf den Direktor am Morgen.", [("قَابَلَ", "traf"), ("الزَّمِيلُ", "der Kollege"), ("الْمُدِيرَ", "den Direktor"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1115, "الشَّرِيكُ يَعْمَلُ مَعَ الْفَلَّاحِ.", "Der Partner arbeitet mit dem Bauern.", [("الشَّرِيكُ", "der Partner"), ("يَعْمَلُ", "arbeitet"), ("مَعَ", "mit"), ("الْفَلَّاحِ", "dem Bauern")]),
    (1115, "شَرِيكُ الْمَشْرُوعِ نَشِيطٌ.", "Der Projektpartner ist aktiv.", [("شَرِيكُ", "der Partner"), ("الْمَشْرُوعِ", "des Projekts"), ("نَشِيطٌ", "ist aktiv")]),
    (1115, "اِخْتَارَ الرَّجُلُ شَرِيكًا أَمِينًا.", "Der Mann wählte einen treuen Partner.", [("اِخْتَارَ", "wählte"), ("الرَّجُلُ", "der Mann"), ("شَرِيكًا", "einen Partner"), ("أَمِينًا", "treuen")]),
    (1116, "السَّائِحُ يَتَجَوَّلُ فِي الْمَدِينَةِ.", "Der Tourist bummelt durch die Stadt.", [("السَّائِحُ", "der Tourist"), ("يَتَجَوَّلُ", "bummelt"), ("فِي", "durch"), ("الْمَدِينَةِ", "die Stadt")]),
    (1116, "سَائِحُ الْيَابَانِ وُصَلَ فِي الصَّيْفِ.", "Der Tourist aus Japan kam im Sommer an.", [("سَائِحُ", "der Tourist"), ("الْيَابَانِ", "aus Japan"), ("وُصَلَ", "kam an"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1117, "الْمُسَافِرُ يَنْتَظِرُ الْقِطَارَ فِي الْمَحَطَّةِ.", "Der Reisende wartet am Bahnhof auf den Zug.", [("الْمُسَافِرُ", "der Reisende"), ("يَنْتَظِرُ", "wartet"), ("الْقِطَارَ", "auf den Zug"), ("فِي", "am"), ("الْمَحَطَّةِ", "Bahnhof")]),
    (1117, "مُسَافِرُ الصَّبَاحِ قَدِمَ مُبَكِّرًا.", "Der Morgenreisende kam früh an.", [("مُسَافِرُ", "der Reisende"), ("الصَّبَاحِ", "des Morgens"), ("قَدِمَ", "kam an"), ("مُبَكِّرًا", "früh")]),
    (1117, "سَاعَدْنَا الْمُسَافِرَ فِي حَمْلِ الْحَقِيبَةِ.", "Wir halfen dem Reisenden beim Tragen der Tasche.", [("سَاعَدْنَا", "wir halfen"), ("الْمُسَافِرَ", "dem Reisenden"), ("فِي", "beim"), ("حَمْلِ", "Tragen"), ("الْحَقِيبَةِ", "der Tasche")]),
    (1118, "الْجَوَازُ ضَرُورِيٌّ لِلسَّفَرِ.", "Der Reisepass ist für die Reise notwendig.", [("الْجَوَازُ", "der Reisepass"), ("ضَرُورِيٌّ", "ist notwendig"), ("لِلسَّفَرِ", "für die Reise")]),
    (1118, "جَوَازُ السَّفَرِ جَدِيدٌ.", "Der Reisepass ist neu.", [("جَوَازُ", "der Pass"), ("السَّفَرِ", "der Reise"), ("جَدِيدٌ", "ist neu")]),
    (1118, "أَرَيْنَا الْجَوَازَ لِلْمُوَظَّفِ.", "Wir zeigten dem Beamten den Pass.", [("أَرَيْنَا", "wir zeigten"), ("الْجَوَازَ", "den Pass"), ("لِلْمُوَظَّفِ", "dem Beamten")]),
    (1119, "الْمِينَاءُ مَشْغُولٌ بِالسُّفُنِ.", "Der Hafen ist voll mit Schiffen.", [("الْمِينَاءُ", "der Hafen"), ("مَشْغُولٌ", "ist beschäftigt"), ("بِالسُّفُنِ", "mit Schiffen")]),
    (1119, "مِينَاءُ الْبَاخِرَةِ كَبِيرٌ.", "Der Hafen des Schiffes ist groß.", [("مِينَاءُ", "der Hafen"), ("الْبَاخِرَةِ", "des Schiffs"), ("كَبِيرٌ", "ist groß")]),
    (1119, "رَسَتِ السَّفِينَةُ فِي الْمِينَاءِ.", "Das Schiff legte im Hafen an.", [("رَسَتِ", "legte an"), ("السَّفِينَةُ", "das Schiff"), ("فِي", "im"), ("الْمِينَاءِ", "Hafen")]),
    (1120, "النِّصْفُ الْأَوَّلُ مِنَ الْكِتَابِ جَيِّدٌ.", "Die erste Hälfte des Buches ist gut.", [("النِّصْفُ", "die Hälfte"), ("الْأَوَّلُ", "erste"), ("مِنَ", "von"), ("الْكِتَابِ", "dem Buch"), ("جَيِّدٌ", "ist gut")]),
    (1120, "نِصْفُ الطَّلَبِ قَدِمَ فِي الصَّبَاحِ.", "Die Hälfte der Bestellung kam am Morgen.", [("نِصْفُ", "die Hälfte"), ("الطَّلَبِ", "der Bestellung"), ("قَدِمَ", "kam"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1120, "أَكَلْنَا النِّصْفَ مِنَ الْفَاكِهَةِ.", "Wir aßen die Hälfte der Früchte.", [("أَكَلْنَا", "wir aßen"), ("النِّصْفَ", "die Hälfte"), ("مِنَ", "der"), ("الْفَاكِهَةِ", "Früchte")]),
    (1121, "الثُّلُثُ الْأَخِيرُ صَعْبٌ فِي الدَّرْسِ.", "Das letzte Drittel ist schwer in der Lektion.", [("الثُّلُثُ", "das Drittel"), ("الْأَخِيرُ", "letzte"), ("صَعْبٌ", "ist schwer"), ("فِي", "in"), ("الدَّرْسِ", "der Lektion")]),
    (1121, "ثُلُثُ الْفَصْلِ مَضَى بِسُرْعَةٍ.", "Ein Drittel des Semesters verging schnell.", [("ثُلُثُ", "ein Drittel"), ("الْفَصْلِ", "des Semesters"), ("مَضَى", "verging"), ("بِسُرْعَةٍ", "schnell")]),
    (1122, "الْكِتَابُ مُفِيدٌ لِلطُّلَّابِ.", "Das Buch ist den Schülern nützlich.", [("الْكِتَابُ", "das Buch"), ("مُفِيدٌ", "ist nützlich"), ("لِلطُّلَّابِ", "den Schülern")]),
    (1122, "كَانَ الدَّرْسُ مُفِيدًا جِدًّا.", "Die Lektion war sehr nützlich.", [("كَانَ", "war"), ("الدَّرْسُ", "die Lektion"), ("مُفِيدًا", "nützlich"), ("جِدًّا", "sehr")]),
    (1122, "هَذَا الْمَشْرُوعُ مُفِيدٌ لِلْجَمِيعِ.", "Dieses Projekt ist für alle nützlich.", [("هَذَا", "dieses"), ("الْمَشْرُوعُ", "Projekt"), ("مُفِيدٌ", "ist nützlich"), ("لِلْجَمِيعِ", "für alle")]),
    (1123, "الْمَاءُ ضَرُورِيٌّ لِلْحَيَاةِ.", "Wasser ist für das Leben notwendig.", [("الْمَاءُ", "Wasser"), ("ضَرُورِيٌّ", "ist notwendig"), ("لِلْحَيَاةِ", "für das Leben")]),
    (1123, "كَانَ الْجَوَازُ ضَرُورِيًّا لِلسَّفَرِ.", "Der Pass war für die Reise notwendig.", [("كَانَ", "war"), ("الْجَوَازُ", "der Pass"), ("ضَرُورِيًّا", "notwendig"), ("لِلسَّفَرِ", "für die Reise")]),
    (1123, "هَذَا الْعَمَلُ ضَرُورِيٌّ لِلنَّجَاحِ.", "Diese Arbeit ist für den Erfolg notwendig.", [("هَذَا", "diese"), ("الْعَمَلُ", "Arbeit"), ("ضَرُورِيٌّ", "ist notwendig"), ("لِلنَّجَاحِ", "für den Erfolg")]),
    (1124, "الْوَقْتُ مُنَاسِبٌ لِلِاجْتِمَاعِ.", "Die Zeit ist für die Sitzung geeignet.", [("الْوَقْتُ", "die Zeit"), ("مُنَاسِبٌ", "ist geeignet"), ("لِلِاجْتِمَاعِ", "für die Sitzung")]),
    (1124, "كَانَ الثَّوْبُ مُنَاسِبًا لِلطَّقْسِ.", "Die Kleidung war dem Wetter angemessen.", [("كَانَ", "war"), ("الثَّوْبُ", "die Kleidung"), ("مُنَاسِبًا", "angemessen"), ("لِلطَّقْسِ", "dem Wetter")]),
    (1124, "هَذَا الْمَوْضُوعُ مُنَاسِبٌ لِلدَّرْسِ.", "Dieses Thema ist für die Lektion passend.", [("هَذَا", "dieses"), ("الْمَوْضُوعُ", "Thema"), ("مُنَاسِبٌ", "ist passend"), ("لِلدَّرْسِ", "für die Lektion")]),
    (1125, "الْبَيْتُ حَدِيثٌ فِي الْحَيِّ.", "Das Haus ist modern im Viertel.", [("الْبَيْتُ", "das Haus"), ("حَدِيثٌ", "ist modern"), ("فِي", "im"), ("الْحَيِّ", "Viertel")]),
    (1125, "كَانَ الْهَاتِفُ حَدِيثًا وَسَرِيعًا.", "Das Telefon war modern und schnell.", [("كَانَ", "war"), ("الْهَاتِفُ", "das Telefon"), ("حَدِيثًا", "modern"), ("وَسَرِيعًا", "und schnell")]),
    (1125, "هَذَا الْمَرْكَزُ التِّجَارِيُّ حَدِيثٌ.", "Dieses Einkaufszentrum ist modern.", [("هَذَا", "dieses"), ("الْمَرْكَزُ", "Zentrum"), ("التِّجَارِيُّ", "Einkaufs-"), ("حَدِيثٌ", "ist modern")]),
    (1126, "الْقِصَّةُ مُمْتِعَةٌ لِلْأَطْفَالِ.", "Die Geschichte ist für die Kinder unterhaltsam.", [("الْقِصَّةُ", "die Geschichte"), ("مُمْتِعَةٌ", "ist unterhaltsam"), ("لِلْأَطْفَالِ", "für die Kinder")]),
    (1126, "كَانَ الْفِلْمُ مُمْتِعًا جِدًّا.", "Der Film war sehr unterhaltsam.", [("كَانَ", "war"), ("الْفِلْمُ", "der Film"), ("مُمْتِعًا", "unterhaltsam"), ("جِدًّا", "sehr")]),
    (1127, "الْمَنْظَرُ رَائِعٌ مِنَ الْجَبَلِ.", "Die Aussicht ist vom Berg wunderbar.", [("الْمَنْظَرُ", "die Aussicht"), ("رَائِعٌ", "ist wunderbar"), ("مِنَ", "vom"), ("الْجَبَلِ", "Berg")]),
    (1127, "كَانَ الْعَمَلُ رَائِعًا فِي الْمَعْرِضِ.", "Die Arbeit war in der Ausstellung großartig.", [("كَانَ", "war"), ("الْعَمَلُ", "die Arbeit"), ("رَائِعًا", "großartig"), ("فِي", "in"), ("الْمَعْرِضِ", "der Ausstellung")]),
    (1127, "هَذَا الْيَوْمُ رَائِعٌ فِي الرِّحْلَةِ.", "Dieser Tag ist wunderbar auf der Reise.", [("هَذَا", "dieser"), ("الْيَوْمُ", "Tag"), ("رَائِعٌ", "ist wunderbar"), ("فِي", "auf"), ("الرِّحْلَةِ", "der Reise")]),
    (1128, "الرَّجُلُ قَادِرٌ عَلَى الْعَمَلِ.", "Der Mann ist zur Arbeit fähig.", [("الرَّجُلُ", "der Mann"), ("قَادِرٌ", "ist fähig"), ("عَلَى", "zu"), ("الْعَمَلِ", "der Arbeit")]),
    (1128, "كَانَ الطَّبِيبُ قَادِرًا عَلَى الْمُعَالَجَةِ.", "Der Arzt war zur Behandlung fähig.", [("كَانَ", "war"), ("الطَّبِيبُ", "der Arzt"), ("قَادِرًا", "fähig"), ("عَلَى", "zu"), ("الْمُعَالَجَةِ", "der Behandlung")]),
    (1128, "هَذَا الْمُوَظَّفُ قَادِرٌ عَلَى التَّحْمِيلِ.", "Dieser Angestellte ist fähig, Verantwortung zu tragen.", [("هَذَا", "dieser"), ("الْمُوَظَّفُ", "Angestellte"), ("قَادِرٌ", "ist fähig"), ("عَلَى", "zu"), ("التَّحْمِيلِ", "tragen")]),
    (1129, "الْجَوَابُ خَاطِئٌ فِي الِامْتِحَانِ.", "Die Antwort ist in der Prüfung falsch.", [("الْجَوَابُ", "die Antwort"), ("خَاطِئٌ", "ist falsch"), ("فِي", "in"), ("الِامْتِحَانِ", "der Prüfung")]),
    (1129, "كَانَ الرَّأْيُ خَاطِئًا فِي الْبِدَايَةِ.", "Die Meinung war am Anfang falsch.", [("كَانَ", "war"), ("الرَّأْيُ", "die Meinung"), ("خَاطِئًا", "falsch"), ("فِي", "am"), ("الْبِدَايَةِ", "Anfang")]),
    (1129, "هَذَا الطَّرِيقُ خَاطِئٌ لِلسَّفَرِ.", "Dieser Weg ist für die Reise falsch.", [("هَذَا", "dieser"), ("الطَّرِيقُ", "Weg"), ("خَاطِئٌ", "ist falsch"), ("لِلسَّفَرِ", "für die Reise")]),
    (1130, "الْبِنَاءُ مُرْتَفِعٌ فِي الْمَدِينَةِ.", "Das Gebäude ist hoch in der Stadt.", [("الْبِنَاءُ", "das Gebäude"), ("مُرْتَفِعٌ", "ist hoch"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1130, "كَانَتِ السَّعْرُ مُرْتَفِعًا هَذَا الشَّهْرَ.", "Der Preis war diesen Monat hoch.", [("كَانَتِ", "war"), ("السَّعْرُ", "der Preis"), ("مُرْتَفِعًا", "hoch"), ("هَذَا", "diesen"), ("الشَّهْرَ", "Monat")]),
    (1130, "هَذَا الْمَوْضِعُ مُرْتَفِعٌ عَنِ الْأَرْضِ.", "Diese Stelle ist über dem Boden erhöht.", [("هَذَا", "diese"), ("الْمَوْضِعُ", "Stelle"), ("مُرْتَفِعٌ", "ist erhöht"), ("عَنِ", "über"), ("الْأَرْضِ", "dem Boden")]),
    (1131, "الْوَقْتُ كَافٍ لِلْعَمَلِ.", "Die Zeit ist für die Arbeit ausreichend.", [("الْوَقْتُ", "die Zeit"), ("كَافٍ", "ist ausreichend"), ("لِلْعَمَلِ", "für die Arbeit")]),
    (1131, "كَانَ الطَّعَامُ كَافِيًا لِلْجَمِيعِ.", "Das Essen war für alle ausreichend.", [("كَانَ", "war"), ("الطَّعَامُ", "das Essen"), ("كَافِيًا", "ausreichend"), ("لِلْجَمِيعِ", "für alle")]),
    (1132, "الْجَوَابُ نَاقِصٌ فِي الْوَرَقَةِ.", "Die Antwort ist auf dem Blatt unvollständig.", [("الْجَوَابُ", "die Antwort"), ("نَاقِصٌ", "ist unvollständig"), ("فِي", "auf"), ("الْوَرَقَةِ", "dem Blatt")]),
    (1132, "كَانَ الْعَدَدُ نَاقِصًا فِي الْقَائِمَةِ.", "Die Zahl war in der Liste unvollständig.", [("كَانَ", "war"), ("الْعَدَدُ", "die Zahl"), ("نَاقِصًا", "unvollständig"), ("فِي", "in"), ("الْقَائِمَةِ", "der Liste")]),
    (1132, "هَذَا الْكِتَابُ نَاقِصٌ فِي الْمَكْتَبَةِ.", "Dieses Buch ist in der Bibliothek unvollständig.", [("هَذَا", "dieses"), ("الْكِتَابُ", "Buch"), ("نَاقِصٌ", "ist unvollständig"), ("فِي", "in"), ("الْمَكْتَبَةِ", "der Bibliothek")]),
    (1133, "الْقِطَارُ مُتَأَخِّرٌ فِي الْمَحَطَّةِ.", "Der Zug ist am Bahnhof verspätet.", [("الْقِطَارُ", "der Zug"), ("مُتَأَخِّرٌ", "ist verspätet"), ("فِي", "am"), ("الْمَحَطَّةِ", "Bahnhof")]),
    (1133, "كَانَ الطَّالِبُ مُتَأَخِّرًا عَنِ الدَّرْسِ.", "Der Student war zur Lektion zu spät gekommen.", [("كَانَ", "war"), ("الطَّالِبُ", "der Student"), ("مُتَأَخِّرًا", "verspätet"), ("عَنِ", "zur"), ("الدَّرْسِ", "Lektion")]),
    (1133, "هَذَا الْخَبَرُ مُتَأَخِّرٌ فِي الصَّحِيفَةِ.", "Diese Nachricht ist in der Zeitung verspätet.", [("هَذَا", "diese"), ("الْخَبَرُ", "Nachricht"), ("مُتَأَخِّرٌ", "ist verspätet"), ("فِي", "in"), ("الصَّحِيفَةِ", "der Zeitung")]),
    (1134, "الْأَمْرُ غَامِضٌ لِلْجَمِيعِ.", "Die Sache ist für alle unklar.", [("الْأَمْرُ", "die Sache"), ("غَامِضٌ", "ist unklar"), ("لِلْجَمِيعِ", "für alle")]),
    (1134, "كَانَ الْكَلَامُ غَامِضًا فِي الْخُطْبَةِ.", "Die Rede war in der Ansprache unklar.", [("كَانَ", "war"), ("الْكَلَامُ", "die Rede"), ("غَامِضًا", "unklar"), ("فِي", "in"), ("الْخُطْبَةِ", "der Ansprache")]),
    (1134, "هَذَا الْمَوْضُوعُ غَامِضٌ فِي الْكِتَابِ.", "Dieses Thema ist im Buch geheimnisvoll.", [("هَذَا", "dieses"), ("الْمَوْضُوعُ", "Thema"), ("غَامِضٌ", "ist geheimnisvoll"), ("فِي", "im"), ("الْكِتَابِ", "Buch")]),
    (1135, "الرَّجُلُ وَحِيدٌ فِي الْبَيْتِ.", "Der Mann ist allein im Haus.", [("الرَّجُلُ", "der Mann"), ("وَحِيدٌ", "ist allein"), ("فِي", "im"), ("الْبَيْتِ", "Haus")]),
    (1135, "كَانَ الطِّفْلُ وَحِيدًا فِي الْحَدِيقَةِ.", "Das Kind war allein im Garten.", [("كَانَ", "war"), ("الطِّفْلُ", "das Kind"), ("وَحِيدًا", "allein"), ("فِي", "im"), ("الْحَدِيقَةِ", "Garten")]),
    (1135, "هَذَا الْمَقْعَدُ وَحِيدٌ فِي الصَّفِّ.", "Dieser Sitz ist der einzige in der Reihe.", [("هَذَا", "dieser"), ("الْمَقْعَدُ", "Sitz"), ("وَحِيدٌ", "ist der einzige"), ("فِي", "in"), ("الصَّفِّ", "der Reihe")]),
    (1136, "الْوَقْتُ مُحَدَّدٌ لِلِاجْتِمَاعِ.", "Die Zeit ist für die Sitzung festgelegt.", [("الْوَقْتُ", "die Zeit"), ("مُحَدَّدٌ", "ist festgelegt"), ("لِلِاجْتِمَاعِ", "für die Sitzung")]),
    (1136, "كَانَ الْمَوْضُوعُ مُحَدَّدًا فِي الْبَرْنَامَجِ.", "Das Thema war im Programm bestimmt.", [("كَانَ", "war"), ("الْمَوْضُوعُ", "das Thema"), ("مُحَدَّدًا", "bestimmt"), ("فِي", "im"), ("الْبَرْنَامَجِ", "Programm")]),
    (1137, "الْقَوْلُ عُمُومِيٌّ فِي الْخِطَابِ.", "Die Aussage ist allgemein in der Rede.", [("الْقَوْلُ", "die Aussage"), ("عُمُومِيٌّ", "ist allgemein"), ("فِي", "in"), ("الْخِطَابِ", "der Rede")]),
    (1137, "كَانَ الرَّأْيُ عُمُومِيًّا فِي النَّقْشِ.", "Die Meinung war in der Diskussion allgemein.", [("كَانَ", "war"), ("الرَّأْيُ", "die Meinung"), ("عُمُومِيًّا", "allgemein"), ("فِي", "in"), ("النَّقْشِ", "der Diskussion")]),
    (1137, "هَذَا الْأَمْرُ عُمُومِيٌّ لِجَمِيعِ النَّاسِ.", "Diese Sache ist für alle Menschen allgemein.", [("هَذَا", "diese"), ("الْأَمْرُ", "Sache"), ("عُمُومِيٌّ", "ist allgemein"), ("لِجَمِيعِ", "für alle"), ("النَّاسِ", "Menschen")]),
    (1138, "الْجِدَارُ خَارِجِيٌّ فِي الْبِنَاءِ.", "Die Wand ist außen am Gebäude.", [("الْجِدَارُ", "die Wand"), ("خَارِجِيٌّ", "ist außen"), ("فِي", "am"), ("الْبِنَاءِ", "Gebäude")]),
    (1138, "كَانَ الطَّالِبُ خَارِجِيًّا فِي الْمَدْرَسَةِ.", "Der Schüler war auswärtig in der Schule.", [("كَانَ", "war"), ("الطَّالِبُ", "der Schüler"), ("خَارِجِيًّا", "auswärtig"), ("فِي", "in"), ("الْمَدْرَسَةِ", "der Schule")]),
    (1138, "هَذَا الْأَمْرُ خَارِجِيٌّ عَنِ الْبِلَادِ.", "Diese Angelegenheit betrifft das Ausland.", [("هَذَا", "diese"), ("الْأَمْرُ", "Angelegenheit"), ("خَارِجِيٌّ", "betrifft das Ausland"), ("عَنِ", "außerhalb"), ("الْبِلَادِ", "des Landes")]),
    (1139, "الْخَبَرُ رَسْمِيٌّ مِنَ الْحُكُومَةِ.", "Die Nachricht ist offiziell von der Regierung.", [("الْخَبَرُ", "die Nachricht"), ("رَسْمِيٌّ", "ist offiziell"), ("مِنَ", "von"), ("الْحُكُومَةِ", "der Regierung")]),
    (1139, "كَانَ الْقَرَارُ رَسْمِيًّا فِي الِاجْتِمَاعِ.", "Die Entscheidung war in der Sitzung offiziell.", [("كَانَ", "war"), ("الْقَرَارُ", "die Entscheidung"), ("رَسْمِيًّا", "offiziell"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1139, "هَذَا الْكِتَابُ رَسْمِيٌّ فِي الْمَدْرَسَةِ.", "Dieses Buch ist offiziell in der Schule.", [("هَذَا", "dieses"), ("الْكِتَابُ", "Buch"), ("رَسْمِيٌّ", "ist offiziell"), ("فِي", "in"), ("الْمَدْرَسَةِ", "der Schule")]),
    (1140, "الطَّالِبُ كَسْلَانُ فِي الدَّرْسِ.", "Der Schüler ist in der Lektion faul.", [("الطَّالِبُ", "der Schüler"), ("كَسْلَانُ", "ist faul"), ("فِي", "in"), ("الدَّرْسِ", "der Lektion")]),
    (1140, "كَانَ الْعَامِلُ كَسْلَانًا هَذِهِ الْأَيَّامَ.", "Der Arbeiter war in diesen Tagen träge.", [("كَانَ", "war"), ("الْعَامِلُ", "der Arbeiter"), ("كَسْلَانًا", "träge"), ("هَذِهِ", "diesen"), ("الْأَيَّامَ", "Tagen")]),
    (1140, "هَذَا الْوَلَدُ كَسْلَانُ فِي الْبَيْتِ.", "Dieser Junge ist im Haus faul.", [("هَذَا", "dieser"), ("الْوَلَدُ", "Junge"), ("كَسْلَانُ", "ist faul"), ("فِي", "im"), ("الْبَيْتِ", "Haus")]),
    (1141, "الْكِتَابُ ثَمِينٌ فِي الْمَكْتَبَةِ.", "Das Buch ist in der Bibliothek wertvoll.", [("الْكِتَابُ", "das Buch"), ("ثَمِينٌ", "ist wertvoll"), ("فِي", "in"), ("الْمَكْتَبَةِ", "der Bibliothek")]),
    (1141, "كَانَ الْوَقْتُ ثَمِينًا فِي السَّفَرِ.", "Die Zeit war auf der Reise kostbar.", [("كَانَ", "war"), ("الْوَقْتُ", "die Zeit"), ("ثَمِينًا", "kostbar"), ("فِي", "auf"), ("السَّفَرِ", "der Reise")]),
    (1142, "الْأَمْرُ مُسْتَحِيلٌ فِي الْعَمَلِ.", "Die Sache ist bei der Arbeit unmöglich.", [("الْأَمْرُ", "die Sache"), ("مُسْتَحِيلٌ", "ist unmöglich"), ("فِي", "bei"), ("الْعَمَلِ", "der Arbeit")]),
    (1142, "كَانَ السَّفَرُ مُسْتَحِيلًا فِي الْعَاصِفَةِ.", "Die Reise war im Sturm unmöglich.", [("كَانَ", "war"), ("السَّفَرُ", "die Reise"), ("مُسْتَحِيلًا", "unmöglich"), ("فِي", "im"), ("الْعَاصِفَةِ", "Sturm")]),
    (1142, "هَذَا الْحَلُّ مُسْتَحِيلٌ فِي الْبِدَايَةِ.", "Diese Lösung ist am Anfang unmöglich.", [("هَذَا", "diese"), ("الْحَلُّ", "Lösung"), ("مُسْتَحِيلٌ", "ist unmöglich"), ("فِي", "am"), ("الْبِدَايَةِ", "Anfang")]),
    (1143, "الْقَرَارُ نِهَائِيٌّ فِي الِاجْتِمَاعِ.", "Die Entscheidung ist in der Sitzung endgültig.", [("الْقَرَارُ", "die Entscheidung"), ("نِهَائِيٌّ", "ist endgültig"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1143, "كَانَ الْجَوَابُ نِهَائِيًّا فِي الْخِطَابِ.", "Die Antwort war in der Rede endgültig.", [("كَانَ", "war"), ("الْجَوَابُ", "die Antwort"), ("نِهَائِيًّا", "endgültig"), ("فِي", "in"), ("الْخِطَابِ", "der Rede")]),
    (1143, "هَذَا الْمَوْقِفُ نِهَائِيٌّ فِي الْحَرْبِ.", "Diese Stellung ist im Krieg endgültig.", [("هَذَا", "diese"), ("الْمَوْقِفُ", "Stellung"), ("نِهَائِيٌّ", "ist endgültig"), ("فِي", "im"), ("الْحَرْبِ", "Krieg")]),
    (1144, "الْيَوْمُ آخِرُ أَيَّامِ الْعِيدِ.", "Der Tag ist der letzte der Festtage.", [("الْيَوْمُ", "der Tag"), ("آخِرُ", "ist der letzte"), ("أَيَّامِ", "der Tage"), ("الْعِيدِ", "des Festes")]),
    (1144, "كَانَ الصَّفُّ آخِرَ صَفٍّ فِي الْمَدْرَسَةِ.", "Die Klasse war die letzte in der Schule.", [("كَانَ", "war"), ("الصَّفُّ", "die Klasse"), ("آخِرَ", "die letzte"), ("صَفٍّ", "Klasse"), ("فِي", "in"), ("الْمَدْرَسَةِ", "der Schule")]),
    (1144, "هَذَا هُوَ الْبَيْتُ الْآخِرُ فِي الْحَيِّ.", "Das ist das letzte Haus im Viertel.", [("هَذَا", "das ist"), ("هُوَ", "es"), ("الْبَيْتُ", "Haus"), ("الْآخِرُ", "letzte"), ("فِي", "im"), ("الْحَيِّ", "Viertel")]),
    (1145, "الْيَوْمُ أَوَّلُ أَيَّامِ الرَّبِيعِ.", "Der Tag ist der erste der Frühlingstage.", [("الْيَوْمُ", "der Tag"), ("أَوَّلُ", "ist der erste"), ("أَيَّامِ", "der Tage"), ("الرَّبِيعِ", "des Frühlings")]),
    (1145, "كَانَ الطَّالِبُ أَوَّلَ فَائِزٍ فِي الْمُسَابَقَةِ.", "Der Student war der erste Sieger im Wettbewerb.", [("كَانَ", "war"), ("الطَّالِبُ", "der Student"), ("أَوَّلَ", "der erste"), ("فَائِزٍ", "Sieger"), ("فِي", "im"), ("الْمُسَابَقَةِ", "Wettbewerb")]),
    (1145, "هَذَا هُوَ الدَّرْسُ الْأَوَّلُ فِي الْكِتَابِ.", "Das ist die erste Lektion im Buch.", [("هَذَا", "das ist"), ("هُوَ", "es"), ("الدَّرْسُ", "Lektion"), ("الْأَوَّلُ", "erste"), ("فِي", "im"), ("الْكِتَابِ", "Buch")]),
    (1146, "يَعْمَلُ الرَّجُلُ دَائِمًا فِي الْحَقْلِ.", "Der Mann arbeitet immer auf dem Feld.", [("يَعْمَلُ", "arbeitet"), ("الرَّجُلُ", "der Mann"), ("دَائِمًا", "immer"), ("فِي", "auf"), ("الْحَقْلِ", "dem Feld")]),
    (1146, "كَانَتِ الْمَرْأَةُ دَائِمًا فِي الْمَطْبَخِ.", "Die Frau war immer in der Küche.", [("كَانَتِ", "war"), ("الْمَرْأَةُ", "die Frau"), ("دَائِمًا", "immer"), ("فِي", "in"), ("الْمَطْبَخِ", "der Küche")]),
    (1147, "يَزُورُنَا أَحْيَانًا فِي الْعُطْلَةِ.", "Er besucht uns manchmal im Urlaub.", [("يَزُورُنَا", "er besucht uns"), ("أَحْيَانًا", "manchmal"), ("فِي", "im"), ("الْعُطْلَةِ", "Urlaub")]),
    (1147, "نَتَرَاجَعُ أَحْيَانًا فِي الْعَمَلِ.", "Wir treten manchmal zurück in der Arbeit.", [("نَتَرَاجَعُ", "wir treten zurück"), ("أَحْيَانًا", "manchmal"), ("فِي", "in"), ("الْعَمَلِ", "der Arbeit")]),
    (1147, "كَانَ الرَّجُلُ أَحْيَانًا يَنْسَى الْوَقْتَ.", "Der Mann vergaß manchmal die Zeit.", [("كَانَ", "war"), ("الرَّجُلُ", "der Mann"), ("أَحْيَانًا", "manchmal"), ("يَنْسَى", "vergaß"), ("الْوَقْتَ", "die Zeit")]),
    (1148, "يَمْطُرُ نَادِرًا فِي هَذِهِ الْبَلْدَةِ.", "Es regnet selten in dieser Stadt.", [("يَمْطُرُ", "es regnet"), ("نَادِرًا", "selten"), ("فِي", "in"), ("هَذِهِ", "dieser"), ("الْبَلْدَةِ", "Stadt")]),
    (1148, "نَزُورُ الْجَدَّ نَادِرًا فِي الشِّتَاءِ.", "Wir besuchen den Großvater selten im Winter.", [("نَزُورُ", "wir besuchen"), ("الْجَدَّ", "den Großvater"), ("نَادِرًا", "selten"), ("فِي", "im"), ("الشِّتَاءِ", "Winter")]),
    (1148, "كَانَ يَتَحَدَّثُ نَادِرًا فِي الِاجْتِمَاعِ.", "Er sprach selten in der Sitzung.", [("كَانَ", "pflegte"), ("يَتَحَدَّثُ", "zu sprechen"), ("نَادِرًا", "selten"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1149, "الْبَيْتُ خَلْفَ الْحَدِيقَةِ.", "Das Haus ist hinter dem Garten.", [("الْبَيْتُ", "das Haus"), ("خَلْفَ", "hinter"), ("الْحَدِيقَةِ", "dem Garten")]),
    (1149, "وَقَفَ الرَّجُلُ خَلْفَ الْبَابِ.", "Der Mann stand hinter der Tür.", [("وَقَفَ", "stand"), ("الرَّجُلُ", "der Mann"), ("خَلْفَ", "hinter"), ("الْبَابِ", "der Tür")]),
    (1149, "خَلْفَ الْجَبَلِ قَرْيَةٌ صَغِيرَةٌ.", "Hinter dem Berg ist ein kleines Dorf.", [("خَلْفَ", "hinter"), ("الْجَبَلِ", "dem Berg"), ("قَرْيَةٌ", "ein Dorf"), ("صَغِيرَةٌ", "kleines")]),
    (1150, "وَرَاءَ النَّهْرِ أَشْجَارٌ كَثِيرَةٌ.", "Hinter dem Fluss sind viele Bäume.", [("وَرَاءَ", "hinter"), ("النَّهْرِ", "dem Fluss"), ("أَشْجَارٌ", "Bäume"), ("كَثِيرَةٌ", "viele")]),
    (1150, "وَقَفَ الْوَلَدُ وَرَاءَ أَبِيهِ.", "Der Junge stand hinter seinem Vater.", [("وَقَفَ", "stand"), ("الْوَلَدُ", "der Junge"), ("وَرَاءَ", "hinter"), ("أَبِيهِ", "seinem Vater")]),
    (1151, "اِسْتَفْهَمَ الطَّالِبُ عَنِ الْوَقْتِ.", "Der Student erkundigte sich nach der Zeit.", [("اِسْتَفْهَمَ", "erkundigte sich"), ("الطَّالِبُ", "der Student"), ("عَنِ", "nach"), ("الْوَقْتِ", "der Zeit")]),
    (1151, "اِسْتَفْهَمَ الرَّجُلُ عَنْ أَحْوَالِ الْجِيرَانِ.", "Der Mann fragte nach dem Befinden der Nachbarn.", [("اِسْتَفْهَمَ", "fragte nach"), ("الرَّجُلُ", "der Mann"), ("عَنْ", "nach"), ("أَحْوَالِ", "dem Befinden"), ("الْجِيرَانِ", "der Nachbarn")]),
    (1151, "اِسْتَفْهَمْنَا عَنْ مَوْضِعِ السُّوقِ.", "Wir erkundigten uns nach dem Ort des Marktes.", [("اِسْتَفْهَمْنَا", "wir erkundigten uns"), ("عَنْ", "nach"), ("مَوْضِعِ", "dem Ort"), ("السُّوقِ", "des Marktes")]),
    (1152, "اِسْتَدْعَى الْمُدِيرُ الْمُوَظَّفِينَ إِلَى الِاجْتِمَاعِ.", "Der Direktor berief die Angestellten zur Sitzung ein.", [("اِسْتَدْعَى", "berief ein"), ("الْمُدِيرُ", "der Direktor"), ("الْمُوَظَّفِينَ", "die Angestellten"), ("إِلَى", "zur"), ("الِاجْتِمَاعِ", "Sitzung")]),
    (1152, "اِسْتَدْعَتِ الْمَرْأَةُ الطَّبِيبَ إِلَى الْبَيْتِ.", "Die Frau rief den Arzt zum Haus.", [("اِسْتَدْعَتِ", "rief"), ("الْمَرْأَةُ", "die Frau"), ("الطَّبِيبَ", "den Arzt"), ("إِلَى", "zum"), ("الْبَيْتِ", "Haus")]),
    (1152, "اِسْتَدْعَى الْقَاضِي الشُّهُودَ إِلَى الْمَحْكَمَةِ.", "Der Richter rief die Zeugen zum Gericht.", [("اِسْتَدْعَى", "rief"), ("الْقَاضِي", "der Richter"), ("الشُّهُودَ", "die Zeugen"), ("إِلَى", "zum"), ("الْمَحْكَمَةِ", "Gericht")]),
    (1153, "اِبْتَعَدَ الْوَلَدُ عَنِ النَّارِ.", "Der Junge entfernte sich vom Feuer.", [("اِبْتَعَدَ", "entfernte sich"), ("الْوَلَدُ", "der Junge"), ("عَنِ", "vom"), ("النَّارِ", "Feuer")]),
    (1153, "اِبْتَعَدَتِ السَّفِينَةُ عَنْ الشَّاطِئِ.", "Das Schiff entfernte sich von der Küste.", [("اِبْتَعَدَتِ", "entfernte sich"), ("السَّفِينَةُ", "das Schiff"), ("عَنْ", "von"), ("الشَّاطِئِ", "der Küste")]),
    (1153, "اِبْتَعَدْنَا عَنِ الْمَوْضُوعِ فِي النَّقْشِ.", "Wir entfernten uns in der Diskussion vom Thema.", [("اِبْتَعَدْنَا", "wir entfernten uns"), ("عَنِ", "vom"), ("الْمَوْضُوعِ", "Thema"), ("فِي", "in"), ("النَّقْشِ", "der Diskussion")]),
    (1154, "اِقْتَصَدَ الرَّجُلُ فِي إِنْفَاقِهِ.", "Der Mann war sparsam in seinen Ausgaben.", [("اِقْتَصَدَ", "war sparsam"), ("الرَّجُلُ", "der Mann"), ("فِي", "in"), ("إِنْفَاقِهِ", "seinen Ausgaben")]),
    (1154, "اِقْتَصَدَتِ الْمَرْأَةُ فِي شِرَاءِ الْحَوَائِجِ.", "Die Frau wirtschaftete sparsam beim Kauf der Bedarfsgüter.", [("اِقْتَصَدَتِ", "wirtschaftete sparsam"), ("الْمَرْأَةُ", "die Frau"), ("فِي", "beim"), ("شِرَاءِ", "Kauf"), ("الْحَوَائِجِ", "der Bedarfsgüter")]),
    (1154, "اِقْتَصَدْنَا فِي الْمَاءِ فِي الصَّيْفِ.", "Wir sparten im Sommer mit dem Wasser.", [("اِقْتَصَدْنَا", "wir sparten"), ("فِي", "mit"), ("الْمَاءِ", "dem Wasser"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1155, "اِنْعَقَدَ الِاجْتِمَاعُ فِي الْمَدِينَةِ.", "Die Tagung fand in der Stadt statt.", [("اِنْعَقَدَ", "fand statt"), ("الِاجْتِمَاعُ", "die Tagung"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1155, "اِنْعَقَدَ الْمُؤْتَمَرُ فِي الْقَاهِرَةِ.", "Die Konferenz fand in Kairo statt.", [("اِنْعَقَدَ", "fand statt"), ("الْمُؤْتَمَرُ", "die Konferenz"), ("فِي", "in"), ("الْقَاهِرَةِ", "Kairo")]),
    (1156, "اِشْتَهَرَ الْمُغَنِّي فِي جَمِيعِ الْبِلَادِ.", "Der Sänger wurde in allen Ländern bekannt.", [("اِشْتَهَرَ", "wurde bekannt"), ("الْمُغَنِّي", "der Sänger"), ("فِي", "in"), ("جَمِيعِ", "allen"), ("الْبِلَادِ", "Ländern")]),
    (1156, "اِشْتَهَرَ الْكِتَابُ فِي الْجَامِعَةِ.", "Das Buch wurde an der Universität bekannt.", [("اِشْتَهَرَ", "wurde bekannt"), ("الْكِتَابُ", "das Buch"), ("فِي", "an"), ("الْجَامِعَةِ", "der Universität")]),
    (1156, "اِشْتَهَرَتِ الْمَدِينَةُ بِالْجَبَلِ الْجَمِيلِ.", "Die Stadt wurde durch den schönen Berg bekannt.", [("اِشْتَهَرَتِ", "wurde bekannt"), ("الْمَدِينَةُ", "die Stadt"), ("بِالْجَبَلِ", "durch den Berg"), ("الْجَمِيلِ", "schönen")]),
    (1157, "اِمْتَنَعَ الرَّجُلُ عَنْ التَّدْخِينِ.", "Der Mann weigerte sich zu rauchen.", [("اِمْتَنَعَ", "weigerte sich"), ("الرَّجُلُ", "der Mann"), ("عَنْ", "zu"), ("التَّدْخِينِ", "rauchen")]),
    (1157, "اِمْتَنَعَتِ الْمَرْأَةُ عَنِ الْإِجَابَةِ.", "Die Frau weigerte sich zu antworten.", [("اِمْتَنَعَتِ", "weigerte sich"), ("الْمَرْأَةُ", "die Frau"), ("عَنِ", "zu"), ("الْإِجَابَةِ", "antworten")]),
    (1157, "اِمْتَنَعْنَا عَنِ السَّفَرِ فِي الْعَاصِفَةِ.", "Wir unterließen die Reise im Sturm.", [("اِمْتَنَعْنَا", "wir unterließen"), ("عَنِ", "die"), ("السَّفَرِ", "Reise"), ("فِي", "im"), ("الْعَاصِفَةِ", "Sturm")]),
    (1158, "اِحْتَمَلَ الْجُنْدِيُّ الْحَرَّ فِي الصَّحْرَاءِ.", "Der Soldat hielt die Hitze in der Wüste aus.", [("اِحْتَمَلَ", "hielt aus"), ("الْجُنْدِيُّ", "der Soldat"), ("الْحَرَّ", "die Hitze"), ("فِي", "in"), ("الصَّحْرَاءِ", "der Wüste")]),
    (1158, "اِحْتَمَلَ الرَّجُلُ الْأَلَمَ بِصَبْرٍ.", "Der Mann ertrug den Schmerz mit Geduld.", [("اِحْتَمَلَ", "ertrug"), ("الرَّجُلُ", "der Mann"), ("الْأَلَمَ", "den Schmerz"), ("بِصَبْرٍ", "mit Geduld")]),
    (1158, "اِحْتَمَلْنَا الِانْتِظَارَ فِي الْمَحَطَّةِ.", "Wir hielten das Warten am Bahnhof aus.", [("اِحْتَمَلْنَا", "wir hielten aus"), ("الِانْتِظَارَ", "das Warten"), ("فِي", "am"), ("الْمَحَطَّةِ", "Bahnhof")]),
    (1159, "اِسْتَمْتَعَ الرَّجُلُ بِالْقِرَاءَةِ فِي الْمَسَاءِ.", "Der Mann genoss das Lesen am Abend.", [("اِسْتَمْتَعَ", "genoss"), ("الرَّجُلُ", "der Mann"), ("بِالْقِرَاءَةِ", "das Lesen"), ("فِي", "am"), ("الْمَسَاءِ", "Abend")]),
    (1159, "اِسْتَمْتَعَتِ الْأَطْفَالُ بِالرِّحْلَةِ.", "Die Kinder genossen die Reise.", [("اِسْتَمْتَعَتِ", "genossen"), ("الْأَطْفَالُ", "die Kinder"), ("بِالرِّحْلَةِ", "die Reise")]),
    (1159, "اِسْتَمْتَعْنَا بِالْمَنْظَرِ مِنَ الْجَبَلِ.", "Wir genossen die Aussicht vom Berg.", [("اِسْتَمْتَعْنَا", "wir genossen"), ("بِالْمَنْظَرِ", "die Aussicht"), ("مِنَ", "vom"), ("الْجَبَلِ", "Berg")]),
    (1160, "تَعَلَّقَ الْوَلَدُ بِأُمِّهِ.", "Der Junge hing an seiner Mutter.", [("تَعَلَّقَ", "hing"), ("الْوَلَدُ", "der Junge"), ("بِأُمِّهِ", "an seiner Mutter")]),
    (1160, "تَعَلَّقَ الرَّجُلُ بِالْفِكْرَةِ الْجَدِيدَةِ.", "Der Mann hing an der neuen Idee.", [("تَعَلَّقَ", "hing"), ("الرَّجُلُ", "der Mann"), ("بِالْفِكْرَةِ", "an der Idee"), ("الْجَدِيدَةِ", "neuen")]),
    (1161, "اِنْتَصَرَ الْجَيْشُ فِي الْمَعْرَكَةِ.", "Die Armee siegte in der Schlacht.", [("اِنْتَصَرَ", "siegte"), ("الْجَيْشُ", "die Armee"), ("فِي", "in"), ("الْمَعْرَكَةِ", "der Schlacht")]),
    (1161, "اِنْتَصَرَ الْفَرِيقُ فِي الْمُبَارَاةِ.", "Die Mannschaft obsiegte im Spiel.", [("اِنْتَصَرَ", "obsiegte"), ("الْفَرِيقُ", "die Mannschaft"), ("فِي", "im"), ("الْمُبَارَاةِ", "Spiel")]),
    (1161, "اِنْتَصَرَ الْحَقُّ فِي النِّهَايَةِ.", "Die Wahrheit siegte am Ende.", [("اِنْتَصَرَ", "siegte"), ("الْحَقُّ", "die Wahrheit"), ("فِي", "am"), ("النِّهَايَةِ", "Ende")]),
    (1162, "اِسْتَوْعَبَ الْبَيْتُ جَمِيعَ الضُّيُوفِ.", "Das Haus fasste alle Gäste.", [("اِسْتَوْعَبَ", "fasste"), ("الْبَيْتُ", "das Haus"), ("جَمِيعَ", "alle"), ("الضُّيُوفِ", "Gäste")]),
    (1162, "اِسْتَوْعَبَ الْكِتَابُ الْمَوْضُوعَ كَامِلًا.", "Das Buch umfasste das Thema vollständig.", [("اِسْتَوْعَبَ", "umfasste"), ("الْكِتَابُ", "das Buch"), ("الْمَوْضُوعَ", "das Thema"), ("كَامِلًا", "vollständig")]),
    (1162, "اِسْتَوْعَبَ الْقَاعَةُ الْمِائَةَ فَرْدٍ.", "Der Saal nahm hundert Personen auf.", [("اِسْتَوْعَبَ", "nahm auf"), ("الْقَاعَةُ", "der Saal"), ("الْمِائَةَ", "die hundert"), ("فَرْدٍ", "Personen")]),
    (1163, "اِسْتَعَانَ الرَّجُلُ بِصَدِيقِهِ فِي الْعَمَلِ.", "Der Mann bat seinen Freund um Hilfe bei der Arbeit.", [("اِسْتَعَانَ", "bat um Hilfe"), ("الرَّجُلُ", "der Mann"), ("بِصَدِيقِهِ", "seinen Freund"), ("فِي", "bei"), ("الْعَمَلِ", "der Arbeit")]),
    (1163, "اِسْتَعَانَتِ الشَّرِكَةُ بِالْخُبَرَاءِ.", "Die Firma rief die Experten um Hilfe.", [("اِسْتَعَانَتِ", "rief um Hilfe"), ("الشَّرِكَةُ", "die Firma"), ("بِالْخُبَرَاءِ", "die Experten")]),
    (1163, "اِسْتَعَنَّا بِالْكِتَابِ فِي الدَّرْسِ.", "Wir nahmen das Buch in der Lektion zur Hilfe.", [("اِسْتَعَنَّا", "wir nahmen zur Hilfe"), ("بِالْكِتَابِ", "das Buch"), ("فِي", "in"), ("الدَّرْسِ", "der Lektion")]),
    (1164, "اِسْتَوْلَى الْجَيْشُ عَلَى الْمَدِينَةِ.", "Die Armee bemächtigte sich der Stadt.", [("اِسْتَوْلَى", "bemächtigte sich"), ("الْجَيْشُ", "die Armee"), ("عَلَى", "der"), ("الْمَدِينَةِ", "Stadt")]),
    (1164, "اِسْتَوْلَى الْخَوْفُ عَلَى النَّاسِ.", "Die Angst ergriff die Menschen.", [("اِسْتَوْلَى", "ergriff"), ("الْخَوْفُ", "die Angst"), ("عَلَى", "die"), ("النَّاسِ", "Menschen")]),
    (1164, "اِسْتَوْلَى الرَّجُلُ عَلَى الْحَقِيبَةِ.", "Der Mann bemächtigte sich der Tasche.", [("اِسْتَوْلَى", "bemächtigte sich"), ("الرَّجُلُ", "der Mann"), ("عَلَى", "der"), ("الْحَقِيبَةِ", "Tasche")]),
    (1165, "اِنْتَقَمَ الرَّجُلُ مِنَ اللِّصِّ.", "Der Mann rächte sich am Dieb.", [("اِنْتَقَمَ", "rächte sich"), ("الرَّجُلُ", "der Mann"), ("مِنَ", "am"), ("اللِّصِّ", "Dieb")]),
    (1165, "اِنْتَقَمَتِ الْمَرْأَةُ مِنَ الظَّالِمِ.", "Die Frau rächte sich am Unterdrücker.", [("اِنْتَقَمَتِ", "rächte sich"), ("الْمَرْأَةُ", "die Frau"), ("مِنَ", "am"), ("الظَّالِمِ", "Unterdrücker")]),
    (1166, "اِنْحَنَى الرَّجُلُ لِيَلْتَقِطَ الْقَلَمَ.", "Der Mann beugte sich, um den Stift aufzuheben.", [("اِنْحَنَى", "beugte sich"), ("الرَّجُلُ", "der Mann"), ("لِيَلْتَقِطَ", "um aufzuheben"), ("الْقَلَمَ", "den Stift")]),
    (1166, "اِنْحَنَتِ الشَّجَرَةُ فِي الْعَاصِفَةِ.", "Der Baum krümmte sich im Sturm.", [("اِنْحَنَتِ", "krümmte sich"), ("الشَّجَرَةُ", "der Baum"), ("فِي", "im"), ("الْعَاصِفَةِ", "Sturm")]),
    (1166, "اِنْحَنَى الطَّالِبُ عَلَى الدَّفْتَرِ.", "Der Student beugte sich über das Heft.", [("اِنْحَنَى", "beugte sich"), ("الطَّالِبُ", "der Student"), ("عَلَى", "über"), ("الدَّفْتَرِ", "das Heft")]),
    (1167, "اِطْمَأَنَّ الرَّجُلُ بَعْدَ الْخَبَرِ الْجَيِّدِ.", "Der Mann beruhigte sich nach der guten Nachricht.", [("اِطْمَأَنَّ", "beruhigte sich"), ("الرَّجُلُ", "der Mann"), ("بَعْدَ", "nach"), ("الْخَبَرِ", "der Nachricht"), ("الْجَيِّدِ", "guten")]),
    (1167, "اِطْمَأَنَّ الْقَلْبُ عِنْدَ اللِّقَاءِ.", "Das Herz beruhigte sich beim Treffen.", [("اِطْمَأَنَّ", "beruhigte sich"), ("الْقَلْبُ", "das Herz"), ("عِنْدَ", "beim"), ("اللِّقَاءِ", "Treffen")]),
    (1167, "اِطْمَأَنَّ الشَّعْبُ إِلَى الْقَرَارِ.", "Das Volk vertraute auf die Entscheidung.", [("اِطْمَأَنَّ", "vertraute"), ("الشَّعْبُ", "das Volk"), ("إِلَى", "auf"), ("الْقَرَارِ", "die Entscheidung")]),
    (1168, "اِعْتَادَ الرَّجُلُ عَلَى النُّهُوضِ مُبَكِّرًا.", "Der Mann gewöhnte sich an das frühe Aufstehen.", [("اِعْتَادَ", "gewöhnte sich"), ("الرَّجُلُ", "der Mann"), ("عَلَى", "an"), ("النُّهُوضِ", "das Aufstehen"), ("مُبَكِّرًا", "frühe")]),
    (1168, "اِعْتَادَ الْوَلَدُ عَلَى الْقِرَاءَةِ فِي اللَّيْلِ.", "Der Junge gewöhnte sich an das Lesen in der Nacht.", [("اِعْتَادَ", "gewöhnte sich"), ("الْوَلَدُ", "der Junge"), ("عَلَى", "an"), ("الْقِرَاءَةِ", "das Lesen"), ("فِي", "in"), ("اللَّيْلِ", "der Nacht")]),
    (1168, "اِعْتَادَتِ الْمَرْأَةُ عَلَى الْعَمَلِ الْيَوْمِيِّ.", "Die Frau gewöhnte sich an die tägliche Arbeit.", [("اِعْتَادَتِ", "gewöhnte sich"), ("الْمَرْأَةُ", "die Frau"), ("عَلَى", "an"), ("الْعَمَلِ", "die Arbeit"), ("الْيَوْمِيِّ", "tägliche")]),
    (1169, "تَخَيَّلَ الطِّفْلُ قِصَّةً جَمِيلَةً.", "Das Kind stellte sich eine schöne Geschichte vor.", [("تَخَيَّلَ", "stellte sich vor"), ("الطِّفْلُ", "das Kind"), ("قِصَّةً", "eine Geschichte"), ("جَمِيلَةً", "schöne")]),
    (1169, "تَخَيَّلَ الرَّجُلُ حَيَاةً أَفْضَلَ.", "Der Mann stellte sich ein besseres Leben vor.", [("تَخَيَّلَ", "stellte sich vor"), ("الرَّجُلُ", "der Mann"), ("حَيَاةً", "ein Leben"), ("أَفْضَلَ", "besseres")]),
    (1169, "تَخَيَّلْنَا الْمُسْتَقْبَلَ فِي السَّفَرِ.", "Wir stellten uns die Zukunft auf der Reise vor.", [("تَخَيَّلْنَا", "wir stellten uns vor"), ("الْمُسْتَقْبَلَ", "die Zukunft"), ("فِي", "auf"), ("السَّفَرِ", "der Reise")]),
    (1170, "تَفَادَى الرَّجُلُ الْمُشْكِلَةَ بِحِكْمَةٍ.", "Der Mann vermied das Problem klug.", [("تَفَادَى", "vermied"), ("الرَّجُلُ", "der Mann"), ("الْمُشْكِلَةَ", "das Problem"), ("بِحِكْمَةٍ", "klug")]),
    (1170, "تَفَادَتِ السَّيَّارَةُ الْعَائِقَ فِي الطَّرِيقِ.", "Das Auto wich dem Hindernis auf der Straße aus.", [("تَفَادَتِ", "wich aus"), ("السَّيَّارَةُ", "das Auto"), ("الْعَائِقَ", "dem Hindernis"), ("فِي", "auf"), ("الطَّرِيقِ", "der Straße")]),
    (1171, "تَجَمَّعَ النَّاسُ فِي السُّوقِ.", "Die Menschen versammelten sich auf dem Markt.", [("تَجَمَّعَ", "versammelten sich"), ("النَّاسُ", "die Menschen"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1171, "تَجَمَّعَ الْأَصْدِقَاءُ حَوْلَ الْمَائِدَةِ.", "Die Freunde versammelten sich um den Tisch.", [("تَجَمَّعَ", "versammelten sich"), ("الْأَصْدِقَاءُ", "die Freunde"), ("حَوْلَ", "um"), ("الْمَائِدَةِ", "den Tisch")]),
    (1171, "تَجَمَّعَ الْمَاءُ فِي الْوِعَاءِ.", "Das Wasser sammelte sich im Gefäß.", [("تَجَمَّعَ", "sammelte sich"), ("الْمَاءُ", "das Wasser"), ("فِي", "im"), ("الْوِعَاءِ", "Gefäß")]),
    (1172, "تَوَزَّعَتِ الْحِصَصُ عَلَى الْجُنُودِ.", "Die Rationen wurden auf die Soldaten verteilt.", [("تَوَزَّعَتِ", "wurden verteilt"), ("الْحِصَصُ", "die Rationen"), ("عَلَى", "auf"), ("الْجُنُودِ", "die Soldaten")]),
    (1172, "تَوَزَّعَ الرَّبْحُ بَيْنَ الشُّرَكَاءِ.", "Der Gewinn verteilte sich zwischen den Partnern.", [("تَوَزَّعَ", "verteilte sich"), ("الرَّبْحُ", "der Gewinn"), ("بَيْنَ", "zwischen"), ("الشُّرَكَاءِ", "den Partnern")]),
    (1172, "تَوَزَّعَتِ الْأَسْئِلَةُ عَلَى الطُّلَّابِ.", "Die Fragen wurden auf die Schüler verteilt.", [("تَوَزَّعَتِ", "wurden verteilt"), ("الْأَسْئِلَةُ", "die Fragen"), ("عَلَى", "auf"), ("الطُّلَّابِ", "die Schüler")]),
    (1173, "اِمْتَلَكَ الرَّجُلُ بَيْتًا فِي الْمَدِينَةِ.", "Der Mann besaß ein Haus in der Stadt.", [("اِمْتَلَكَ", "besaß"), ("الرَّجُلُ", "der Mann"), ("بَيْتًا", "ein Haus"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1173, "اِمْتَلَكَتِ الشَّرِكَةُ مَصَانِعَ كَثِيرَةً.", "Die Firma besaß viele Fabriken.", [("اِمْتَلَكَتِ", "besaß"), ("الشَّرِكَةُ", "die Firma"), ("مَصَانِعَ", "Fabriken"), ("كَثِيرَةً", "viele")]),
    (1173, "اِمْتَلَكَ الْفَلَّاحُ أَرْضًا وَاسِعَةً.", "Der Bauer besaß ein weites Land.", [("اِمْتَلَكَ", "besaß"), ("الْفَلَّاحُ", "der Bauer"), ("أَرْضًا", "ein Land"), ("وَاسِعَةً", "weites")]),
    (1174, "اِعْتَقَدَ الرَّجُلُ أَنَّ الْقَرَارَ عَدْلٌ.", "Der Mann glaubte, dass die Entscheidung gerecht ist.", [("اِعْتَقَدَ", "glaubte"), ("الرَّجُلُ", "der Mann"), ("أَنَّ", "dass"), ("الْقَرَارَ", "die Entscheidung"), ("عَدْلٌ", "gerecht ist")]),
    (1174, "اِعْتَقَدَ الطَّالِبُ فِي أَهَمِّيَّةِ الدَّرْسِ.", "Der Student war von der Wichtigkeit der Lektion überzeugt.", [("اِعْتَقَدَ", "war überzeugt"), ("الطَّالِبُ", "der Student"), ("فِي", "von"), ("أَهَمِّيَّةِ", "der Wichtigkeit"), ("الدَّرْسِ", "der Lektion")]),
    (1174, "اِعْتَقَدَ النَّاسُ فِي صِدْقِ الْخَبَرِ.", "Die Menschen glaubten an die Wahrheit der Nachricht.", [("اِعْتَقَدَ", "glaubten"), ("النَّاسُ", "die Menschen"), ("فِي", "an"), ("صِدْقِ", "die Wahrheit"), ("الْخَبَرِ", "der Nachricht")]),
    (1175, "اِنْظَمَّ الْوَلَدُ إِلَى الْفَرِيقِ.", "Der Junge schloss sich der Mannschaft an.", [("اِنْظَمَّ", "schloss sich an"), ("الْوَلَدُ", "der Junge"), ("إِلَى", "der"), ("الْفَرِيقِ", "Mannschaft")]),
    (1175, "اِنْظَمَّ الْمُوَظَّفُ إِلَى النِّقَابَةِ.", "Der Angestellte schloss sich der Gewerkschaft an.", [("اِنْظَمَّ", "schloss sich an"), ("الْمُوَظَّفُ", "der Angestellte"), ("إِلَى", "der"), ("النِّقَابَةِ", "Gewerkschaft")]),
    (1176, "اِحْتَفَظَ الرَّجُلُ بِالْوَثَائِقِ الْقَدِيمَةِ.", "Der Mann bewahrte die alten Dokumente auf.", [("اِحْتَفَظَ", "bewahrte auf"), ("الرَّجُلُ", "der Mann"), ("بِالْوَثَائِقِ", "die Dokumente"), ("الْقَدِيمَةِ", "alten")]),
    (1176, "اِحْتَفَظَتِ الْمَرْأَةُ بِالصُّوَرِ الثَّمِينَةِ.", "Die Frau bewahrte die wertvollen Fotos auf.", [("اِحْتَفَظَتِ", "bewahrte auf"), ("الْمَرْأَةُ", "die Frau"), ("بِالصُّوَرِ", "die Fotos"), ("الثَّمِينَةِ", "wertvollen")]),
    (1176, "اِحْتَفَظْنَا بِالْمُفَاتِيحِ فِي الدُّرْجِ.", "Wir bewahrten die Schlüssel in der Schublade auf.", [("اِحْتَفَظْنَا", "wir bewahrten auf"), ("بِالْمُفَاتِيحِ", "die Schlüssel"), ("فِي", "in"), ("الدُّرْجِ", "der Schublade")]),
    (1177, "اِنْزَعَجَ الرَّجُلُ مِنَ الضَّجِيجِ.", "Der Mann ärgerte sich über den Lärm.", [("اِنْزَعَجَ", "ärgerte sich"), ("الرَّجُلُ", "der Mann"), ("مِنَ", "über"), ("الضَّجِيجِ", "den Lärm")]),
    (1177, "اِنْزَعَجَ الْوَلَدُ مِنَ الْخَبَرِ السَّيِّئِ.", "Der Junge ärgerte sich über die schlechte Nachricht.", [("اِنْزَعَجَ", "ärgerte sich"), ("الْوَلَدُ", "der Junge"), ("مِنَ", "über"), ("الْخَبَرِ", "die Nachricht"), ("السَّيِّئِ", "schlechte")]),
    (1177, "اِنْزَعَجَتِ الْمَرْأَةُ مِنَ التَّأْخِيرِ.", "Die Frau ärgerte sich über die Verspätung.", [("اِنْزَعَجَتِ", "ärgerte sich"), ("الْمَرْأَةُ", "die Frau"), ("مِنَ", "über"), ("التَّأْخِيرِ", "die Verspätung")]),
    (1178, "اِسْتَرْجَعَ الرَّجُلُ أَمْوَالَهُ مِنَ الْبَنْكِ.", "Der Mann erhielt sein Geld von der Bank zurück.", [("اِسْتَرْجَعَ", "erhielt zurück"), ("الرَّجُلُ", "der Mann"), ("أَمْوَالَهُ", "sein Geld"), ("مِنَ", "von"), ("الْبَنْكِ", "der Bank")]),
    (1178, "اِسْتَرْجَعَتِ الشَّرِكَةُ الْبَضَائِعَ الْمَرْدُودَةَ.", "Die Firma erhielt die zurückgegebenen Waren zurück.", [("اِسْتَرْجَعَتِ", "erhielt zurück"), ("الشَّرِكَةُ", "die Firma"), ("الْبَضَائِعَ", "die Waren"), ("الْمَرْدُودَةَ", "zurückgegebenen")]),
    (1178, "اِسْتَرْجَعْنَا الْحَقِيبَةَ مِنَ الْقِطَارِ.", "Wir holten die Tasche vom Zug zurück.", [("اِسْتَرْجَعْنَا", "wir holten zurück"), ("الْحَقِيبَةَ", "die Tasche"), ("مِنَ", "vom"), ("الْقِطَارِ", "Zug")]),
    (1179, "اِعْتَزَلَ الرَّجُلُ الْحَيَاةَ الْعَامَّةَ.", "Der Mann zog sich aus dem öffentlichen Leben zurück.", [("اِعْتَزَلَ", "zog sich zurück"), ("الرَّجُلُ", "der Mann"), ("الْحَيَاةَ", "aus dem Leben"), ("الْعَامَّةَ", "öffentlichen")]),
    (1179, "اِعْتَزَلَ الْعَامِلُ الْعَمَلَ بَعْدَ الشِّقَاءِ.", "Der Arbeiter zog sich nach der Mühe von der Arbeit zurück.", [("اِعْتَزَلَ", "zog sich zurück"), ("الْعَامِلُ", "der Arbeiter"), ("الْعَمَلَ", "von der Arbeit"), ("بَعْدَ", "nach"), ("الشِّقَاءِ", "der Mühe")]),
    (1179, "اِعْتَزَلَتِ الْمَرْأَةُ الْأَصْدِقَاءَ فِي هَذِهِ الْأَيَّامِ.", "Die Frau zog sich in diesen Tagen von den Freunden zurück.", [("اِعْتَزَلَتِ", "zog sich zurück"), ("الْمَرْأَةُ", "die Frau"), ("الْأَصْدِقَاءَ", "von den Freunden"), ("فِي", "in"), ("هَذِهِ", "diesen"), ("الْأَيَّامِ", "Tagen")]),
    (1180, "اِسْتَهَانَ الْمُدِيرُ بِمَوْهِبَةِ الْمُوَظَّفِ.", "Der Direktor schätzte die Begabung des Angestellten gering.", [("اِسْتَهَانَ", "schätzte gering"), ("الْمُدِيرُ", "der Direktor"), ("بِمَوْهِبَةِ", "die Begabung"), ("الْمُوَظَّفِ", "des Angestellten")]),
    (1180, "اِسْتَهَانَ الرَّجُلُ بِخَطَرِ السَّفَرِ.", "Der Mann schätzte die Gefahr der Reise gering.", [("اِسْتَهَانَ", "schätzte gering"), ("الرَّجُلُ", "der Mann"), ("بِخَطَرِ", "die Gefahr"), ("السَّفَرِ", "der Reise")]),
    (1181, "اِحْتَاطَ الرَّجُلُ فِي السَّفَرِ الطَّوِيلِ.", "Der Mann übte auf der langen Reise Vorsicht.", [("اِحْتَاطَ", "übte Vorsicht"), ("الرَّجُلُ", "der Mann"), ("فِي", "auf"), ("السَّفَرِ", "der Reise"), ("الطَّوِيلِ", "langen")]),
    (1181, "اِحْتَاطَ الْقَائِدُ فِي تَخْطِيطِ الْمَعْرَكَةِ.", "Der Führer übte bei der Planung der Schlacht Vorsicht.", [("اِحْتَاطَ", "übte Vorsicht"), ("الْقَائِدُ", "der Führer"), ("فِي", "bei"), ("تَخْطِيطِ", "der Planung"), ("الْمَعْرَكَةِ", "der Schlacht")]),
    (1181, "اِحْتَاطَتِ الْمَرْأَةُ لِتَفَادِي الْخَطَرِ.", "Die Frau übte Vorsicht, um die Gefahr zu vermeiden.", [("اِحْتَاطَتِ", "übte Vorsicht"), ("الْمَرْأَةُ", "die Frau"), ("لِتَفَادِي", "um zu vermeiden"), ("الْخَطَرِ", "die Gefahr")]),
    (1182, "اِمْتَدَّ الطَّرِيقُ إِلَى الْجَبَلِ.", "Die Straße erstreckte sich bis zum Berg.", [("اِمْتَدَّ", "erstreckte sich"), ("الطَّرِيقُ", "die Straße"), ("إِلَى", "bis zum"), ("الْجَبَلِ", "Berg")]),
    (1182, "اِمْتَدَّتِ الْحَدِيقَةُ عَلَى ضِفَّةِ النَّهْرِ.", "Der Garten erstreckte sich am Ufer des Flusses.", [("اِمْتَدَّتِ", "erstreckte sich"), ("الْحَدِيقَةُ", "der Garten"), ("عَلَى", "am"), ("ضِفَّةِ", "Ufer"), ("النَّهْرِ", "des Flusses")]),
    (1182, "اِمْتَدَّتْ أَيَّامُ الْعُطْلَةِ أَسْبُوعَيْنِ.", "Die Urlaubstage erstreckten sich über zwei Wochen.", [("اِمْتَدَّتْ", "erstreckten sich"), ("أَيَّامُ", "die Tage"), ("الْعُطْلَةِ", "des Urlaubs"), ("أَسْبُوعَيْنِ", "zwei Wochen")]),
    (1183, "اِنْقَلَبَتِ السَّيَّارَةُ فِي الطَّرِيقِ.", "Das Auto kippte auf der Straße um.", [("اِنْقَلَبَتِ", "kippte um"), ("السَّيَّارَةُ", "das Auto"), ("فِي", "auf"), ("الطَّرِيقِ", "der Straße")]),
    (1183, "اِنْقَلَبَ الْكَأْسُ عَلَى الْمَائِدَةِ.", "Das Glas kippte auf dem Tisch um.", [("اِنْقَلَبَ", "kippte um"), ("الْكَأْسُ", "das Glas"), ("عَلَى", "auf"), ("الْمَائِدَةِ", "dem Tisch")]),
    (1183, "اِنْقَلَبَ الْقَرَارُ فِي نِهَايَةِ الِاجْتِمَاعِ.", "Die Entscheidung wurde am Ende der Sitzung umgestoßen.", [("اِنْقَلَبَ", "wurde umgestoßen"), ("الْقَرَارُ", "die Entscheidung"), ("فِي", "am"), ("نِهَايَةِ", "Ende"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1184, "اِحْتَرَقَ الْبَيْتُ فِي الْحَرِيقِ الْكَبِيرِ.", "Das Haus verbrannte im großen Feuer.", [("اِحْتَرَقَ", "verbrannte"), ("الْبَيْتُ", "das Haus"), ("فِي", "im"), ("الْحَرِيقِ", "Feuer"), ("الْكَبِيرِ", "großen")]),
    (1184, "اِحْتَرَقَ الطَّعَامُ فِي الْمَطْبَخِ.", "Das Essen verbrannte in der Küche.", [("اِحْتَرَقَ", "verbrannte"), ("الطَّعَامُ", "das Essen"), ("فِي", "in"), ("الْمَطْبَخِ", "der Küche")]),
    (1184, "اِحْتَرَقَتِ الْأَوْرَاقُ فِي النَّارِ.", "Die Blätter verbrannten im Feuer.", [("اِحْتَرَقَتِ", "verbrannten"), ("الْأَوْرَاقُ", "die Blätter"), ("فِي", "im"), ("النَّارِ", "Feuer")]),
    (1185, "اِغْتَسَلَ الرَّجُلُ قَبْلَ الصَّلَاةِ.", "Der Mann wusch sich vor dem Gebet.", [("اِغْتَسَلَ", "wusch sich"), ("الرَّجُلُ", "der Mann"), ("قَبْلَ", "vor"), ("الصَّلَاةِ", "dem Gebet")]),
    (1185, "اِغْتَسَلَ الْوَلَدُ بِالْمَاءِ الْبَارِدِ.", "Der Junge wusch sich mit dem kalten Wasser.", [("اِغْتَسَلَ", "wusch sich"), ("الْوَلَدُ", "der Junge"), ("بِالْمَاءِ", "mit dem Wasser"), ("الْبَارِدِ", "kalten")]),
    (1186, "تَعَاوَنَ الْجِيرَانُ فِي بِنَاءِ الْحَائِطِ.", "Die Nachbarn arbeiteten beim Bau der Mauer zusammen.", [("تَعَاوَنَ", "arbeiteten zusammen"), ("الْجِيرَانُ", "die Nachbarn"), ("فِي", "beim"), ("بِنَاءِ", "Bau"), ("الْحَائِطِ", "der Mauer")]),
    (1186, "تَعَاوَنَ الطُّلَّابُ فِي الدَّرْسِ.", "Die Schüler arbeiteten bei der Lektion zusammen.", [("تَعَاوَنَ", "arbeiteten zusammen"), ("الطُّلَّابُ", "die Schüler"), ("فِي", "bei"), ("الدَّرْسِ", "der Lektion")]),
    (1186, "تَعَاوَنَ الْعُمَّالُ فِي الْمَصْنَعِ.", "Die Arbeiter arbeiteten in der Fabrik zusammen.", [("تَعَاوَنَ", "arbeiteten zusammen"), ("الْعُمَّالُ", "die Arbeiter"), ("فِي", "in"), ("الْمَصْنَعِ", "der Fabrik")]),
    (1187, "تَرَاجَعَ الْعَامِلُ عَنْ قَرَارِهِ.", "Der Arbeiter trat von seiner Entscheidung zurück.", [("تَرَاجَعَ", "trat zurück"), ("الْعَامِلُ", "der Arbeiter"), ("عَنْ", "von"), ("قَرَارِهِ", "seiner Entscheidung")]),
    (1187, "تَرَاجَعَ الْعَدَدُ فِي السُّوقِ.", "Die Zahl ging auf dem Markt zurück.", [("تَرَاجَعَ", "ging zurück"), ("الْعَدَدُ", "die Zahl"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1187, "تَرَاجَعَتِ الْقُوَّةُ بَعْدَ الْمَرَضِ.", "Die Kraft nahm nach der Krankheit ab.", [("تَرَاجَعَتِ", "nahm ab"), ("الْقُوَّةُ", "die Kraft"), ("بَعْدَ", "nach"), ("الْمَرَضِ", "der Krankheit")]),
    (1188, "تَصَرَّفَ الرَّجُلُ بِحِكْمَةٍ فِي الْمَوْقِفِ.", "Der Mann handelte in der Lage klug.", [("تَصَرَّفَ", "handelte"), ("الرَّجُلُ", "der Mann"), ("بِحِكْمَةٍ", "klug"), ("فِي", "in"), ("الْمَوْقِفِ", "der Lage")]),
    (1188, "تَصَرَّفَ الْمُوَظَّفُ بِمَسْؤُولِيَّةٍ.", "Der Angestellte verhielt sich verantwortungsbewusst.", [("تَصَرَّفَ", "verhielt sich"), ("الْمُوَظَّفُ", "der Angestellte"), ("بِمَسْؤُولِيَّةٍ", "verantwortungsbewusst")]),
    (1188, "تَصَرَّفْنَا بِسُرْعَةٍ فِي الْحَرِيقِ.", "Wir handelten beim Feuer schnell.", [("تَصَرَّفْنَا", "wir handelten"), ("بِسُرْعَةٍ", "schnell"), ("فِي", "beim"), ("الْحَرِيقِ", "Feuer")]),
    (1189, "اِنْطَبَعَ الْمَعْنَى فِي ذِهْنِ الطَّالِبِ.", "Die Bedeutung prägte sich dem Geist des Schülers ein.", [("اِنْطَبَعَ", "prägte sich ein"), ("الْمَعْنَى", "die Bedeutung"), ("فِي", "dem"), ("ذِهْنِ", "Geist"), ("الطَّالِبِ", "des Schülers")]),
    (1189, "اِنْطَبَعَ الْفِلْمُ فِي ذَاكِرَةِ الْجَمِيعِ.", "Der Film prägte sich dem Gedächtnis aller ein.", [("اِنْطَبَعَ", "prägte sich ein"), ("الْفِلْمُ", "der Film"), ("فِي", "dem"), ("ذَاكِرَةِ", "Gedächtnis"), ("الْجَمِيعِ", "aller")]),
    (1189, "اِنْطَبَعَتِ الصُّورَةُ عَلَى الْوَرَقِ.", "Das Bild prägte sich auf das Papier ein.", [("اِنْطَبَعَتِ", "prägte sich ein"), ("الصُّورَةُ", "das Bild"), ("عَلَى", "auf"), ("الْوَرَقِ", "das Papier")]),
    (1190, "اِسْتَقْصَى الْقَاضِي الْحَقِيقَةَ كَامِلَةً.", "Der Richter untersuchte die Wahrheit vollständig.", [("اِسْتَقْصَى", "untersuchte"), ("الْقَاضِي", "der Richter"), ("الْحَقِيقَةَ", "die Wahrheit"), ("كَامِلَةً", "vollständig")]),
    (1190, "اِسْتَقْصَى الطَّبِيبُ أَسْبَابَ الْمَرَضِ.", "Der Arzt untersuchte die Ursachen der Krankheit gründlich.", [("اِسْتَقْصَى", "untersuchte"), ("الطَّبِيبُ", "der Arzt"), ("أَسْبَابَ", "die Ursachen"), ("الْمَرَضِ", "der Krankheit")]),
    (1191, "اِحْتَكَمَ الرَّجُلَانِ إِلَى الْقَاضِي.", "Die beiden Männer schlichteten beim Richter.", [("اِحْتَكَمَ", "schlichteten"), ("الرَّجُلَانِ", "die beiden Männer"), ("إِلَى", "beim"), ("الْقَاضِي", "Richter")]),
    (1191, "اِحْتَكَمَ الْفَرِيقُ إِلَى الْمُحَكَّمِ.", "Die Mannschaft richtete sich nach dem Schiedsrichter.", [("اِحْتَكَمَ", "richtete sich"), ("الْفَرِيقُ", "die Mannschaft"), ("إِلَى", "nach"), ("الْمُحَكَّمِ", "dem Schiedsrichter")]),
    (1191, "اِحْتَكَمْنَا إِلَى الْعَقْلِ فِي النَّقْشِ.", "Wir beriefen uns in der Diskussion auf den Verstand.", [("اِحْتَكَمْنَا", "wir beriefen uns"), ("إِلَى", "auf"), ("الْعَقْلِ", "den Verstand"), ("فِي", "in"), ("النَّقْشِ", "der Diskussion")]),
    (1192, "اِنْضَمَّ الْجُنْدِيُّ إِلَى الْجَيْشِ الْجَدِيدِ.", "Der Soldat schloss sich der neuen Armee an.", [("اِنْضَمَّ", "schloss sich an"), ("الْجُنْدِيُّ", "der Soldat"), ("إِلَى", "der"), ("الْجَيْشِ", "Armee"), ("الْجَدِيدِ", "neuen")]),
    (1192, "اِنْضَمَّ الْمُوَاطِنُ إِلَى الْحِزْبِ.", "Der Bürger schloss sich der Partei an.", [("اِنْضَمَّ", "schloss sich an"), ("الْمُوَاطِنُ", "der Bürger"), ("إِلَى", "der"), ("الْحِزْبِ", "Partei")]),
    (1192, "اِنْضَمَّ الرِّفَاقُ بَعْضُهُمْ إِلَى بَعْضٍ.", "Die Gefährten schlossen sich einander an.", [("اِنْضَمَّ", "schlossen sich an"), ("الرِّفَاقُ", "die Gefährten"), ("بَعْضُهُمْ", "einander"), ("إِلَى", "den"), ("بَعْضٍ", "anderen")]),
    (1193, "اِسْتَغَلَّ صَاحِبُ الْمَصْنَعِ الْعُمَّالَ.", "Der Fabrikbesitzer nutzte die Arbeiter aus.", [("اِسْتَغَلَّ", "nutzte aus"), ("صَاحِبُ", "der Besitzer"), ("الْمَصْنَعِ", "der Fabrik"), ("الْعُمَّالَ", "die Arbeiter")]),
    (1193, "اِسْتَغَلَّ الرَّجُلُ الْفُرْصَةَ لِلنَّجَاحِ.", "Der Mann nutzte die Gelegenheit für den Erfolg aus.", [("اِسْتَغَلَّ", "nutzte aus"), ("الرَّجُلُ", "der Mann"), ("الْفُرْصَةَ", "die Gelegenheit"), ("لِلنَّجَاحِ", "für den Erfolg")]),
    (1193, "اِسْتَغَلَّ الْفَلَّاحُ الْأَرْضَ فِي الرَّبِيعِ.", "Der Bauer nutzte das Land im Frühling aus.", [("اِسْتَغَلَّ", "nutzte aus"), ("الْفَلَّاحُ", "der Bauer"), ("الْأَرْضَ", "das Land"), ("فِي", "im"), ("الرَّبِيعِ", "Frühling")]),
    (1194, "اِنْبَهَرَ الرَّجُلُ بِالْمَنْظَرِ الْجَمِيلِ.", "Der Mann staunte über die schöne Aussicht.", [("اِنْبَهَرَ", "staunte"), ("الرَّجُلُ", "der Mann"), ("بِالْمَنْظَرِ", "über die Aussicht"), ("الْجَمِيلِ", "schöne")]),
    (1194, "اِنْبَهَرَ الطِّفْلُ بِالْأَلْعَابِ الْجَدِيدَةِ.", "Das Kind staunte über die neuen Spielzeuge.", [("اِنْبَهَرَ", "staunte"), ("الطِّفْلُ", "das Kind"), ("بِالْأَلْعَابِ", "über die Spielzeuge"), ("الْجَدِيدَةِ", "neuen")]),
    (1194, "اِنْبَهَرَ الْحُضُورُ بِالْخِطَابِ.", "Die Anwesenden staunten über die Rede.", [("اِنْبَهَرَ", "staunten"), ("الْحُضُورُ", "die Anwesenden"), ("بِالْخِطَابِ", "über die Rede")]),
    (1195, "اِعْتَزَّ الرَّجُلُ بِصِدْقِهِ.", "Der Mann war durch seine Ehrlichkeit stark.", [("اِعْتَزَّ", "war stark"), ("الرَّجُلُ", "der Mann"), ("بِصِدْقِهِ", "durch seine Ehrlichkeit")]),
    (1195, "اِعْتَزَّ الْعَامِلُ بِعَمَلِهِ الْمُتْقَنِ.", "Der Arbeiter war durch seine sorgfältige Arbeit stark.", [("اِعْتَزَّ", "war stark"), ("الْعَامِلُ", "der Arbeiter"), ("بِعَمَلِهِ", "durch seine Arbeit"), ("الْمُتْقَنِ", "sorgfältige")]),
    (1196, "اِسْتَرَخَّ الرَّجُلُ بَعْدَ الْعَمَلِ الطَّوِيلِ.", "Der Mann entspannte sich nach der langen Arbeit.", [("اِسْتَرَخَّ", "entspannte sich"), ("الرَّجُلُ", "der Mann"), ("بَعْدَ", "nach"), ("الْعَمَلِ", "der Arbeit"), ("الطَّوِيلِ", "langen")]),
    (1196, "اِسْتَرَخَّ الْجِسْمُ فِي الْمَاءِ الدَّافِئِ.", "Der Körper entspannte sich im warmen Wasser.", [("اِسْتَرَخَّ", "entspannte sich"), ("الْجِسْمُ", "der Körper"), ("فِي", "im"), ("الْمَاءِ", "Wasser"), ("الدَّافِئِ", "warmen")]),
    (1196, "اِسْتَرَخَّ الْعَامِلُونَ فِي الْعُطْلَةِ.", "Die Arbeiter entspannten sich im Urlaub.", [("اِسْتَرَخَّ", "entspannten sich"), ("الْعَامِلُونَ", "die Arbeiter"), ("فِي", "im"), ("الْعُطْلَةِ", "Urlaub")]),
    (1197, "اِنْفَرَدَ الرَّجُلُ فِي الْغُرْفَةِ.", "Der Mann war allein im Zimmer.", [("اِنْفَرَدَ", "war allein"), ("الرَّجُلُ", "der Mann"), ("فِي", "im"), ("الْغُرْفَةِ", "Zimmer")]),
    (1197, "اِنْفَرَدَ الْفَنَّانُ بِعَمَلِهِ فِي الْمَرْسَمِ.", "Der Künstler war im Atelier mit seiner Arbeit allein.", [("اِنْفَرَدَ", "war allein"), ("الْفَنَّانُ", "der Künstler"), ("بِعَمَلِهِ", "mit seiner Arbeit"), ("فِي", "im"), ("الْمَرْسَمِ", "Atelier")]),
    (1197, "اِنْفَرَدَ الْوَلَدُ عَنْ أَصْدِقَائِهِ فِي الْمَسَاءِ.", "Der Junge blieb am Abend von seinen Freunden allein.", [("اِنْفَرَدَ", "blieb allein"), ("الْوَلَدُ", "der Junge"), ("عَنْ", "von"), ("أَصْدِقَائِهِ", "seinen Freunden"), ("فِي", "am"), ("الْمَسَاءِ", "Abend")]),
    (1198, "اِسْتَفَاقَ الرَّجُلُ مِنَ النَّوْمِ الْعَمِيقِ.", "Der Mann kam aus dem tiefen Schlaf zu sich.", [("اِسْتَفَاقَ", "kam zu sich"), ("الرَّجُلُ", "der Mann"), ("مِنَ", "aus"), ("النَّوْمِ", "dem Schlaf"), ("الْعَمِيقِ", "tiefen")]),
    (1198, "اِسْتَفَاقَ الطِّفْلُ مِنَ الْحُلْمِ.", "Das Kind erwachte aus dem Traum.", [("اِسْتَفَاقَ", "erwachte"), ("الطِّفْلُ", "das Kind"), ("مِنَ", "aus"), ("الْحُلْمِ", "dem Traum")]),
    (1198, "اِسْتَفَاقَتِ الْمَرْأَةُ مِنَ الْإِغْمَاءِ فِي الْمُسْتَشْفَى.", "Die Frau kam im Krankenhaus aus der Ohnmacht zu sich.", [("اِسْتَفَاقَتِ", "kam zu sich"), ("الْمَرْأَةُ", "die Frau"), ("مِنَ", "aus"), ("الْإِغْمَاءِ", "der Ohnmacht"), ("فِي", "im"), ("الْمُسْتَشْفَى", "Krankenhaus")]),
    (1199, "اِعْتَزَمَ الرَّجُلُ عَلَى تَعَلُّمِ اللُّغَةِ.", "Der Mann hatte fest vor, die Sprache zu lernen.", [("اِعْتَزَمَ", "hatte vor"), ("الرَّجُلُ", "der Mann"), ("عَلَى", "das"), ("تَعَلُّمِ", "Lernen"), ("اللُّغَةِ", "der Sprache")]),
    (1199, "اِعْتَزَمَ الطَّالِبُ عَلَى الِاجْتِهَادِ فِي الدَّرْسِ.", "Der Student hatte fest vor, sich in der Lektion anzustrengen.", [("اِعْتَزَمَ", "hatte vor"), ("الطَّالِبُ", "der Student"), ("عَلَى", "sich"), ("الِاجْتِهَادِ", "anzustrengen"), ("فِي", "in"), ("الدَّرْسِ", "der Lektion")]),
    (1199, "اِعْتَزَمْنَا عَلَى السَّفَرِ فِي الصَّيْفِ.", "Wir hatten fest vor, im Sommer zu reisen.", [("اِعْتَزَمْنَا", "wir hatten vor"), ("عَلَى", "das"), ("السَّفَرِ", "Reisen"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1200, "اِسْتَحْسَنَ الْمُدِيرُ فِكْرَةَ الْمُوَظَّفِ.", "Der Direktor fand die Idee des Angestellten gut.", [("اِسْتَحْسَنَ", "fand gut"), ("الْمُدِيرُ", "der Direktor"), ("فِكْرَةَ", "die Idee"), ("الْمُوَظَّفِ", "des Angestellten")]),
    (1200, "اِسْتَحْسَنَ الْجَمْهُورُ الْأَدَاءَ فِي الْمَسْرَحِ.", "Das Publikum billigte die Aufführung im Theater.", [("اِسْتَحْسَنَ", "billigte"), ("الْجَمْهُورُ", "das Publikum"), ("الْأَدَاءَ", "die Aufführung"), ("فِي", "im"), ("الْمَسْرَحِ", "Theater")]),
    (1201, "اِنْفَتَحَ الْبَابُ فِي الصَّبَاحِ.", "Die Tür öffnete sich am Morgen.", [("اِنْفَتَحَ", "öffnete sich"), ("الْبَابُ", "die Tür"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1201, "اِنْفَتَحَتِ النَّافِذَةُ بِسَبَبِ الرِّيحِ.", "Das Fenster öffnete sich wegen des Windes.", [("اِنْفَتَحَتِ", "öffnete sich"), ("النَّافِذَةُ", "das Fenster"), ("بِسَبَبِ", "wegen"), ("الرِّيحِ", "des Windes")]),
    (1201, "اِنْفَتَحَ الْمَحَلُّ الْجَدِيدُ فِي السُّوقِ.", "Das neue Geschäft eröffnete auf dem Markt.", [("اِنْفَتَحَ", "eröffnete"), ("الْمَحَلُّ", "das Geschäft"), ("الْجَدِيدُ", "neue"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1202, "اِعْتَدَّ الْمُحَاسِبُ الْأَمْوَالَ بِدِقَّةٍ.", "Der Buchhalter zählte das Geld genau.", [("اِعْتَدَّ", "zählte"), ("الْمُحَاسِبُ", "der Buchhalter"), ("الْأَمْوَالَ", "das Geld"), ("بِدِقَّةٍ", "genau")]),
    (1202, "اِعْتَدَّ الْمُدِيرُ بِمَوْهِبَةِ الْمُوَظَّفِ.", "Der Direktor berücksichtigte die Begabung des Angestellten.", [("اِعْتَدَّ", "berücksichtigte"), ("الْمُدِيرُ", "der Direktor"), ("بِمَوْهِبَةِ", "die Begabung"), ("الْمُوَظَّفِ", "des Angestellten")]),
    (1202, "اِعْتَدَّ الْقَاضِي بِالْأَدِلَّةِ فِي الْحُكْمِ.", "Der Richter berücksichtigte die Beweise im Urteil.", [("اِعْتَدَّ", "berücksichtigte"), ("الْقَاضِي", "der Richter"), ("بِالْأَدِلَّةِ", "die Beweise"), ("فِي", "im"), ("الْحُكْمِ", "Urteil")]),
    (1203, "اِسْتَغْرَبَ الرَّجُلُ مِنَ الْخَبَرِ الْغَرِيبِ.", "Der Mann wunderte sich über die seltsame Nachricht.", [("اِسْتَغْرَبَ", "wunderte sich"), ("الرَّجُلُ", "der Mann"), ("مِنَ", "über"), ("الْخَبَرِ", "die Nachricht"), ("الْغَرِيبِ", "seltsame")]),
    (1203, "اِسْتَغْرَبَ الطِّفْلُ مِنْ صَوْتِ الْفِيلِ.", "Das Kind wunderte sich über das Geräusch des Elefanten.", [("اِسْتَغْرَبَ", "wunderte sich"), ("الطِّفْلُ", "das Kind"), ("مِنْ", "über"), ("صَوْتِ", "das Geräusch"), ("الْفِيلِ", "des Elefanten")]),
    (1203, "اِسْتَغْرَبَ الْجَمِيعُ مِنَ السُّكُوتِ.", "Alle wunderten sich über das Schweigen.", [("اِسْتَغْرَبَ", "wunderten sich"), ("الْجَمِيعُ", "alle"), ("مِنَ", "über"), ("السُّكُوتِ", "das Schweigen")]),
    (1204, "اِعْتَقَلَتِ الشُّرْطَةُ اللِّصَّ فِي اللَّيْلِ.", "Die Polizei verhaftete den Dieb in der Nacht.", [("اِعْتَقَلَتِ", "verhaftete"), ("الشُّرْطَةُ", "die Polizei"), ("اللِّصَّ", "den Dieb"), ("فِي", "in"), ("اللَّيْلِ", "der Nacht")]),
    (1204, "اِعْتَقَلَ الْجَيْشُ الْجَاسُوسَ.", "Die Armee verhaftete den Spion.", [("اِعْتَقَلَ", "verhaftete"), ("الْجَيْشُ", "die Armee"), ("الْجَاسُوسَ", "den Spion")]),
    (1204, "اِعْتَقَلَتِ الْحُكُومَةُ الْمُخَالِفِينَ.", "Die Regierung verhaftete die Gegner.", [("اِعْتَقَلَتِ", "verhaftete"), ("الْحُكُومَةُ", "die Regierung"), ("الْمُخَالِفِينَ", "die Gegner")]),
    (1205, "اِنْصَرَفَ الْعَامِلُ مِنَ الْمَصْنَعِ فِي الْمَسَاءِ.", "Der Arbeiter ging am Abend aus der Fabrik weg.", [("اِنْصَرَفَ", "ging weg"), ("الْعَامِلُ", "der Arbeiter"), ("مِنَ", "aus"), ("الْمَصْنَعِ", "der Fabrik"), ("فِي", "am"), ("الْمَسَاءِ", "Abend")]),
    (1205, "اِنْصَرَفَ الضُّيُوفُ بَعْدَ الْعَشَاءِ.", "Die Gäste gingen nach dem Abendessen weg.", [("اِنْصَرَفَ", "gingen weg"), ("الضُّيُوفُ", "die Gäste"), ("بَعْدَ", "nach"), ("الْعَشَاءِ", "dem Abendessen")]),
    (1206, "اِعْتَرَضَ الرَّجُلُ عَلَى الْقَرَارِ.", "Der Mann trat der Entscheidung entgegen.", [("اِعْتَرَضَ", "trat entgegen"), ("الرَّجُلُ", "der Mann"), ("عَلَى", "der"), ("الْقَرَارِ", "Entscheidung")]),
    (1206, "اِعْتَرَضَ الطَّالِبُ عَلَى النَّتِيجَةِ.", "Der Student widersprach dem Ergebnis.", [("اِعْتَرَضَ", "widersprach"), ("الطَّالِبُ", "der Student"), ("عَلَى", "dem"), ("النَّتِيجَةِ", "Ergebnis")]),
    (1206, "اِعْتَرَضَ السَّائِحُ عَلَى السِّعْرِ الْعَالِي.", "Der Tourist trat dem hohen Preis entgegen.", [("اِعْتَرَضَ", "trat entgegen"), ("السَّائِحُ", "der Tourist"), ("عَلَى", "dem"), ("السِّعْرِ", "Preis"), ("الْعَالِي", "hohen")]),
    (1207, "اِسْتَغْرَقَ الطَّالِبُ فِي قِرَاءَةِ الْكِتَابِ.", "Der Student vertiefte sich in das Lesen des Buches.", [("اِسْتَغْرَقَ", "vertiefte sich"), ("الطَّالِبُ", "der Student"), ("فِي", "in das"), ("قِرَاءَةِ", "Lesen"), ("الْكِتَابِ", "des Buches")]),
    (1207, "اِسْتَغْرَقَ الْعَمَلُ وَقْتًا طَوِيلًا.", "Die Arbeit brauchte lange Zeit.", [("اِسْتَغْرَقَ", "brauchte"), ("الْعَمَلُ", "die Arbeit"), ("وَقْتًا", "Zeit"), ("طَوِيلًا", "lange")]),
    (1207, "اِسْتَغْرَقَ الْعَالِمُ فِي تَفْكِيرِهِ.", "Der Gelehrte vertiefte sich in sein Nachdenken.", [("اِسْتَغْرَقَ", "vertiefte sich"), ("الْعَالِمُ", "der Gelehrte"), ("فِي", "in"), ("تَفْكِيرِهِ", "sein Nachdenken")]),
    (1208, "السُّكَّانُ كَثِيرُونَ فِي الْمَدِينَةِ.", "Die Bevölkerung ist zahlreich in der Stadt.", [("السُّكَّانُ", "die Bevölkerung"), ("كَثِيرُونَ", "ist zahlreich"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1208, "سُكَّانُ الْقَرْيَةِ هَادِئُونَ.", "Die Bewohner des Dorfes sind ruhig.", [("سُكَّانُ", "die Bewohner"), ("الْقَرْيَةِ", "des Dorfes"), ("هَادِئُونَ", "sind ruhig")]),
    (1208, "يَزِيدُ السُّكَّانُ فِي الْبَلَدِ كُلَّ عَامٍ.", "Die Bevölkerung nimmt im Land jedes Jahr zu.", [("يَزِيدُ", "nimmt zu"), ("السُّكَّانُ", "die Bevölkerung"), ("فِي", "im"), ("الْبَلَدِ", "Land"), ("كُلَّ", "jedes"), ("عَامٍ", "Jahr")]),
    (1209, "الْوَاقِعُ يَخْتَلِفُ عَنِ الْحُلْمِ.", "Die Wirklichkeit unterscheidet sich vom Traum.", [("الْوَاقِعُ", "die Wirklichkeit"), ("يَخْتَلِفُ", "unterscheidet sich"), ("عَنِ", "vom"), ("الْحُلْمِ", "Traum")]),
    (1209, "وَاقِعُ الْحَيَاةِ قَاسٍ أَحْيَانًا.", "Die Wirklichkeit des Lebens ist manchmal hart.", [("وَاقِعُ", "die Wirklichkeit"), ("الْحَيَاةِ", "des Lebens"), ("قَاسٍ", "ist hart"), ("أَحْيَانًا", "manchmal")]),
    (1209, "نَظَرْنَا إِلَى الْوَاقِعِ بِعَيْنٍ وَاضِحَةٍ.", "Wir sahen die Wirklichkeit mit klarem Auge.", [("نَظَرْنَا", "wir sahen"), ("إِلَى", "auf"), ("الْوَاقِعِ", "die Wirklichkeit"), ("بِعَيْنٍ", "mit Auge"), ("وَاضِحَةٍ", "klarem")]),
    (1210, "الْمَلِكَةُ تَحْكُمُ بِعَدْلٍ.", "Die Königin regiert mit Gerechtigkeit.", [("الْمَلِكَةُ", "die Königin"), ("تَحْكُمُ", "regiert"), ("بِعَدْلٍ", "mit Gerechtigkeit")]),
    (1210, "مَلِكَةُ الْجَمَالِ تُوِّجَتْ فِي الْمُسَابَقَةِ.", "Die Schönheitskönigin wurde im Wettbewerb gekrönt.", [("مَلِكَةُ", "die Königin"), ("الْجَمَالِ", "der Schönheit"), ("تُوِّجَتْ", "wurde gekrönt"), ("فِي", "im"), ("الْمُسَابَقَةِ", "Wettbewerb")]),
    (1211, "الْأَمِيرُ قَادَ الْجُنُودَ فِي الْحَرْبِ.", "Der Prinz führte die Soldaten im Krieg.", [("الْأَمِيرُ", "der Prinz"), ("قَادَ", "führte"), ("الْجُنُودَ", "die Soldaten"), ("فِي", "im"), ("الْحَرْبِ", "Krieg")]),
    (1211, "أَمِيرُ الْبَلَدِ حَكِيمٌ.", "Der Fürst des Landes ist weise.", [("أَمِيرُ", "der Fürst"), ("الْبَلَدِ", "des Landes"), ("حَكِيمٌ", "ist weise")]),
    (1211, "تَلَقَّى الْأَمِيرُ الضُّيُوفَ فِي الْقَصْرِ.", "Der Prinz empfing die Gäste im Palast.", [("تَلَقَّى", "empfing"), ("الْأَمِيرُ", "der Prinz"), ("الضُّيُوفَ", "die Gäste"), ("فِي", "im"), ("الْقَصْرِ", "Palast")]),
    (1212, "الْمَعْرَكَةُ كَانَتْ شَدِيدَةً فِي الْحَرْبِ.", "Die Schlacht war heftig im Krieg.", [("الْمَعْرَكَةُ", "die Schlacht"), ("كَانَتْ", "war"), ("شَدِيدَةً", "heftig"), ("فِي", "im"), ("الْحَرْبِ", "Krieg")]),
    (1212, "مَعْرَكَةُ الْفُصُولِ قَرِيبَةٌ.", "Die Schlacht der Jahreszeiten ist nah.", [("مَعْرَكَةُ", "die Schlacht"), ("الْفُصُولِ", "der Jahreszeiten"), ("قَرِيبَةٌ", "ist nah")]),
    (1212, "انْتَهَتِ الْمَعْرَكَةُ بِالنَّصْرِ فِي الصَّبَاحِ.", "Die Schlacht endete am Morgen mit dem Sieg.", [("انْتَهَتِ", "endete"), ("الْمَعْرَكَةُ", "die Schlacht"), ("بِالنَّصْرِ", "mit dem Sieg"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1213, "الْهَزِيمَةُ مُحْزِنَةٌ لِلْجَيْشِ.", "Die Niederlage ist für die Armee traurig.", [("الْهَزِيمَةُ", "die Niederlage"), ("مُحْزِنَةٌ", "ist traurig"), ("لِلْجَيْشِ", "für die Armee")]),
    (1213, "هَزِيمَةُ الْفَرِيقِ فِي الْمُبَارَاةِ وَاضِحَةٌ.", "Die Niederlage der Mannschaft im Spiel ist deutlich.", [("هَزِيمَةُ", "die Niederlage"), ("الْفَرِيقِ", "der Mannschaft"), ("فِي", "im"), ("الْمُبَارَاةِ", "Spiel"), ("وَاضِحَةٌ", "ist deutlich")]),
    (1213, "قَبِلَ الْجُنُودُ الْهَزِيمَةَ بِصَبْرٍ.", "Die Soldaten nahmen die Niederlage mit Geduld hin.", [("قَبِلَ", "nahmen hin"), ("الْجُنُودُ", "die Soldaten"), ("الْهَزِيمَةَ", "die Niederlage"), ("بِصَبْرٍ", "mit Geduld")]),
    (1214, "الْخَطَرُ كَبِيرٌ فِي الرِّحْلَةِ الْجَبَلِيَّةِ.", "Die Gefahr ist groß auf der Bergreise.", [("الْخَطَرُ", "die Gefahr"), ("كَبِيرٌ", "ist groß"), ("فِي", "auf"), ("الرِّحْلَةِ", "der Reise"), ("الْجَبَلِيَّةِ", "Berg-")]),
    (1214, "خَطَرُ الْحَرِيقِ مُهَدِّدٌ فِي الصَّيْفِ.", "Die Brandgefahr ist im Sommer bedrohlich.", [("خَطَرُ", "die Gefahr"), ("الْحَرِيقِ", "des Feuers"), ("مُهَدِّدٌ", "ist bedrohlich"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1214, "تَجَنَّبْنَا الْخَطَرَ فِي الطَّرِيقِ.", "Wir vermieden die Gefahr auf der Straße.", [("تَجَنَّبْنَا", "wir vermieden"), ("الْخَطَرَ", "die Gefahr"), ("فِي", "auf"), ("الطَّرِيقِ", "der Straße")]),
    (1215, "الشَّرِكَةُ كَبِيرَةٌ فِي الْمَدِينَةِ.", "Die Firma ist groß in der Stadt.", [("الشَّرِكَةُ", "die Firma"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1215, "شَرِكَةُ التِّجَارَةِ نَاجِحَةٌ.", "Die Handelsfirma ist erfolgreich.", [("شَرِكَةُ", "die Firma"), ("التِّجَارَةِ", "des Handels"), ("نَاجِحَةٌ", "ist erfolgreich")]),
    (1216, "الْمَتَاعُ غَالٍ فِي السُّوقِ الْيَوْمَ.", "Die Ware ist heute teuer auf dem Markt.", [("الْمَتَاعُ", "die Ware"), ("غَالٍ", "ist teuer"), ("فِي", "auf"), ("السُّوقِ", "dem Markt"), ("الْيَوْمَ", "heute")]),
    (1216, "مَتَاعُ الْبَيْتِ قَدِيمٌ.", "Das Hab und Gut des Hauses ist alt.", [("مَتَاعُ", "das Hab und Gut"), ("الْبَيْتِ", "des Hauses"), ("قَدِيمٌ", "ist alt")]),
    (1216, "اشْتَرَيْنَا الْمَتَاعَ مِنَ الْبَلَدِ الْبَعِيدِ.", "Wir kauften die Ware aus dem fernen Land.", [("اشْتَرَيْنَا", "wir kauften"), ("الْمَتَاعَ", "die Ware"), ("مِنَ", "aus"), ("الْبَلَدِ", "dem Land"), ("الْبَعِيدِ", "fernen")]),
    (1217, "الْبَضَائِعُ وَاصِلَةٌ فِي السُّوقِ.", "Die Waren sind auf dem Markt angekommen.", [("الْبَضَائِعُ", "die Waren"), ("وَاصِلَةٌ", "sind angekommen"), ("فِي", "auf"), ("السُّوقِ", "dem Markt")]),
    (1217, "بَضَائِعُ الشَّرِكَةِ كَثِيرَةٌ.", "Die Waren der Firma sind zahlreich.", [("بَضَائِعُ", "die Waren"), ("الشَّرِكَةِ", "der Firma"), ("كَثِيرَةٌ", "sind zahlreich")]),
    (1217, "وَرَدَتِ الْبَضَائِعُ مِنَ الْمِينَاءِ.", "Die Waren kamen aus dem Hafen an.", [("وَرَدَتِ", "kamen an"), ("الْبَضَائِعُ", "die Waren"), ("مِنَ", "aus"), ("الْمِينَاءِ", "dem Hafen")]),
    (1218, "الْخَسَارَةُ كَبِيرَةٌ فِي التِّجَارَةِ.", "Der Verlust ist groß im Handel.", [("الْخَسَارَةُ", "der Verlust"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "im"), ("التِّجَارَةِ", "Handel")]),
    (1218, "خَسَارَةُ الشَّرِكَةِ وَاضِحَةٌ هَذَا الْعَامَ.", "Der Verlust der Firma ist dieses Jahr deutlich.", [("خَسَارَةُ", "der Verlust"), ("الشَّرِكَةِ", "der Firma"), ("وَاضِحَةٌ", "ist deutlich"), ("هَذَا", "dieses"), ("الْعَامَ", "Jahr")]),
    (1218, "تَكَبَّدْنَا خَسَارَةً فِي الْمَشْرُوعِ.", "Wir erlitten einen Verlust im Projekt.", [("تَكَبَّدْنَا", "wir erlitten"), ("خَسَارَةً", "einen Verlust"), ("فِي", "im"), ("الْمَشْرُوعِ", "Projekt")]),
    (1219, "الْإِيجَارُ غَالٍ فِي الْمَدِينَةِ الْكَبِيرَةِ.", "Die Miete ist teuer in der großen Stadt.", [("الْإِيجَارُ", "die Miete"), ("غَالٍ", "ist teuer"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt"), ("الْكَبِيرَةِ", "großen")]),
    (1219, "إِيجَارُ الْبَيْتِ يُدْفَعُ كُلَّ شَهْرٍ.", "Die Miete des Hauses wird jeden Monat bezahlt.", [("إِيجَارُ", "die Miete"), ("الْبَيْتِ", "des Hauses"), ("يُدْفَعُ", "wird bezahlt"), ("كُلَّ", "jeden"), ("شَهْرٍ", "Monat")]),
    (1219, "دَفَعْنَا الْإِيجَارَ فِي الْوَقْتِ.", "Wir zahlten die Miete rechtzeitig.", [("دَفَعْنَا", "wir zahlten"), ("الْإِيجَارَ", "die Miete"), ("فِي", "zur"), ("الْوَقْتِ", "Zeit")]),
    (1220, "الْبَضَاعَةُ جَيِّدَةٌ فِي الْمَحَلِّ.", "Die Ware ist gut im Laden.", [("الْبَضَاعَةُ", "die Ware"), ("جَيِّدَةٌ", "ist gut"), ("فِي", "im"), ("الْمَحَلِّ", "Laden")]),
    (1220, "بَضَاعَةُ السُّوقِ مَعْرُوفَةٌ بِجَوْدَتِهَا.", "Die Marktware ist für ihre Qualität bekannt.", [("بَضَاعَةُ", "die Ware"), ("السُّوقِ", "des Marktes"), ("مَعْرُوفَةٌ", "ist bekannt"), ("بِجَوْدَتِهَا", "für ihre Qualität")]),
    (1221, "الْمِيزَانِيَّةُ مُوَازَنَةٌ فِي الْحُكُومَةِ.", "Der Haushalt ist in der Regierung ausgeglichen.", [("الْمِيزَانِيَّةُ", "der Haushalt"), ("مُوَازَنَةٌ", "ist ausgeglichen"), ("فِي", "in"), ("الْحُكُومَةِ", "der Regierung")]),
    (1221, "مِيزَانِيَّةُ الدَّوْلَةِ كَبِيرَةٌ هَذَا الْعَامَ.", "Der Staatshaushalt ist dieses Jahr groß.", [("مِيزَانِيَّةُ", "der Haushalt"), ("الدَّوْلَةِ", "des Staates"), ("كَبِيرَةٌ", "ist groß"), ("هَذَا", "dieses"), ("الْعَامَ", "Jahr")]),
    (1221, "نَاقَشَ الْمَجْلِسُ الْمِيزَانِيَّةَ فِي الِاجْتِمَاعِ.", "Das Parlament besprach den Haushalt in der Sitzung.", [("نَاقَشَ", "besprach"), ("الْمَجْلِسُ", "das Parlament"), ("الْمِيزَانِيَّةَ", "den Haushalt"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1222, "الضَّرِيبَةُ عَالِيَةٌ فِي الْبِلَادِ.", "Die Steuer ist im Land hoch.", [("الضَّرِيبَةُ", "die Steuer"), ("عَالِيَةٌ", "ist hoch"), ("فِي", "im"), ("الْبِلَادِ", "Land")]),
    (1222, "ضَرِيبَةُ الدَّخْلِ تُدْفَعُ سَنَوِيًّا.", "Die Einkommenssteuer wird jährlich gezahlt.", [("ضَرِيبَةُ", "die Steuer"), ("الدَّخْلِ", "des Einkommens"), ("تُدْفَعُ", "wird gezahlt"), ("سَنَوِيًّا", "jährlich")]),
    (1222, "دَفَعَ الْمُوَاطِنُ الضَّرِيبَةَ إِلَى الدَّوْلَةِ.", "Der Bürger zahlte die Steuer an den Staat.", [("دَفَعَ", "zahlte"), ("الْمُوَاطِنُ", "der Bürger"), ("الضَّرِيبَةَ", "die Steuer"), ("إِلَى", "an"), ("الدَّوْلَةِ", "den Staat")]),
    (1223, "الْمَحْفَظَةُ مَلِيئَةٌ بِالنُّقُودِ.", "Die Brieftasche ist voll mit Geld.", [("الْمَحْفَظَةُ", "die Brieftasche"), ("مَلِيئَةٌ", "ist voll"), ("بِالنُّقُودِ", "mit Geld")]),
    (1223, "مَحْفَظَةُ الرَّجُلِ جَدِيدَةٌ.", "Die Brieftasche des Mannes ist neu.", [("مَحْفَظَةُ", "die Brieftasche"), ("الرَّجُلِ", "des Mannes"), ("جَدِيدَةٌ", "ist neu")]),
    (1223, "وَضَعَ الرَّجُلُ الْمَحْفَظَةَ فِي جَيْبِهِ.", "Der Mann steckte die Brieftasche in seine Tasche.", [("وَضَعَ", "steckte"), ("الرَّجُلُ", "der Mann"), ("الْمَحْفَظَةَ", "die Brieftasche"), ("فِي", "in"), ("جَيْبِهِ", "seine Tasche")]),
    (1224, "السُّبْحَةُ جَمِيلَةٌ فِي الْيَدِ.", "Die Perlenkette ist schön an der Hand.", [("السُّبْحَةُ", "die Perlenkette"), ("جَمِيلَةٌ", "ist schön"), ("فِي", "an"), ("الْيَدِ", "der Hand")]),
    (1224, "سُبْحَةُ الْجَدِّ قَدِيمَةٌ وَثَمِينَةٌ.", "Die Perlenkette des Großvaters ist alt und wertvoll.", [("سُبْحَةُ", "die Perlenkette"), ("الْجَدِّ", "des Großvaters"), ("قَدِيمَةٌ", "ist alt"), ("وَثَمِينَةٌ", "und wertvoll")]),
    (1224, "أَخَذَ الرَّجُلُ السُّبْحَةَ بِيَدِهِ.", "Der Mann nahm die Perlenkette in seine Hand.", [("أَخَذَ", "nahm"), ("الرَّجُلُ", "der Mann"), ("السُّبْحَةَ", "die Perlenkette"), ("بِيَدِهِ", "in seine Hand")]),
    (1225, "الْمَجَالُ وَاسِعٌ فِي الْعِلْمِ.", "Das Feld ist weit in der Wissenschaft.", [("الْمَجَالُ", "das Feld"), ("وَاسِعٌ", "ist weit"), ("فِي", "in"), ("الْعِلْمِ", "der Wissenschaft")]),
    (1225, "مَجَالُ الْعَمَلِ كَبِيرٌ فِي الْمَدِينَةِ.", "Das Arbeitsfeld ist groß in der Stadt.", [("مَجَالُ", "das Feld"), ("الْعَمَلِ", "der Arbeit"), ("كَبِيرٌ", "ist groß"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1226, "النِّظَامُ وَاضِحٌ فِي الْمَدْرَسَةِ.", "Die Ordnung ist klar in der Schule.", [("النِّظَامُ", "die Ordnung"), ("وَاضِحٌ", "ist klar"), ("فِي", "in"), ("الْمَدْرَسَةِ", "der Schule")]),
    (1226, "نِظَامُ الْبَلَدِ قَوِيٌّ.", "Das System des Landes ist stark.", [("نِظَامُ", "das System"), ("الْبَلَدِ", "des Landes"), ("قَوِيٌّ", "ist stark")]),
    (1226, "اتَّبَعْنَا النِّظَامَ فِي الْعَمَلِ.", "Wir befolgten die Ordnung bei der Arbeit.", [("اتَّبَعْنَا", "wir befolgten"), ("النِّظَامَ", "die Ordnung"), ("فِي", "bei"), ("الْعَمَلِ", "der Arbeit")]),
    (1227, "الْمُؤَسَّسَةُ كَبِيرَةٌ فِي الْمَدِينَةِ.", "Die Institution ist groß in der Stadt.", [("الْمُؤَسَّسَةُ", "die Institution"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1227, "مُؤَسَّسَةُ التَّعْلِيمِ مُهِمَّةٌ.", "Die Bildungsinstitution ist wichtig.", [("مُؤَسَّسَةُ", "die Institution"), ("التَّعْلِيمِ", "der Bildung"), ("مُهِمَّةٌ", "ist wichtig")]),
    (1227, "أَسَّسَ الرَّجُلُ مُؤَسَّسَةً لِلْخَيْرِ.", "Der Mann gründete eine Stiftung für das Gute.", [("أَسَّسَ", "gründete"), ("الرَّجُلُ", "der Mann"), ("مُؤَسَّسَةً", "eine Stiftung"), ("لِلْخَيْرِ", "für das Gute")]),
    (1228, "الْهَيْئَةُ تَدِيرُ الْأُمُورَ فِي الْبَلَدِ.", "Die Behörde verwaltet die Angelegenheiten im Land.", [("الْهَيْئَةُ", "die Behörde"), ("تَدِيرُ", "verwaltet"), ("الْأُمُورَ", "die Angelegenheiten"), ("فِي", "im"), ("الْبَلَدِ", "Land")]),
    (1228, "هَيْئَةُ التَّدْرِيسِ قَرِيبَةٌ مِنَ السُّوقِ.", "Die Lehranstalt ist in der Nähe des Marktes.", [("هَيْئَةُ", "die Einrichtung"), ("التَّدْرِيسِ", "des Unterrichts"), ("قَرِيبَةٌ", "ist in der Nähe"), ("مِنَ", "von"), ("السُّوقِ", "dem Markt")]),
    (1228, "اجْتَمَعَتِ الْهَيْئَةُ فِي الْقَاعَةِ.", "Die Kommission versammelte sich im Saal.", [("اجْتَمَعَتِ", "versammelte sich"), ("الْهَيْئَةُ", "die Kommission"), ("فِي", "im"), ("الْقَاعَةِ", "Saal")]),
    (1229, "السُّفَارَةُ قَرِيبَةٌ مِنْ قَصْرِ الْمَلِكِ.", "Die Botschaft ist in der Nähe des Königspalastes.", [("السُّفَارَةُ", "die Botschaft"), ("قَرِيبَةٌ", "ist in der Nähe"), ("مِنْ", "von"), ("قَصْرِ", "dem Palast"), ("الْمَلِكِ", "des Königs")]),
    (1229, "سُفَارَةُ بِلَادِنَا جَدِيدَةٌ فِي الْمَدِينَةِ.", "Die Botschaft unseres Landes ist neu in der Stadt.", [("سُفَارَةُ", "die Botschaft"), ("بِلَادِنَا", "unseres Landes"), ("جَدِيدَةٌ", "ist neu"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1229, "زَارَ السَّفِيرُ السُّفَارَةَ فِي الصَّبَاحِ.", "Der Botschafter besuchte am Morgen die Botschaft.", [("زَارَ", "besuchte"), ("السَّفِيرُ", "der Botschafter"), ("السُّفَارَةَ", "die Botschaft"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1230, "الْجَمْعِيَّةُ تَعْمَلُ لِلْفُقَرَاءِ.", "Der Verein arbeitet für die Armen.", [("الْجَمْعِيَّةُ", "der Verein"), ("تَعْمَلُ", "arbeitet"), ("لِلْفُقَرَاءِ", "für die Armen")]),
    (1230, "جَمْعِيَّةُ الْحَيِّ نَشِيطَةٌ.", "Der Stadtteilverein ist aktiv.", [("جَمْعِيَّةُ", "der Verein"), ("الْحَيِّ", "des Viertels"), ("نَشِيطَةٌ", "ist aktiv")]),
    (1231, "النِّقَابَةُ تَدْفَعُ عَنِ الْعُمَّالِ.", "Die Gewerkschaft tritt für die Arbeiter ein.", [("النِّقَابَةُ", "die Gewerkschaft"), ("تَدْفَعُ", "tritt ein"), ("عَنِ", "für"), ("الْعُمَّالِ", "die Arbeiter")]),
    (1231, "نِقَابَةُ الْمُعَلِّمِينَ كَبِيرَةٌ.", "Die Lehrer-Gewerkschaft ist groß.", [("نِقَابَةُ", "die Gewerkschaft"), ("الْمُعَلِّمِينَ", "der Lehrer"), ("كَبِيرَةٌ", "ist groß")]),
    (1231, "اِنْضَمَّ الْعَامِلُ إِلَى النِّقَابَةِ.", "Der Arbeiter schloss sich der Gewerkschaft an.", [("اِنْضَمَّ", "schloss sich an"), ("الْعَامِلُ", "der Arbeiter"), ("إِلَى", "der"), ("النِّقَابَةِ", "Gewerkschaft")]),
    (1232, "الْحِزْبُ يَفُوزُ فِي الِانْتِخَابَاتِ.", "Die Partei gewinnt bei den Wahlen.", [("الْحِزْبُ", "die Partei"), ("يَفُوزُ", "gewinnt"), ("فِي", "bei"), ("الِانْتِخَابَاتِ", "den Wahlen")]),
    (1232, "حِزْبُ الْعُمَّالِ قَدِيمٌ فِي الْبَلَدِ.", "Die Arbeiterpartei ist alt im Land.", [("حِزْبُ", "die Partei"), ("الْعُمَّالِ", "der Arbeiter"), ("قَدِيمٌ", "ist alt"), ("فِي", "im"), ("الْبَلَدِ", "Land")]),
    (1232, "اِنْتَخَبَ النَّاسُ الْحِزْبَ الْجَدِيدَ.", "Die Menschen wählten die neue Partei.", [("اِنْتَخَبَ", "wählten"), ("النَّاسُ", "die Menschen"), ("الْحِزْبَ", "die Partei"), ("الْجَدِيدَ", "neue")]),
    (1233, "الِانْتِخَابَاتُ قَرِيبَةٌ فِي الْبَلَدِ.", "Die Wahlen sind im Land nah.", [("الِانْتِخَابَاتُ", "die Wahlen"), ("قَرِيبَةٌ", "sind nah"), ("فِي", "im"), ("الْبَلَدِ", "Land")]),
    (1233, "اِنْتِخَابَاتُ الْبَرْلَمَانِ مَهَمَّةٌ.", "Die Parlamentswahlen sind wichtig.", [("اِنْتِخَابَاتُ", "die Wahlen"), ("الْبَرْلَمَانِ", "des Parlaments"), ("مَهَمَّةٌ", "sind wichtig")]),
    (1233, "تَلَتِ الِانْتِخَابَاتُ فِي الرَّبِيعِ.", "Die Wahlen fanden im Frühling statt.", [("تَلَتِ", "fanden statt"), ("الِانْتِخَابَاتُ", "die Wahlen"), ("فِي", "im"), ("الرَّبِيعِ", "Frühling")]),
    (1234, "التَّصْوِيتُ وَاضِحٌ فِي الِاجْتِمَاعِ.", "Die Abstimmung ist in der Sitzung klar.", [("التَّصْوِيتُ", "die Abstimmung"), ("وَاضِحٌ", "ist klar"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1234, "تَصْوِيتُ الشَّعْبِ مُهِمٌّ فِي الدِّيمُقْرَاطِيَّةِ.", "Die Abstimmung des Volkes ist wichtig in der Demokratie.", [("تَصْوِيتُ", "die Abstimmung"), ("الشَّعْبِ", "des Volkes"), ("مُهِمٌّ", "ist wichtig"), ("فِي", "in"), ("الدِّيمُقْرَاطِيَّةِ", "der Demokratie")]),
    (1234, "اِنْتَهَى التَّصْوِيتُ فِي الْمَسَاءِ.", "Die Abstimmung endete am Abend.", [("اِنْتَهَى", "endete"), ("التَّصْوِيتُ", "die Abstimmung"), ("فِي", "am"), ("الْمَسَاءِ", "Abend")]),
    (1235, "الْمُرَشَّحُ جَيِّدٌ فِي الِانْتِخَابَاتِ.", "Der Kandidat ist gut bei den Wahlen.", [("الْمُرَشَّحُ", "der Kandidat"), ("جَيِّدٌ", "ist gut"), ("فِي", "bei"), ("الِانْتِخَابَاتِ", "den Wahlen")]),
    (1235, "مُرَشَّحُ الْحِزْبِ مَعْرُوفٌ.", "Der Kandidat der Partei ist bekannt.", [("مُرَشَّحُ", "der Kandidat"), ("الْحِزْبِ", "der Partei"), ("مَعْرُوفٌ", "ist bekannt")]),
    (1236, "السِّيَاسَةُ تُدِيرُ أُمُورَ الْبَلَدِ.", "Die Politik verwaltet die Angelegenheiten des Landes.", [("السِّيَاسَةُ", "die Politik"), ("تُدِيرُ", "verwaltet"), ("أُمُورَ", "die Angelegenheiten"), ("الْبَلَدِ", "des Landes")]),
    (1236, "سِيَاسَةُ الْحُكُومَةِ وَاضِحَةٌ.", "Die Politik der Regierung ist klar.", [("سِيَاسَةُ", "die Politik"), ("الْحُكُومَةِ", "der Regierung"), ("وَاضِحَةٌ", "ist klar")]),
    (1236, "نُقَاشُ السِّيَاسَةِ فِي الْمَجْلِسِ.", "Die Diskussion der Politik ist im Parlament.", [("نُقَاشُ", "die Diskussion"), ("السِّيَاسَةِ", "der Politik"), ("فِي", "im"), ("الْمَجْلِسِ", "Parlament")]),
    (1237, "الْقَضِيَّةُ مُعَقَّدَةٌ فِي الْمَحْكَمَةِ.", "Der Fall ist kompliziert vor Gericht.", [("الْقَضِيَّةُ", "der Fall"), ("مُعَقَّدَةٌ", "ist kompliziert"), ("فِي", "vor"), ("الْمَحْكَمَةِ", "Gericht")]),
    (1237, "قَضِيَّةُ الْعَامِلِ وَاضِحَةٌ.", "Die Sache des Arbeiters ist klar.", [("قَضِيَّةُ", "die Sache"), ("الْعَامِلِ", "des Arbeiters"), ("وَاضِحَةٌ", "ist klar")]),
    (1237, "بَحَثَ الْقَاضِي الْقَضِيَّةَ بِدِقَّةٍ.", "Der Richter prüfte den Fall genau.", [("بَحَثَ", "prüfte"), ("الْقَاضِي", "der Richter"), ("الْقَضِيَّةَ", "den Fall"), ("بِدِقَّةٍ", "genau")]),
    (1238, "الْمُحَافَظَةُ كَبِيرَةٌ فِي الشَّرْقِ.", "Das Gouvernement ist groß im Osten.", [("الْمُحَافَظَةُ", "das Gouvernement"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "im"), ("الشَّرْقِ", "Osten")]),
    (1238, "مُحَافَظَةُ الْقَاهِرَةِ مَشْهُورَةٌ.", "Das Gouvernement Kairo ist berühmt.", [("مُحَافَظَةُ", "das Gouvernement"), ("الْقَاهِرَةِ", "von Kairo"), ("مَشْهُورَةٌ", "ist berühmt")]),
    (1238, "زُرْنَا الْمُحَافَظَةَ فِي الصَّيْفِ.", "Wir besuchten das Gouvernement im Sommer.", [("زُرْنَا", "wir besuchten"), ("الْمُحَافَظَةَ", "das Gouvernement"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1239, "الْجِوَارُ صَالِحٌ بَيْنَ الْعَائِلَتَيْنِ.", "Die Nachbarschaft ist gut zwischen den beiden Familien.", [("الْجِوَارُ", "die Nachbarschaft"), ("صَالِحٌ", "ist gut"), ("بَيْنَ", "zwischen"), ("الْعَائِلَتَيْنِ", "den beiden Familien")]),
    (1239, "جِوَارُ الْبَيْتِ هَادِئٌ.", "Die Nachbarschaft des Hauses ist ruhig.", [("جِوَارُ", "die Nachbarschaft"), ("الْبَيْتِ", "des Hauses"), ("هَادِئٌ", "ist ruhig")]),
    (1239, "نَتَعَامَلُ بِالْجِوَارِ مَعَ الْجِيرَانِ.", "Wir pflegen die Nachbarschaft mit den Nachbarn.", [("نَتَعَامَلُ", "wir pflegen"), ("بِالْجِوَارِ", "die Nachbarschaft"), ("مَعَ", "mit"), ("الْجِيرَانِ", "den Nachbarn")]),
    (1240, "الْحَارَةُ قَدِيمَةٌ فِي الْمَدِينَةِ.", "Das Viertel ist alt in der Stadt.", [("الْحَارَةُ", "das Viertel"), ("قَدِيمَةٌ", "ist alt"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1240, "حَارَةُ السُّوقِ مَعْرُوفَةٌ.", "Das Marktviertel ist bekannt.", [("حَارَةُ", "das Viertel"), ("السُّوقِ", "des Marktes"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1241, "الْفَتْرَةُ قَصِيرَةٌ فِي الْعَامِ.", "Der Zeitraum ist kurz im Jahr.", [("الْفَتْرَةُ", "der Zeitraum"), ("قَصِيرَةٌ", "ist kurz"), ("فِي", "im"), ("الْعَامِ", "Jahr")]),
    (1241, "فَتْرَةُ الِانْتِظَارِ طَوِيلَةٌ.", "Die Wartezeit ist lang.", [("فَتْرَةُ", "die Zeit"), ("الِانْتِظَارِ", "des Wartens"), ("طَوِيلَةٌ", "ist lang")]),
    (1241, "قَضَيْنَا فَتْرَةً جَمِيلَةً فِي الْجَبَلِ.", "Wir verbrachten eine schöne Zeit im Gebirge.", [("قَضَيْنَا", "wir verbrachten"), ("فَتْرَةً", "eine Zeit"), ("جَمِيلَةً", "schöne"), ("فِي", "im"), ("الْجَبَلِ", "Gebirge")]),
    (1242, "الْمُدَّةُ كَافِيَةٌ لِإِنْهَاءِ الْعَمَلِ.", "Die Dauer ist zum Beenden der Arbeit ausreichend.", [("الْمُدَّةُ", "die Dauer"), ("كَافِيَةٌ", "ist ausreichend"), ("لِإِنْهَاءِ", "zum Beenden"), ("الْعَمَلِ", "der Arbeit")]),
    (1242, "مُدَّةُ السَّفَرِ ثَلَاثَةُ أَيَّامٍ.", "Die Reisedauer beträgt drei Tage.", [("مُدَّةُ", "die Dauer"), ("السَّفَرِ", "der Reise"), ("ثَلَاثَةُ", "drei"), ("أَيَّامٍ", "Tage")]),
    (1242, "حَدَّدْنَا الْمُدَّةَ فِي الْعَقْدِ.", "Wir legten die Dauer im Vertrag fest.", [("حَدَّدْنَا", "wir legten fest"), ("الْمُدَّةَ", "die Dauer"), ("فِي", "im"), ("الْعَقْدِ", "Vertrag")]),
    (1243, "الْمِصْدَاقُ مُتْلَفٌ فِي الْمَسْأَلَةِ.", "Die Bestätigung ist in der Angelegenheit erbracht.", [("الْمِصْدَاقُ", "die Bestätigung"), ("مُتْلَفٌ", "ist erbracht"), ("فِي", "in"), ("الْمَسْأَلَةِ", "der Angelegenheit")]),
    (1243, "مِصْدَاقُ كَلَامِهِ فِعْلُهُ.", "Die Bestätigung seiner Rede ist seine Tat.", [("مِصْدَاقُ", "die Bestätigung"), ("كَلَامِهِ", "seiner Rede"), ("فِعْلُهُ", "ist seine Tat")]),
    (1243, "ذَكَرْنَا الْمِصْدَاقَ فِي الْبَحْثِ.", "Wir nannten die Bestätigung in der Forschung.", [("ذَكَرْنَا", "wir nannten"), ("الْمِصْدَاقَ", "die Bestätigung"), ("فِي", "in"), ("الْبَحْثِ", "der Forschung")]),
    (1244, "الدَّوْرُ مُهِمٌّ فِي الْمَسْرَحِيَّةِ.", "Die Rolle ist wichtig im Theaterstück.", [("الدَّوْرُ", "die Rolle"), ("مُهِمٌّ", "ist wichtig"), ("فِي", "im"), ("الْمَسْرَحِيَّةِ", "Theaterstück")]),
    (1244, "دَوْرُ الْمُوَظَّفِ وَاضِحٌ فِي الشَّرِكَةِ.", "Die Rolle des Angestellten ist in der Firma klar.", [("دَوْرُ", "die Rolle"), ("الْمُوَظَّفِ", "des Angestellten"), ("وَاضِحٌ", "ist klar"), ("فِي", "in"), ("الشَّرِكَةِ", "der Firma")]),
    (1244, "لَعِبَ الْمُمَثِّلُ دَوْرًا كَبِيرًا.", "Der Schauspieler spielte eine große Rolle.", [("لَعِبَ", "spielte"), ("الْمُمَثِّلُ", "der Schauspieler"), ("دَوْرًا", "eine Rolle"), ("كَبِيرًا", "große")]),
    (1245, "الْمَسْؤُولِيَّةُ كَبِيرَةٌ عَلَى الْمُدِيرِ.", "Die Verantwortung ist groß für den Direktor.", [("الْمَسْؤُولِيَّةُ", "die Verantwortung"), ("كَبِيرَةٌ", "ist groß"), ("عَلَى", "für"), ("الْمُدِيرِ", "den Direktor")]),
    (1245, "مَسْؤُولِيَّةُ الْآبَاءِ فِي التَّرْبِيَةِ.", "Die Verantwortung der Eltern liegt in der Erziehung.", [("مَسْؤُولِيَّةُ", "die Verantwortung"), ("الْآبَاءِ", "der Eltern"), ("فِي", "in"), ("التَّرْبِيَةِ", "der Erziehung")]),
    (1246, "الْإِمْكَانُ مَوْجُودٌ لِلتَّعَلُّمِ.", "Die Möglichkeit ist zum Lernen vorhanden.", [("الْإِمْكَانُ", "die Möglichkeit"), ("مَوْجُودٌ", "ist vorhanden"), ("لِلتَّعَلُّمِ", "zum Lernen")]),
    (1246, "إِمْكَانُ السَّفَرِ قَرِيبٌ.", "Die Reisemöglichkeit ist nah.", [("إِمْكَانُ", "die Möglichkeit"), ("السَّفَرِ", "der Reise"), ("قَرِيبٌ", "ist nah")]),
    (1246, "ذَكَرَ الْإِمْكَانَ فِي الْخِطَابِ.", "Er erwähnte die Möglichkeit in der Rede.", [("ذَكَرَ", "erwähnte"), ("الْإِمْكَانَ", "die Möglichkeit"), ("فِي", "in"), ("الْخِطَابِ", "der Rede")]),
    (1247, "الْقُدْرَةُ كَبِيرَةٌ فِي الْعَمَلِ.", "Das Können ist groß bei der Arbeit.", [("الْقُدْرَةُ", "das Können"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "bei"), ("الْعَمَلِ", "der Arbeit")]),
    (1247, "قُدْرَةُ الْجَيْشِ قَوِيَّةٌ.", "Die Fähigkeit der Armee ist stark.", [("قُدْرَةُ", "die Fähigkeit"), ("الْجَيْشِ", "der Armee"), ("قَوِيَّةٌ", "ist stark")]),
    (1247, "زَادَتِ الْقُدْرَةُ بَعْدَ التَّدْرِيبِ.", "Das Können nahm nach dem Training zu.", [("زَادَتِ", "nahm zu"), ("الْقُدْرَةُ", "das Können"), ("بَعْدَ", "nach"), ("التَّدْرِيبِ", "dem Training")]),
    (1248, "الْمَقْدِرَةُ وَاسِعَةٌ فِي الْمُؤَسَّسَةِ.", "Das Vermögen ist weit in der Einrichtung.", [("الْمَقْدِرَةُ", "das Vermögen"), ("وَاسِعَةٌ", "ist weit"), ("فِي", "in"), ("الْمُؤَسَّسَةِ", "der Einrichtung")]),
    (1248, "مَقْدِرَةُ الْعَامِلِ مَعْرُوفَةٌ.", "Die Leistungsfähigkeit des Arbeiters ist bekannt.", [("مَقْدِرَةُ", "die Leistungsfähigkeit"), ("الْعَامِلِ", "des Arbeiters"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1248, "ظَهَرَتِ الْمَقْدِرَةُ فِي الِامْتِحَانِ.", "Das Vermögen zeigte sich in der Prüfung.", [("ظَهَرَتِ", "zeigte sich"), ("الْمَقْدِرَةُ", "das Vermögen"), ("فِي", "in"), ("الِامْتِحَانِ", "der Prüfung")]),
    (1249, "الْمَوَاهِبُ كَثِيرَةٌ عِنْدَ الطِّفْلِ.", "Die Begabungen sind beim Kind zahlreich.", [("الْمَوَاهِبُ", "die Begabungen"), ("كَثِيرَةٌ", "sind zahlreich"), ("عِنْدَ", "bei"), ("الطِّفْلِ", "dem Kind")]),
    (1249, "مَوَاهِبُ الْفَنَّانِ وَاضِحَةٌ.", "Die Begabungen des Künstlers sind deutlich.", [("مَوَاهِبُ", "die Begabungen"), ("الْفَنَّانِ", "des Künstlers"), ("وَاضِحَةٌ", "sind deutlich")]),
    (1249, "نَمَّيْنَا الْمَوَاهِبَ بِالتَّدْرِيبِ.", "Wir förderten die Begabungen durch das Training.", [("نَمَّيْنَا", "wir förderten"), ("الْمَوَاهِبَ", "die Begabungen"), ("بِالتَّدْرِيبِ", "durch das Training")]),
    (1250, "الْمَوْهِبَةُ نَادِرَةٌ فِي النَّاسِ.", "Die Begabung ist unter den Menschen selten.", [("الْمَوْهِبَةُ", "die Begabung"), ("نَادِرَةٌ", "ist selten"), ("فِي", "unter"), ("النَّاسِ", "den Menschen")]),
    (1250, "مَوْهِبَةُ الْقِرَاءَةِ وَاضِحَةٌ عِنْدَهُ.", "Die Lesebegabung ist bei ihm deutlich.", [("مَوْهِبَةُ", "die Begabung"), ("الْقِرَاءَةِ", "des Lesens"), ("وَاضِحَةٌ", "ist deutlich"), ("عِنْدَهُ", "bei ihm")]),
    (1251, "الْمَهَارَةُ مُهِمَّةٌ فِي الْعَمَلِ.", "Die Fertigkeit ist wichtig in der Arbeit.", [("الْمَهَارَةُ", "die Fertigkeit"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "in"), ("الْعَمَلِ", "der Arbeit")]),
    (1251, "مَهَارَةُ الْكِتَابَةِ وَاضِحَةٌ.", "Die Schreibfertigkeit ist deutlich.", [("مَهَارَةُ", "die Fertigkeit"), ("الْكِتَابَةِ", "des Schreibens"), ("وَاضِحَةٌ", "ist deutlich")]),
    (1251, "اِكْتَسَبَ الْمَهَارَةَ بِالتَّدْرِيبِ الْمُسْتَمِرِّ.", "Er erwarb die Fertigkeit durch das ständige Training.", [("اِكْتَسَبَ", "erwarb"), ("الْمَهَارَةَ", "die Fertigkeit"), ("بِالتَّدْرِيبِ", "durch das Training"), ("الْمُسْتَمِرِّ", "ständige")]),
    (1252, "الْمَعْرِفَةُ كَثِيرَةٌ عِنْدَ الْعَالِمِ.", "Das Wissen ist beim Gelehrten groß.", [("الْمَعْرِفَةُ", "das Wissen"), ("كَثِيرَةٌ", "ist groß"), ("عِنْدَ", "beim"), ("الْعَالِمِ", "Gelehrten")]),
    (1252, "مَعْرِفَةُ اللُّغَةِ تَسْهُلُ التَّعَامُلَ.", "Die Kenntnis der Sprache erleichtert den Umgang.", [("مَعْرِفَةُ", "die Kenntnis"), ("اللُّغَةِ", "der Sprache"), ("تَسْهُلُ", "erleichtert"), ("التَّعَامُلَ", "den Umgang")]),
    (1252, "زِدْنَا الْمَعْرِفَةَ بِالْقِرَاءَةِ.", "Wir vermehrten das Wissen durch das Lesen.", [("زِدْنَا", "wir vermehrten"), ("الْمَعْرِفَةَ", "das Wissen"), ("بِالْقِرَاءَةِ", "durch das Lesen")]),
    (1253, "الْمُنَاقَشَةُ مُفِيدَةٌ فِي الدَّرْسِ.", "Die Diskussion ist in der Lektion nützlich.", [("الْمُنَاقَشَةُ", "die Diskussion"), ("مُفِيدَةٌ", "ist nützlich"), ("فِي", "in"), ("الدَّرْسِ", "der Lektion")]),
    (1253, "مُنَاقَشَةُ الْمَوْضُوعِ وَاضِحَةٌ.", "Die Diskussion des Themas ist klar.", [("مُنَاقَشَةُ", "die Diskussion"), ("الْمَوْضُوعِ", "des Themas"), ("وَاضِحَةٌ", "ist klar")]),
    (1253, "نَاقَشْنَا الْمُنَاقَشَةَ فِي الِاجْتِمَاعِ.", "Wir führten die Diskussion in der Sitzung.", [("نَاقَشْنَا", "wir führten"), ("الْمُنَاقَشَةَ", "die Diskussion"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1254, "الْحِوَارُ بَيْنَ الْفَرِيقَيْنِ هَادِئٌ.", "Der Dialog zwischen den beiden Gruppen ist ruhig.", [("الْحِوَارُ", "der Dialog"), ("بَيْنَ", "zwischen"), ("الْفَرِيقَيْنِ", "den beiden Gruppen"), ("هَادِئٌ", "ist ruhig")]),
    (1254, "حِوَارُ الْأَسْرَةِ يُقَوِّي الْعَلَاقَةَ.", "Der Dialog der Familie stärkt die Beziehung.", [("حِوَارُ", "der Dialog"), ("الْأَسْرَةِ", "der Familie"), ("يُقَوِّي", "stärkt"), ("الْعَلَاقَةَ", "die Beziehung")]),
    (1254, "أَحْبَبْنَا الْحِوَارَ فِي الصَّفِّ.", "Wir mochten den Dialog in der Klasse.", [("أَحْبَبْنَا", "wir mochten"), ("الْحِوَارَ", "den Dialog"), ("فِي", "in"), ("الصَّفِّ", "der Klasse")]),
    (1255, "الْقَرَارُ مُهِمٌّ فِي الْمَجْلِسِ.", "Die Entscheidung ist wichtig im Rat.", [("الْقَرَارُ", "die Entscheidung"), ("مُهِمٌّ", "ist wichtig"), ("فِي", "im"), ("الْمَجْلِسِ", "Rat")]),
    (1255, "قَرَارُ الْقَاضِي نِهَائِيٌّ.", "Die Entscheidung des Richters ist endgültig.", [("قَرَارُ", "die Entscheidung"), ("الْقَاضِي", "des Richters"), ("نِهَائِيٌّ", "ist endgültig")]),
    (1256, "الِاقْتِرَاحُ مُنَاسِبٌ لِلْعَمَلِ.", "Der Vorschlag ist für die Arbeit geeignet.", [("الِاقْتِرَاحُ", "der Vorschlag"), ("مُنَاسِبٌ", "ist geeignet"), ("لِلْعَمَلِ", "für die Arbeit")]),
    (1256, "اقْتِرَاحُ الْعَامِلِ جَيِّدٌ.", "Der Vorschlag des Arbeiters ist gut.", [("اقْتِرَاحُ", "der Vorschlag"), ("الْعَامِلِ", "des Arbeiters"), ("جَيِّدٌ", "ist gut")]),
    (1256, "قَبِلَ الْمُدِيرُ الِاقْتِرَاحَ.", "Der Direktor nahm den Vorschlag an.", [("قَبِلَ", "nahm an"), ("الْمُدِيرُ", "der Direktor"), ("الِاقْتِرَاحَ", "den Vorschlag")]),
    (1257, "الْمَقْتَرَحُ مَكْتُوبٌ فِي الْوَرَقَةِ.", "Die Vorlage ist auf dem Blatt geschrieben.", [("الْمَقْتَرَحُ", "die Vorlage"), ("مَكْتُوبٌ", "ist geschrieben"), ("فِي", "auf"), ("الْوَرَقَةِ", "dem Blatt")]),
    (1257, "مَقْتَرَحُ الْقَانُونِ جَدِيدٌ.", "Die Gesetzesvorlage ist neu.", [("مَقْتَرَحُ", "die Vorlage"), ("الْقَانُونِ", "des Gesetzes"), ("جَدِيدٌ", "ist neu")]),
    (1257, "نَاقَشْنَا الْمَقْتَرَحَ فِي الِاجْتِمَاعِ.", "Wir besprachen die Vorlage in der Sitzung.", [("نَاقَشْنَا", "wir besprachen"), ("الْمَقْتَرَحَ", "die Vorlage"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1258, "التَّنْفِيذُ دَقِيقٌ فِي الْمَشْرُوعِ.", "Die Durchführung ist im Projekt präzise.", [("التَّنْفِيذُ", "die Durchführung"), ("دَقِيقٌ", "ist präzise"), ("فِي", "im"), ("الْمَشْرُوعِ", "Projekt")]),
    (1258, "تَنْفِيذُ الْقَرَارِ سَرِيعٌ.", "Die Durchführung der Entscheidung ist schnell.", [("تَنْفِيذُ", "die Durchführung"), ("الْقَرَارِ", "der Entscheidung"), ("سَرِيعٌ", "ist schnell")]),
    (1258, "بَدَأْنَا التَّنْفِيذَ فِي الصَّبَاحِ.", "Wir begannen die Durchführung am Morgen.", [("بَدَأْنَا", "wir begannen"), ("التَّنْفِيذَ", "die Durchführung"), ("فِي", "am"), ("الصَّبَاحِ", "Morgen")]),
    (1259, "التَّنْظِيمُ جَيِّدٌ فِي الْحَفْلَةِ.", "Die Organisation ist gut bei der Feier.", [("التَّنْظِيمُ", "die Organisation"), ("جَيِّدٌ", "ist gut"), ("فِي", "bei"), ("الْحَفْلَةِ", "der Feier")]),
    (1259, "تَنْظِيمُ الْوَقْتِ مُهِمٌّ.", "Die Organisation der Zeit ist wichtig.", [("تَنْظِيمُ", "die Organisation"), ("الْوَقْتِ", "der Zeit"), ("مُهِمٌّ", "ist wichtig")]),
    (1259, "أَكْمَلْنَا التَّنْظِيمَ فِي الْيَوْمِ.", "Wir beendeten die Organisation am Tag.", [("أَكْمَلْنَا", "wir beendeten"), ("التَّنْظِيمَ", "die Organisation"), ("فِي", "am"), ("الْيَوْمِ", "Tag")]),
    (1260, "الْإِدَارَةُ قَوِيَّةٌ فِي الشَّرِكَةِ.", "Die Verwaltung ist in der Firma stark.", [("الْإِدَارَةُ", "die Verwaltung"), ("قَوِيَّةٌ", "ist stark"), ("فِي", "in"), ("الشَّرِكَةِ", "der Firma")]),
    (1260, "إِدَارَةُ الْبَلَدِيَّةِ مَعْرُوفَةٌ.", "Die Verwaltung der Gemeinde ist bekannt.", [("إِدَارَةُ", "die Verwaltung"), ("الْبَلَدِيَّةِ", "der Gemeinde"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1261, "الْمُدِيرُ جَدِيدٌ فِي الشَّرِكَةِ.", "Der Direktor ist neu in der Firma.", [("الْمُدِيرُ", "der Direktor"), ("جَدِيدٌ", "ist neu"), ("فِي", "in"), ("الشَّرِكَةِ", "der Firma")]),
    (1261, "مُدِيرُ الْمَصْنَعِ مُجْتَهِدٌ.", "Der Fabrikdirektor ist fleißig.", [("مُدِيرُ", "der Direktor"), ("الْمَصْنَعِ", "der Fabrik"), ("مُجْتَهِدٌ", "ist fleißig")]),
    (1261, "اِجْتَمَعَ الْمُدِيرُ بِالْعُمَّالِ.", "Der Direktor traf sich mit den Arbeitern.", [("اِجْتَمَعَ", "traf sich"), ("الْمُدِيرُ", "der Direktor"), ("بِالْعُمَّالِ", "mit den Arbeitern")]),
    (1262, "الرِّئَاسَةُ مُهِمَّةٌ فِي الْمَجْلِسِ.", "Der Vorsitz ist wichtig im Rat.", [("الرِّئَاسَةُ", "der Vorsitz"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "im"), ("الْمَجْلِسِ", "Rat")]),
    (1262, "رِئَاسَةُ الْحِزْبِ قَوِيَّةٌ.", "Die Führung der Partei ist stark.", [("رِئَاسَةُ", "die Führung"), ("الْحِزْبِ", "der Partei"), ("قَوِيَّةٌ", "ist stark")]),
    (1262, "تَوَلَّى الرِّئَاسَةَ فِي الِاجْتِمَاعِ.", "Er übernahm den Vorsitz in der Sitzung.", [("تَوَلَّى", "übernahm"), ("الرِّئَاسَةَ", "den Vorsitz"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1263, "الْمَنْصِبُ مُهِمٌّ فِي الدَّوْلَةِ.", "Das Amt ist wichtig im Staat.", [("الْمَنْصِبُ", "das Amt"), ("مُهِمٌّ", "ist wichtig"), ("فِي", "im"), ("الدَّوْلَةِ", "Staat")]),
    (1263, "مَنْصِبُ الْمُدِيرِ رَفِيعٌ.", "Das Amt des Direktors ist hoch.", [("مَنْصِبُ", "das Amt"), ("الْمُدِيرِ", "des Direktors"), ("رَفِيعٌ", "ist hoch")]),
    (1263, "شَغِلَ الرَّجُلُ الْمَنْصِبَ سَنَوَاتٍ.", "Der Mann bekleidete das Amt Jahre lang.", [("شَغِلَ", "bekleidete"), ("الرَّجُلُ", "der Mann"), ("الْمَنْصِبَ", "das Amt"), ("سَنَوَاتٍ", "Jahre lang")]),
    (1264, "النُّقْطَةُ وَاضِحَةٌ عَلَى الْخَرِيطَةِ.", "Der Punkt ist deutlich auf der Karte.", [("النُّقْطَةُ", "der Punkt"), ("وَاضِحَةٌ", "ist deutlich"), ("عَلَى", "auf"), ("الْخَرِيطَةِ", "der Karte")]),
    (1264, "نُقْطَةُ الْبِدَايَةِ مَعْرُوفَةٌ.", "Der Startpunkt ist bekannt.", [("نُقْطَةُ", "der Punkt"), ("الْبِدَايَةِ", "des Anfangs"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1264, "ذَكَرَ النُّقْطَةَ فِي الْخِطَابِ.", "Er erwähnte den Punkt in der Rede.", [("ذَكَرَ", "erwähnte"), ("النُّقْطَةَ", "den Punkt"), ("فِي", "in"), ("الْخِطَابِ", "der Rede")]),
    (1265, "الْأَسَاسُ قَوِيٌّ فِي الْبِنَاءِ.", "Das Fundament ist im Gebäude stark.", [("الْأَسَاسُ", "das Fundament"), ("قَوِيٌّ", "ist stark"), ("فِي", "im"), ("الْبِنَاءِ", "Gebäude")]),
    (1265, "أَسَاسُ الْقَرَارِ وَاضِحٌ.", "Die Grundlage der Entscheidung ist klar.", [("أَسَاسُ", "die Grundlage"), ("الْقَرَارِ", "der Entscheidung"), ("وَاضِحٌ", "ist klar")]),
    (1266, "النِّسْبَةُ وَاضِحَةٌ فِي الْإِحْصَاءِ.", "Der Prozentsatz ist in der Statistik deutlich.", [("النِّسْبَةُ", "der Prozentsatz"), ("وَاضِحَةٌ", "ist deutlich"), ("فِي", "in"), ("الْإِحْصَاءِ", "der Statistik")]),
    (1266, "نِسْبَةُ النَّجَاحِ عَالِيَةٌ.", "Der Erfolgsanteil ist hoch.", [("نِسْبَةُ", "der Anteil"), ("النَّجَاحِ", "des Erfolgs"), ("عَالِيَةٌ", "ist hoch")]),
    (1266, "حَسَبْنَا النِّسْبَةَ بِدِقَّةٍ.", "Wir berechneten den Prozentsatz genau.", [("حَسَبْنَا", "wir berechneten"), ("النِّسْبَةَ", "den Prozentsatz"), ("بِدِقَّةٍ", "genau")]),
    (1267, "التَّطْوِيرُ سَرِيعٌ فِي الْمَدِينَةِ.", "Die Entwicklung ist schnell in der Stadt.", [("التَّطْوِيرُ", "die Entwicklung"), ("سَرِيعٌ", "ist schnell"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1267, "تَطْوِيرُ الْمَشْرُوعِ مُسْتَمِرٌّ.", "Die Entwicklung des Projekts ist stetig.", [("تَطْوِيرُ", "die Entwicklung"), ("الْمَشْرُوعِ", "des Projekts"), ("مُسْتَمِرٌّ", "ist stetig")]),
    (1267, "بَدَأْنَا تَطْوِيرَ الْبَرْنَامَجِ فِي الصَّيْفِ.", "Wir begannen die Entwicklung des Programms im Sommer.", [("بَدَأْنَا", "wir begannen"), ("تَطْوِيرَ", "die Entwicklung"), ("الْبَرْنَامَجِ", "des Programms"), ("فِي", "im"), ("الصَّيْفِ", "Sommer")]),
    (1268, "التَّحْسِينُ وَاضِحٌ فِي النَّتِيجَةِ.", "Die Verbesserung ist im Ergebnis deutlich.", [("التَّحْسِينُ", "die Verbesserung"), ("وَاضِحٌ", "ist deutlich"), ("فِي", "im"), ("النَّتِيجَةِ", "Ergebnis")]),
    (1268, "تَحْسِينُ الْعَمَلِ مُهِمٌّ.", "Die Verbesserung der Arbeit ist wichtig.", [("تَحْسِينُ", "die Verbesserung"), ("الْعَمَلِ", "der Arbeit"), ("مُهِمٌّ", "ist wichtig")]),
    (1268, "حَقَّقْنَا التَّحْسِينَ فِي السَّنَةِ.", "Wir erreichten die Verbesserung im Jahr.", [("حَقَّقْنَا", "wir erreichten"), ("التَّحْسِينَ", "die Verbesserung"), ("فِي", "im"), ("السَّنَةِ", "Jahr")]),
    (1269, "الضَّرُورَةُ دَفَعَتْنَا إِلَى الْعَمَلِ.", "Die Notwendigkeit trieb uns zur Arbeit.", [("الضَّرُورَةُ", "die Notwendigkeit"), ("دَفَعَتْنَا", "trieb uns"), ("إِلَى", "zur"), ("الْعَمَلِ", "Arbeit")]),
    (1269, "ضَرُورَةُ الْمَاءِ وَاضِحَةٌ فِي الْحَيَاةِ.", "Die Notwendigkeit des Wassers ist im Leben klar.", [("ضَرُورَةُ", "die Notwendigkeit"), ("الْمَاءِ", "des Wassers"), ("وَاضِحَةٌ", "ist klar"), ("فِي", "im"), ("الْحَيَاةِ", "Leben")]),
    (1269, "فَهِمْنَا الضَّرُورَةَ فِي الْبِدَايَةِ.", "Wir verstanden die Notwendigkeit am Anfang.", [("فَهِمْنَا", "wir verstanden"), ("الضَّرُورَةَ", "die Notwendigkeit"), ("فِي", "am"), ("الْبِدَايَةِ", "Anfang")]),
    (1270, "الْمَصْلَحَةُ مُهِمَّةٌ فِي الْقَرَارِ.", "Der Nutzen ist wichtig in der Entscheidung.", [("الْمَصْلَحَةُ", "der Nutzen"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "in"), ("الْقَرَارِ", "der Entscheidung")]),
    (1270, "مَصْلَحَةُ الْبَلَدِ فَوْقَ كُلِّ شَيْءٍ.", "Das Interesse des Landes steht über allem.", [("مَصْلَحَةُ", "das Interesse"), ("الْبَلَدِ", "des Landes"), ("فَوْقَ", "über"), ("كُلِّ", "allem"), ("شَيْءٍ", "Ding")]),
    (1271, "الْمَقْصِدُ وَاضِحٌ فِي الْخِطَابِ.", "Das Ziel ist in der Rede klar.", [("الْمَقْصِدُ", "das Ziel"), ("وَاضِحٌ", "ist klar"), ("فِي", "in"), ("الْخِطَابِ", "der Rede")]),
    (1271, "مَقْصِدُ السَّفَرِ مَعْرُوفٌ.", "Die Absicht der Reise ist bekannt.", [("مَقْصِدُ", "die Absicht"), ("السَّفَرِ", "der Reise"), ("مَعْرُوفٌ", "ist bekannt")]),
    (1271, "فَهِمْنَا الْمَقْصِدَ مِنَ الْكَلَامِ.", "Wir verstanden die Absicht der Rede.", [("فَهِمْنَا", "wir verstanden"), ("الْمَقْصِدَ", "die Absicht"), ("مِنَ", "von"), ("الْكَلَامِ", "der Rede")]),
    (1272, "الرَّغْبَةُ كَبِيرَةٌ فِي التَّعَلُّمِ.", "Der Wunsch ist groß beim Lernen.", [("الرَّغْبَةُ", "der Wunsch"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "beim"), ("التَّعَلُّمِ", "Lernen")]),
    (1272, "رَغْبَةُ الْوَلَدِ فِي اللَّعِبِ وَاضِحَةٌ.", "Der Wunsch des Jungen zu spielen ist deutlich.", [("رَغْبَةُ", "der Wunsch"), ("الْوَلَدِ", "des Jungen"), ("فِي", "zu"), ("اللَّعِبِ", "spielen"), ("وَاضِحَةٌ", "ist deutlich")]),
    (1272, "قَدَّمَ الرَّجُلُ رَغْبَتَهُ فِي سُكُونِ الْمَدِينَةِ.", "Der Mann äußerte seinen Wunsch, in der Stadt zu wohnen.", [("قَدَّمَ", "äußerte"), ("الرَّجُلُ", "der Mann"), ("رَغْبَتَهُ", "seinen Wunsch"), ("فِي", "in"), ("سُكُونِ", "dem Wohnen"), ("الْمَدِينَةِ", "in der Stadt")]),
    (1273, "الْحَاجَةُ مُهِمَّةٌ فِي الْحَيَاةِ.", "Das Bedürfnis ist wichtig im Leben.", [("الْحَاجَةُ", "das Bedürfnis"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "im"), ("الْحَيَاةِ", "Leben")]),
    (1273, "حَاجَةُ الْمَرِيضِ إِلَى الطَّبِيبِ وَاضِحَةٌ.", "Das Bedürfnis des Kranken nach dem Arzt ist deutlich.", [("حَاجَةُ", "das Bedürfnis"), ("الْمَرِيضِ", "des Kranken"), ("إِلَى", "nach"), ("الطَّبِيبِ", "dem Arzt"), ("وَاضِحَةٌ", "ist deutlich")]),
    (1273, "أَعْلَمَنَا بِالْحَاجَةِ فِي الْوَقْتِ.", "Er informierte uns zur Zeit über das Bedürfnis.", [("أَعْلَمَنَا", "informierte uns"), ("بِالْحَاجَةِ", "über das Bedürfnis"), ("فِي", "zur"), ("الْوَقْتِ", "Zeit")]),
    (1274, "الْمَنْفَعَةُ كَبِيرَةٌ فِي الْمَشْرُوعِ.", "Der Nutzen ist groß im Projekt.", [("الْمَنْفَعَةُ", "der Nutzen"), ("كَبِيرَةٌ", "ist groß"), ("فِي", "im"), ("الْمَشْرُوعِ", "Projekt")]),
    (1274, "مَنْفَعَةُ الدَّوَاءِ مَعْرُوفَةٌ.", "Der Nutzen des Medikaments ist bekannt.", [("مَنْفَعَةُ", "der Nutzen"), ("الدَّوَاءِ", "des Medikaments"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1274, "ذَكَرَ الْمَنْفَعَةَ فِي الْخِطَابِ.", "Er erwähnte den Nutzen in der Rede.", [("ذَكَرَ", "erwähnte"), ("الْمَنْفَعَةَ", "den Nutzen"), ("فِي", "in"), ("الْخِطَابِ", "der Rede")]),
    (1275, "الْمَضَرَّةُ وَاضِحَةٌ فِي الْقَرَارِ.", "Der Schaden ist in der Entscheidung deutlich.", [("الْمَضَرَّةُ", "der Schaden"), ("وَاضِحَةٌ", "ist deutlich"), ("فِي", "in"), ("الْقَرَارِ", "der Entscheidung")]),
    (1275, "مَضَرَّةُ التَّدْخِينِ مَعْرُوفَةٌ.", "Der Schaden des Rauchens ist bekannt.", [("مَضَرَّةُ", "der Schaden"), ("التَّدْخِينِ", "des Rauchens"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1276, "الظَّرْفُ مُهِمٌّ فِي الْقَرَارِ.", "Der Umstand ist wichtig in der Entscheidung.", [("الظَّرْفُ", "der Umstand"), ("مُهِمٌّ", "ist wichtig"), ("فِي", "in"), ("الْقَرَارِ", "der Entscheidung")]),
    (1276, "ظَرْفُ الْعَامِلِ صَعْبٌ.", "Die Lage des Arbeiters ist schwer.", [("ظَرْفُ", "die Lage"), ("الْعَامِلِ", "des Arbeiters"), ("صَعْبٌ", "ist schwer")]),
    (1276, "نَظَرْنَا إِلَى الظَّرْفِ فِي الْحُكْمِ.", "Wir sahen auf den Umstand im Urteil.", [("نَظَرْنَا", "wir sahen"), ("إِلَى", "auf"), ("الظَّرْفِ", "den Umstand"), ("فِي", "im"), ("الْحُكْمِ", "Urteil")]),
    (1277, "الْمِيثَاقُ مُهِمٌّ بَيْنَ الْبَلَدَيْنِ.", "Der Vertrag ist wichtig zwischen den beiden Ländern.", [("الْمِيثَاقُ", "der Vertrag"), ("مُهِمٌّ", "ist wichtig"), ("بَيْنَ", "zwischen"), ("الْبَلَدَيْنِ", "den beiden Ländern")]),
    (1277, "مِيثَاقُ الْأُمَمِ قَدِيمٌ.", "Die Charta der Nationen ist alt.", [("مِيثَاقُ", "die Charta"), ("الْأُمَمِ", "der Nationen"), ("قَدِيمٌ", "ist alt")]),
    (1277, "وَقَّعُوا الْمِيثَاقَ فِي الْمُؤْتَمَرِ.", "Sie unterzeichneten den Vertrag auf der Konferenz.", [("وَقَّعُوا", "unterzeichneten"), ("الْمِيثَاقَ", "den Vertrag"), ("فِي", "auf"), ("الْمُؤْتَمَرِ", "der Konferenz")]),
    (1278, "الْقَرِينُ وَفِيٌّ فِي السَّفَرِ.", "Der Gefährte ist treu auf der Reise.", [("الْقَرِينُ", "der Gefährte"), ("وَفِيٌّ", "ist treu"), ("فِي", "auf"), ("السَّفَرِ", "der Reise")]),
    (1278, "قَرِينُ الرَّجُلِ فِي الْعَمَلِ مُجْتَهِدٌ.", "Der Arbeitsgefährte des Mannes ist fleißig.", [("قَرِينُ", "der Gefährte"), ("الرَّجُلِ", "des Mannes"), ("فِي", "in"), ("الْعَمَلِ", "der Arbeit"), ("مُجْتَهِدٌ", "ist fleißig")]),
    (1278, "رَافَقَ الْقَرِينُ الْمُسَافِرَ إِلَى الْمَدِينَةِ.", "Der Gefährte begleitete den Reisenden in die Stadt.", [("رَافَقَ", "begleitete"), ("الْقَرِينُ", "der Gefährte"), ("الْمُسَافِرَ", "den Reisenden"), ("إِلَى", "in"), ("الْمَدِينَةِ", "die Stadt")]),
    (1279, "النَّخْبَةُ صَغِيرَةٌ فِي الْمُجْتَمَعِ.", "Die Elite ist klein in der Gesellschaft.", [("النَّخْبَةُ", "die Elite"), ("صَغِيرَةٌ", "ist klein"), ("فِي", "in"), ("الْمُجْتَمَعِ", "der Gesellschaft")]),
    (1279, "نَخْبَةُ الْكُتَّابِ مَعْرُوفَةٌ.", "Die Elite der Schriftsteller ist bekannt.", [("نَخْبَةُ", "die Elite"), ("الْكُتَّابِ", "der Schriftsteller"), ("مَعْرُوفَةٌ", "ist bekannt")]),
    (1279, "اِخْتَارُوا النَّخْبَةَ لِلْمُهِمَّةِ.", "Man wählte die Elite für die Aufgabe aus.", [("اِخْتَارُوا", "man wählte aus"), ("النَّخْبَةَ", "die Elite"), ("لِلْمُهِمَّةِ", "für die Aufgabe")]),
    (1280, "الطَّبَقَةُ الْعُصْرِيَّةُ مُهِمَّةٌ فِي الْبَلَدِ.", "Die zeitgenössische Schicht ist wichtig im Land.", [("الطَّبَقَةُ", "die Schicht"), ("الْعُصْرِيَّةُ", "zeitgenössische"), ("مُهِمَّةٌ", "ist wichtig"), ("فِي", "im"), ("الْبَلَدِ", "Land")]),
    (1280, "طَبَقَةُ الْعُمَّالِ كَبِيرَةٌ.", "Die Arbeiterschicht ist groß.", [("طَبَقَةُ", "die Schicht"), ("الْعُمَّالِ", "der Arbeiter"), ("كَبِيرَةٌ", "ist groß")]),
    (1281, "الْمَخْزُونُ كَبِيرٌ فِي الْمُسْتَوْدَعِ.", "Der Vorrat ist groß im Lager.", [("الْمَخْزُونُ", "der Vorrat"), ("كَبِيرٌ", "ist groß"), ("فِي", "im"), ("الْمُسْتَوْدَعِ", "Lager")]),
    (1281, "مَخْزُونُ الْقَمْحِ جَيِّدٌ هَذَا الْعَامَ.", "Der Weizenvorrat ist gut dieses Jahr.", [("مَخْزُونُ", "der Vorrat"), ("الْقَمْحِ", "des Weizens"), ("جَيِّدٌ", "ist gut"), ("هَذَا", "dieses"), ("الْعَامَ", "Jahr")]),
    (1281, "حَفِظْنَا الْمَخْزُونَ فِي الْمَخْزَنِ.", "Wir bewahrten den Bestand im Lager auf.", [("حَفِظْنَا", "wir bewahrten auf"), ("الْمَخْزُونَ", "den Bestand"), ("فِي", "im"), ("الْمَخْزَنِ", "Lager")]),
    (1282, "الْمُخَزَّنُ وَاسِعٌ فِي الْمَصْنَعِ.", "Das Lager ist weit in der Fabrik.", [("الْمُخَزَّنُ", "das Lager"), ("وَاسِعٌ", "ist weit"), ("فِي", "in"), ("الْمَصْنَعِ", "der Fabrik")]),
    (1282, "مُخَزَّنُ الْبَضَائِعِ مَلِيءٌ.", "Der Warenspeicher ist voll.", [("مُخَزَّنُ", "der Speicher"), ("الْبَضَائِعِ", "der Waren"), ("مَلِيءٌ", "ist voll")]),
    (1282, "أَغْلَقْنَا الْمُخَزَّنَ فِي الْمَسَاءِ.", "Wir schlossen das Lager am Abend.", [("أَغْلَقْنَا", "wir schlossen"), ("الْمُخَزَّنَ", "das Lager"), ("فِي", "am"), ("الْمَسَاءِ", "Abend")]),
    (1283, "الْقَائِمُ مُتَمَكِّنٌ فِي الْمَكَانِ.", "Der Stehende ist fest an dem Ort.", [("الْقَائِمُ", "der Stehende"), ("مُتَمَكِّنٌ", "ist fest"), ("فِي", "an"), ("الْمَكَانِ", "dem Ort")]),
    (1283, "قَائِمُ الْعَمَلِ وَاضِحٌ.", "Die bestehende Arbeit ist klar.", [("قَائِمُ", "die bestehende"), ("الْعَمَلِ", "Arbeit"), ("وَاضِحٌ", "ist klar")]),
    (1283, "وَقَفَ الْقَائِمُ أَمَامَ الْبَابِ.", "Der Stehende stand vor der Tür.", [("وَقَفَ", "stand"), ("الْقَائِمُ", "der Stehende"), ("أَمَامَ", "vor"), ("الْبَابِ", "der Tür")]),
    (1284, "الْفَرِيقُ مُتَّحِدٌ فِي الْعَمَلِ.", "Die Mannschaft ist im Werk vereint.", [("الْفَرِيقُ", "die Mannschaft"), ("مُتَّحِدٌ", "ist vereint"), ("فِي", "im"), ("الْعَمَلِ", "Werk")]),
    (1284, "مُتَّحِدٌ يَعْمَلُ لِخَيْرِ الْجَمِيعِ.", "Der Vereinte arbeitet für das Wohl aller.", [("مُتَّحِدٌ", "der Vereinte"), ("يَعْمَلُ", "arbeitet"), ("لِخَيْرِ", "für das Wohl"), ("الْجَمِيعِ", "aller")]),
    (1284, "اِجْتَمَعَ الْمُتَّحِدُونَ فِي الْمُؤْتَمَرِ.", "Die Vereinten versammelten sich auf der Konferenz.", [("اِجْتَمَعَ", "versammelten sich"), ("الْمُتَّحِدُونَ", "die Vereinten"), ("فِي", "auf"), ("الْمُؤْتَمَرِ", "der Konferenz")]),
    (1285, "الْبَيْتُ مُنْفَرِدٌ فِي الْقَرْيَةِ.", "Das Haus steht einzeln im Dorf.", [("الْبَيْتُ", "das Haus"), ("مُنْفَرِدٌ", "steht einzeln"), ("فِي", "im"), ("الْقَرْيَةِ", "Dorf")]),
    (1285, "عَالِمٌ مُنْفَرِدٌ فِي بَحْثِهِ.", "Ein Gelehrter ist in seiner Forschung allein.", [("عَالِمٌ", "ein Gelehrter"), ("مُنْفَرِدٌ", "ist allein"), ("فِي", "in"), ("بَحْثِهِ", "seiner Forschung")]),
    (1286, "الصَّحِيفَةُ سَابِقَةٌ فِي الِانْتِشَارِ.", "Die Zeitung ist früher erschienen.", [("الصَّحِيفَةُ", "die Zeitung"), ("سَابِقَةٌ", "ist früher"), ("فِي", "beim"), ("الِانْتِشَارِ", "Erscheinen")]),
    (1286, "كَانَ الْقَرَارُ سَابِقًا فِي الْمَجْلِسِ.", "Die Entscheidung war früher im Rat.", [("كَانَ", "war"), ("الْقَرَارُ", "die Entscheidung"), ("سَابِقًا", "früher"), ("فِي", "im"), ("الْمَجْلِسِ", "Rat")]),
    (1286, "عَرَفْنَا السَّابِقَ مِنَ الْخَبَرِ.", "Wir erfuhren das Frühere aus der Nachricht.", [("عَرَفْنَا", "wir erfuhren"), ("السَّابِقَ", "das Frühere"), ("مِنَ", "aus"), ("الْخَبَرِ", "der Nachricht")]),
    (1287, "الْيَوْمُ تَالٍ لِلْعِيدِ.", "Der Tag folgt dem Fest.", [("الْيَوْمُ", "der Tag"), ("تَالٍ", "folgt"), ("لِلْعِيدِ", "dem Fest")]),
    (1287, "كَانَ الْفَصْلُ تَالٍ لِلصَّيْفِ.", "Die Jahreszeit folgte dem Sommer.", [("كَانَ", "war"), ("الْفَصْلُ", "die Jahreszeit"), ("تَالٍ", "folgte"), ("لِلصَّيْفِ", "dem Sommer")]),
    (1287, "جَاءَ التَّالِي مِنَ الطُّلَّابِ.", "Der Folgende kam von den Schülern.", [("جَاءَ", "kam"), ("التَّالِي", "der Folgende"), ("مِنَ", "von"), ("الطُّلَّابِ", "den Schülern")]),
    (1288, "الْفَصْلُ الْمُقْبِلُ مُهِمٌّ.", "Das kommende Semester ist wichtig.", [("الْفَصْلُ", "das Semester"), ("الْمُقْبِلُ", "kommende"), ("مُهِمٌّ", "ist wichtig")]),
    (1288, "كَانَ الْعَامُ الْمُقْبِلُ مَشْغُولًا بِالْأَعْمَالِ.", "Das kommende Jahr war mit Arbeiten voll.", [("كَانَ", "war"), ("الْعَامُ", "das Jahr"), ("الْمُقْبِلُ", "kommende"), ("مَشْغُولًا", "voll"), ("بِالْأَعْمَالِ", "mit Arbeiten")]),
    (1288, "نَنْتَظِرُ الْمُقْبِلَ فِي الْمُسْتَقْبَلِ.", "Wir erwarten das Kommende in der Zukunft.", [("نَنْتَظِرُ", "wir erwarten"), ("الْمُقْبِلَ", "das Kommende"), ("فِي", "in"), ("الْمُسْتَقْبَلِ", "der Zukunft")]),
    (1289, "الْقَادِمُ جَدِيدٌ فِي الْمَدْرَسَةِ.", "Der Kommende ist neu in der Schule.", [("الْقَادِمُ", "der Kommende"), ("جَدِيدٌ", "ist neu"), ("فِي", "in"), ("الْمَدْرَسَةِ", "der Schule")]),
    (1289, "كَانَ السَّفَرُ الْقَادِمُ طَوِيلًا.", "Die bevorstehende Reise war lang.", [("كَانَ", "war"), ("السَّفَرُ", "die Reise"), ("الْقَادِمُ", "bevorstehende"), ("طَوِيلًا", "lang")]),
    (1289, "وَقَفَ الْقَادِمُ عِنْدَ الْبَابِ.", "Der Ankommende stand an der Tür.", [("وَقَفَ", "stand"), ("الْقَادِمُ", "der Ankommende"), ("عِنْدَ", "an"), ("الْبَابِ", "der Tür")]),
    (1290, "الْمُدِيرُ غَائِبٌ الْيَوْمَ.", "Der Direktor ist heute abwesend.", [("الْمُدِيرُ", "der Direktor"), ("غَائِبٌ", "ist abwesend"), ("الْيَوْمَ", "heute")]),
    (1290, "كَانَ الطَّالِبُ غَائِبًا عَنِ الدَّرْسِ.", "Der Student war von der Lektion abwesend.", [("كَانَ", "war"), ("الطَّالِبُ", "der Student"), ("غَائِبًا", "abwesend"), ("عَنِ", "von"), ("الدَّرْسِ", "der Lektion")]),
    (1291, "الْعَمَلُ مُعْتَادٌ فِي الْمَصْنَعِ.", "Die Arbeit ist in der Fabrik gewohnt.", [("الْعَمَلُ", "die Arbeit"), ("مُعْتَادٌ", "ist gewohnt"), ("فِي", "in"), ("الْمَصْنَعِ", "der Fabrik")]),
    (1291, "كَانَ السَّفَرُ الْمُعْتَادُ فِي الشِّتَاءِ.", "Die gewohnte Reise war im Winter.", [("كَانَ", "war"), ("السَّفَرُ", "die Reise"), ("الْمُعْتَادُ", "gewohnte"), ("فِي", "im"), ("الشِّتَاءِ", "Winter")]),
    (1291, "مَعَهُ الْمُعْتَادُ مِنَ الْأَدَوَاتِ.", "Er hat das Gewohnte an Werkzeugen bei sich.", [("مَعَهُ", "er hat bei sich"), ("الْمُعْتَادُ", "das Gewohnte"), ("مِنَ", "an"), ("الْأَدَوَاتِ", "Werkzeugen")]),
    (1292, "الْأَمْرُ عَادِيٌّ فِي الْحَيَاةِ.", "Die Sache ist gewöhnlich im Leben.", [("الْأَمْرُ", "die Sache"), ("عَادِيٌّ", "ist gewöhnlich"), ("فِي", "im"), ("الْحَيَاةِ", "Leben")]),
    (1292, "كَانَ الْيَوْمُ عَادِيًّا فِي الْعَمَلِ.", "Der Tag war gewöhnlich bei der Arbeit.", [("كَانَ", "war"), ("الْيَوْمُ", "der Tag"), ("عَادِيًّا", "gewöhnlich"), ("فِي", "bei"), ("الْعَمَلِ", "der Arbeit")]),
    (1292, "نَقُومُ بِالْعَادِي فِي كُلِّ صَبَاحٍ.", "Wir tun das Gewöhnliche jeden Morgen.", [("نَقُومُ", "wir tun"), ("بِالْعَادِي", "das Gewöhnliche"), ("فِي", "jeden"), ("كُلِّ", "jeden"), ("صَبَاحٍ", "Morgen")]),
    (1293, "الْحَيَاةُ ثَانَوِيَّةٌ فِي الدَّرْسِ.", "Das Leben ist in der Lektion nebensächlich.", [("الْحَيَاةُ", "das Leben"), ("ثَانَوِيَّةٌ", "ist nebensächlich"), ("فِي", "in"), ("الدَّرْسِ", "der Lektion")]),
    (1293, "كَانَ الْأَمْرُ ثَانَوِيًّا فِي الِاجْتِمَاعِ.", "Die Sache war in der Sitzung zweitrangig.", [("كَانَ", "war"), ("الْأَمْرُ", "die Sache"), ("ثَانَوِيًّا", "zweitrangig"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1293, "ذَكَرْنَا الثَّانَوِيَّ فِي الْبَحْثِ.", "Wir erwähnten das Nebensächliche in der Forschung.", [("ذَكَرْنَا", "wir erwähnten"), ("الثَّانَوِيَّ", "das Nebensächliche"), ("فِي", "in"), ("الْبَحْثِ", "der Forschung")]),
    (1294, "التَّعْلِيمُ جَامِعِيٌّ فِي الْمَدِينَةِ.", "Die Bildung ist universitär in der Stadt.", [("التَّعْلِيمُ", "die Bildung"), ("جَامِعِيٌّ", "ist universitär"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1294, "كَانَ الدَّرْسُ جَامِعِيًّا فِي الصَّفِّ.", "Die Lektion war universität in der Klasse.", [("كَانَ", "war"), ("الدَّرْسُ", "die Lektion"), ("جَامِعِيًّا", "universitär"), ("فِي", "in"), ("الصَّفِّ", "der Klasse")]),
    (1294, "دَرَسْنَا الْجَامِعِيَّ فِي الْكُتُبِ.", "Wir studierten das Universitäre in den Büchern.", [("دَرَسْنَا", "wir studierten"), ("الْجَامِعِيَّ", "das Universitäre"), ("فِي", "in"), ("الْكُتُبِ", "den Büchern")]),
    (1295, "الْقَرَارُ حُكُومِيٌّ فِي الْبَلَدِ.", "Die Entscheidung ist staatlich im Land.", [("الْقَرَارُ", "die Entscheidung"), ("حُكُومِيٌّ", "ist staatlich"), ("فِي", "im"), ("الْبَلَدِ", "Land")]),
    (1295, "كَانَ الْمَشْرُوعُ حُكُومِيًّا فِي الْمَدِينَةِ.", "Das Projekt war staatlich in der Stadt.", [("كَانَ", "war"), ("الْمَشْرُوعُ", "das Projekt"), ("حُكُومِيًّا", "staatlich"), ("فِي", "in"), ("الْمَدِينَةِ", "der Stadt")]),
    (1296, "الْخَبَرُ مَحَلِّيٌّ فِي الصَّحِيفَةِ.", "Die Nachricht ist lokal in der Zeitung.", [("الْخَبَرُ", "die Nachricht"), ("مَحَلِّيٌّ", "ist lokal"), ("فِي", "in"), ("الصَّحِيفَةِ", "der Zeitung")]),
    (1296, "كَانَ الْمُوَظَّفُ مَحَلِّيًّا فِي الْمَقْهَى.", "Der Angestellte war örtlich im Café.", [("كَانَ", "war"), ("الْمُوَظَّفُ", "der Angestellte"), ("مَحَلِّيًّا", "örtlich"), ("فِي", "im"), ("الْمَقْهَى", "Café")]),
    (1296, "نُحِبُّ الْمَحَلِّيَّ مِنَ الطَّعَامِ.", "Wir mögen das Lokale vom Essen.", [("نُحِبُّ", "wir mögen"), ("الْمَحَلِّيَّ", "das Lokale"), ("مِنَ", "vom"), ("الطَّعَامِ", "Essen")]),
    (1297, "الاِتِّفَاقُ دَوْلِيٌّ بَيْنَ الْبُلْدَانِ.", "Die Vereinbarung ist international zwischen den Ländern.", [("الاِتِّفَاقُ", "die Vereinbarung"), ("دَوْلِيٌّ", "ist international"), ("بَيْنَ", "zwischen"), ("الْبُلْدَانِ", "den Ländern")]),
    (1297, "كَانَ الْمُؤْتَمَرُ دَوْلِيًّا فِي الْعَاصِمَةِ.", "Die Konferenz war international in der Hauptstadt.", [("كَانَ", "war"), ("الْمُؤْتَمَرُ", "die Konferenz"), ("دَوْلِيًّا", "international"), ("فِي", "in"), ("الْعَاصِمَةِ", "der Hauptstadt")]),
    (1297, "ذَكَرَ الدَّوْلِيَّ فِي التَّقْرِيرِ.", "Er erwähnte das Internationale im Bericht.", [("ذَكَرَ", "erwähnte"), ("الدَّوْلِيَّ", "das Internationale"), ("فِي", "im"), ("التَّقْرِيرِ", "Bericht")]),
    (1298, "الْأَمْرُ دَاخِلِيٌّ فِي الشَّرِكَةِ.", "Die Angelegenheit ist intern in der Firma.", [("الْأَمْرُ", "die Angelegenheit"), ("دَاخِلِيٌّ", "ist intern"), ("فِي", "in"), ("الشَّرِكَةِ", "der Firma")]),
    (1298, "كَانَ الْبَابُ دَاخِلِيًّا فِي الْبِنَاءِ.", "Die Tür war innen im Gebäude.", [("كَانَ", "war"), ("الْبَابُ", "die Tür"), ("دَاخِلِيًّا", "innen"), ("فِي", "im"), ("الْبِنَاءِ", "Gebäude")]),
    (1298, "نَاقَشْنَا الدَّاخِلِيَّ فِي الِاجْتِمَاعِ.", "Wir besprachen das Interne in der Sitzung.", [("نَاقَشْنَا", "wir besprachen"), ("الدَّاخِلِيَّ", "das Interne"), ("فِي", "in"), ("الِاجْتِمَاعِ", "der Sitzung")]),
    (1299, "الْفَنُّ عُصْرِيٌّ فِي الْمُتَحَفِ.", "Die Kunst ist zeitgenössisch im Museum.", [("الْفَنُّ", "die Kunst"), ("عُصْرِيٌّ", "ist zeitgenössisch"), ("فِي", "im"), ("الْمُتَحَفِ", "Museum")]),
    (1299, "كَانَ الشِّعْرُ عُصْرِيًّا فِي الْمَجَلَّةِ.", "Die Dichtung war zeitgenössisch in der Zeitschrift.", [("كَانَ", "war"), ("الشِّعْرُ", "die Dichtung"), ("عُصْرِيًّا", "zeitgenössisch"), ("فِي", "in"), ("الْمَجَلَّةِ", "der Zeitschrift")]),
    (1299, "نُقَدِّرُ الْعُصْرِيَّ مِنَ الْفَنِّ.", "Wir schätzen das Zeitgenössische von der Kunst.", [("نُقَدِّرُ", "wir schätzen"), ("الْعُصْرِيَّ", "das Zeitgenössische"), ("مِنَ", "von"), ("الْفَنِّ", "der Kunst")]),
    (1300, "الطَّالِبُ بَارِزٌ فِي الْفَصْلِ.", "Der Student ist in der Klasse hervorragend.", [("الطَّالِبُ", "der Student"), ("بَارِزٌ", "ist hervorragend"), ("فِي", "in"), ("الْفَصْلِ", "der Klasse")]),
    (1300, "كَانَ الْعَالِمُ بَارِزًا فِي الْعِلْمِ.", "Der Gelehrte war in der Wissenschaft hervorragend.", [("كَانَ", "war"), ("الْعَالِمُ", "der Gelehrte"), ("بَارِزًا", "hervorragend"), ("فِي", "in"), ("الْعِلْمِ", "der Wissenschaft")]),
    (1300, "ذَكَرَ الْبَارِزَ فِي التَّقْرِيرِ.", "Er erwähnte das Hervorragende im Bericht.", [("ذَكَرَ", "erwähnte"), ("الْبَارِزَ", "das Hervorragende"), ("فِي", "im"), ("التَّقْرِيرِ", "Bericht")]),
    (1014, 'اِبْتَدَأْنَا الدَّرْسَ فِي الصَّبَاحِ.', 'Wir begannen die Lektion am Morgen.', [('اِبْتَدَأْنَا', 'wir begannen'), ('الدَّرْسَ', 'die Lektion'), ('فِي', 'am'), ('الصَّبَاحِ', 'Morgen')]),
    (1017, 'شَارَكْنَا فِي الْمُسَابَقَةِ الْكُبْرَى.', 'Wir nahmen am großen Wettbewerb teil.', [('شَارَكْنَا', 'wir nahmen teil'), ('فِي', 'am'), ('الْمُسَابَقَةِ', 'Wettbewerb'), ('الْكُبْرَى', 'großen')]),
    (1024, 'اِنْقَطَعَ الْحَبْلُ وَسَطَ اللَّيْلِ.', 'Das Seil riss mitten in der Nacht ab.', [('اِنْقَطَعَ', 'riss ab'), ('الْحَبْلُ', 'das Seil'), ('وَسَطَ', 'mitten in'), ('اللَّيْلِ', 'der Nacht')]),
    (1030, 'أَنْجَزْنَا الْعَمَلَ بِسُرْعَةٍ.', 'Wir erledigten die Arbeit schnell.', [('أَنْجَزْنَا', 'wir erledigten'), ('الْعَمَلَ', 'die Arbeit'), ('بِسُرْعَةٍ', 'schnell')]),
    (1035, 'أَوْضَحْنَا الْمَعْنَى بِمِثَالٍ.', 'Wir erklärten die Bedeutung mit einem Beispiel.', [('أَوْضَحْنَا', 'wir erklärten'), ('الْمَعْنَى', 'die Bedeutung'), ('بِمِثَالٍ', 'mit einem Beispiel')]),
    (1040, 'اِشْتَرَكْنَا فِي الْمُسَابَقَةِ.', 'Wir nahmen am Wettbewerb teil.', [('اِشْتَرَكْنَا', 'wir nahmen teil'), ('فِي', 'am'), ('الْمُسَابَقَةِ', 'Wettbewerb')]),
    (1045, 'اِسْتَدْعَى الْمُدِيرُ الْمُوَظَّفَ.', 'Der Direktor rief den Angestellten herbei.', [('اِسْتَدْعَى', 'rief herbei'), ('الْمُدِيرُ', 'der Direktor'), ('الْمُوَظَّفَ', 'den Angestellten')]),
    (1050, 'بَحَثَ الرَّجُلُ عَنْ وَسِيلَةٍ لِلنَّجَاحِ.', 'Der Mann suchte nach einem Weg zum Erfolg.', [('بَحَثَ', 'suchte'), ('الرَّجُلُ', 'der Mann'), ('عَنْ', 'nach'), ('وَسِيلَةٍ', 'einem Weg'), ('لِلنَّجَاحِ', 'zum Erfolg')]),
    (1056, 'هَاتِفُ الْبَيْتِ فِي الْمُدِيرِيَّةِ.', 'Das Telefon des Hauses ist in der Verwaltung.', [('هَاتِفُ', 'das Telefon'), ('الْبَيْتِ', 'des Hauses'), ('فِي', 'in'), ('الْمُدِيرِيَّةِ', 'der Verwaltung')]),
    (1061, 'حَضَرْنَا الِاجْتِمَاعَ فِي الصَّبَاحِ.', 'Wir besuchten die Versammlung am Morgen.', [('حَضَرْنَا', 'wir besuchten'), ('الِاجْتِمَاعَ', 'die Versammlung'), ('فِي', 'am'), ('الصَّبَاحِ', 'Morgen')]),
    (1066, 'حَفْلَةُ الْأَصْدِقَاءِ فِي الْمَسَاءِ.', 'Die Feier der Freunde ist am Abend.', [('حَفْلَةُ', 'die Feier'), ('الْأَصْدِقَاءِ', 'der Freunde'), ('فِي', 'am'), ('الْمَسَاءِ', 'Abend')]),
    (1074, 'شَرِبْنَا الْحَلِيبَ مَعَ الْفُطُورِ.', 'Wir tranken die Milch zum Frühstück.', [('شَرِبْنَا', 'wir tranken'), ('الْحَلِيبَ', 'die Milch'), ('مَعَ', 'zum'), ('الْفُطُورِ', 'Frühstück')]),
    (1080, 'نَتَّبِعُ الْمَبْدَأَ فِي الْعَمَلِ.', 'Wir folgen dem Prinzip in der Arbeit.', [('نَتَّبِعُ', 'wir folgen'), ('الْمَبْدَأَ', 'dem Prinzip'), ('فِي', 'in'), ('الْعَمَلِ', 'der Arbeit')]),
    (1085, 'شَارَكْنَا فِي الْوِحْدَةِ بِإِخْلَاصٍ.', 'Wir nahmen an der Einheit aufrichtig teil.', [('شَارَكْنَا', 'wir nahmen teil'), ('فِي', 'an'), ('الْوِحْدَةِ', 'der Einheit'), ('بِإِخْلَاصٍ', 'aufrichtig')]),
    (1090, 'قَدَّرْنَا الْقِيمَةَ بِحِسَابٍ دَقِيقٍ.', 'Wir schätzten den Wert mit genauer Rechnung.', [('قَدَّرْنَا', 'wir schätzten'), ('الْقِيمَةَ', 'den Wert'), ('بِحِسَابٍ', 'mit Rechnung'), ('دَقِيقٍ', 'genauer')]),
    (1096, 'تَطِيرُ الطَّائِرَةُ فِي الْفَضَاءِ.', 'Das Flugzeug fliegt im Luftraum.', [('تَطِيرُ', 'fliegt'), ('الطَّائِرَةُ', 'das Flugzeug'), ('فِي', 'im'), ('الْفَضَاءِ', 'Luftraum')]),
    (1101, 'عَمِلَتِ الْوِزَارَةُ بِجِدٍّ فِي الْعَامِ.', 'Das Ministerium arbeitete im Jahr fleißig.', [('عَمِلَتِ', 'arbeitete'), ('الْوِزَارَةُ', 'das Ministerium'), ('بِجِدٍّ', 'fleißig'), ('فِي', 'im'), ('الْعَامِ', 'Jahr')]),
    (1106, 'كَنَسْنَا الْبَيْتَ بِالْمِكْنَسَةِ.', 'Wir fegten das Haus mit dem Besen.', [('كَنَسْنَا', 'wir fegten'), ('الْبَيْتَ', 'das Haus'), ('بِالْمِكْنَسَةِ', 'mit dem Besen')]),
    (1111, 'اِشْتَرَيْنَا اللَّحْمَ مِنَ الْجَزَّارِ.', 'Wir kauften das Fleisch vom Metzger.', [('اِشْتَرَيْنَا', 'wir kauften'), ('اللَّحْمَ', 'das Fleisch'), ('مِنَ', 'vom'), ('الْجَزَّارِ', 'Metzger')]),
    (1116, 'رَأَيْنَا السَّائِحَ فِي الْمَتَحِفِ.', 'Wir sahen den Touristen im Museum.', [('رَأَيْنَا', 'wir sahen'), ('السَّائِحَ', 'den Touristen'), ('فِي', 'im'), ('الْمَتَحِفِ', 'Museum')]),
    (1121, 'قَرَأْنَا ثُلُثَ الْكِتَابِ فِي اللَّيْلِ.', 'Wir lasen ein Drittel des Buches in der Nacht.', [('قَرَأْنَا', 'wir lasen'), ('ثُلُثَ', 'ein Drittel'), ('الْكِتَابِ', 'des Buches'), ('فِي', 'in'), ('اللَّيْلِ', 'der Nacht')]),
    (1126, 'هَذَا الْكِتَابُ مُمْتِعٌ فِي الْقِرَاءَةِ.', 'Dieses Buch ist beim Lesen unterhaltsam.', [('هَذَا', 'dieses'), ('الْكِتَابُ', 'Buch'), ('مُمْتِعٌ', 'ist unterhaltsam'), ('فِي', 'beim'), ('الْقِرَاءَةِ', 'Lesen')]),
    (1131, 'هَذَا الْجَوَابُ كَافٍ لِلسُّؤَالِ.', 'Diese Antwort ist für die Frage ausreichend.', [('هَذَا', 'diese'), ('الْجَوَابُ', 'Antwort'), ('كَافٍ', 'ist ausreichend'), ('لِلسُّؤَالِ', 'für die Frage')]),
    (1136, 'هَذَا الْمِقْدَارُ مُحَدَّدٌ فِي الْوَثِيقَةِ.', 'Diese Menge ist im Dokument festgelegt.', [('هَذَا', 'diese'), ('الْمِقْدَارُ', 'Menge'), ('مُحَدَّدٌ', 'ist festgelegt'), ('فِي', 'im'), ('الْوَثِيقَةِ', 'Dokument')]),
    (1141, 'هَذَا الْهَدِيُّ ثَمِينٌ فِي الْعِيدِ.', 'Dieses Geschenk ist wertvoll am Fest.', [('هَذَا', 'diese'), ('الْهَدِيُّ', 'Geschenk'), ('ثَمِينٌ', 'ist wertvoll'), ('فِي', 'am'), ('الْعِيدِ', 'Fest')]),
    (1146, 'نُحَافِظُ دَائِمًا عَلَى النَّظَافَةِ.', 'Wir achten immer auf die Sauberkeit.', [('نُحَافِظُ', 'wir achten'), ('دَائِمًا', 'immer'), ('عَلَى', 'auf'), ('النَّظَافَةِ', 'die Sauberkeit')]),
    (1150, 'وَرَاءَ الْبَابِ مَفَاتِيحُ كَثِيرَةٌ.', 'Hinter der Tür sind viele Schlüssel.', [('وَرَاءَ', 'hinter'), ('الْبَابِ', 'der Tür'), ('مَفَاتِيحُ', 'Schlüssel'), ('كَثِيرَةٌ', 'viele')]),
    (1155, 'اِنْعَقَدَ الْمَجْلِسُ فِي الْقَاعَةِ الْكَبِيرَةِ.', 'Die Ratsversammlung fand im großen Saal statt.', [('اِنْعَقَدَ', 'fand statt'), ('الْمَجْلِسُ', 'die Ratsversammlung'), ('فِي', 'im'), ('الْقَاعَةِ', 'Saal'), ('الْكَبِيرَةِ', 'großen')]),
    (1160, 'تَعَلَّقَتِ الْمَرْأَةُ بِحَيَاتِهَا الْقَدِيمَةِ.', 'Die Frau hing an ihrem alten Leben.', [('تَعَلَّقَتِ', 'hing'), ('الْمَرْأَةُ', 'die Frau'), ('بِحَيَاتِهَا', 'an ihrem Leben'), ('الْقَدِيمَةِ', 'alten')]),
    (1165, 'اِنْتَقَمَ الْأَخُ مِنْ عَدُوِّهِ.', 'Der Bruder rächte sich an seinem Feind.', [('اِنْتَقَمَ', 'rächte sich'), ('الْأَخُ', 'der Bruder'), ('مِنْ', 'an'), ('عَدُوِّهِ', 'seinem Feind')]),
    (1170, 'تَفَادَيْنَا الْحَدِيثَ عَنِ الْمَوْضُوعِ.', 'Wir wichen dem Gespräch über das Thema aus.', [('تَفَادَيْنَا', 'wir wichen aus'), ('الْحَدِيثَ', 'dem Gespräch'), ('عَنِ', 'über'), ('الْمَوْضُوعِ', 'das Thema')]),
    (1175, 'اِنْظَمَّ الصَّدِيقُ إِلَى الْمَجْمُوعَةِ.', 'Der Freund schloss sich der Gruppe an.', [('اِنْظَمَّ', 'schloss sich an'), ('الصَّدِيقُ', 'der Freund'), ('إِلَى', 'der'), ('الْمَجْمُوعَةِ', 'Gruppe')]),
    (1180, 'اِسْتَهَانَ الْوَلَدُ بِنَصِيحَةِ الْأَبِ.', 'Der Junge setzte sich über den Rat des Vaters hinweg.', [('اِسْتَهَانَ', 'setzte sich hinweg über'), ('الْوَلَدُ', 'der Junge'), ('بِنَصِيحَةِ', 'den Rat'), ('الْأَبِ', 'des Vaters')]),
    (1185, 'اِغْتَسَلْنَا بَعْدَ الْعَمَلِ فِي الْحَقْلِ.', 'Wir wuschen uns nach der Arbeit auf dem Feld.', [('اِغْتَسَلْنَا', 'wir wuschen uns'), ('بَعْدَ', 'nach'), ('الْعَمَلِ', 'der Arbeit'), ('فِي', 'auf'), ('الْحَقْلِ', 'dem Feld')]),
    (1190, 'اِسْتَقْصَى الْبَاحِثُ التَّفَاصِيلَ فِي الْمُخْتَبَرِ.', 'Der Forscher untersuchte im Labor die Einzelheiten.', [('اِسْتَقْصَى', 'untersuchte'), ('الْبَاحِثُ', 'der Forscher'), ('التَّفَاصِيلَ', 'die Einzelheiten'), ('فِي', 'im'), ('الْمُخْتَبَرِ', 'Labor')]),
    (1195, 'اِعْتَزَّ الشَّعْبُ بِوَطَنِهِ.', 'Das Volk war stark durch sein Vaterland.', [('اِعْتَزَّ', 'war stark'), ('الشَّعْبُ', 'das Volk'), ('بِوَطَنِهِ', 'durch sein Vaterland')]),
    (1200, 'اِسْتَحْسَنَ الْأَبُ سُلُوكَ ابْنِهِ.', 'Der Vater fand das Benehmen seines Sohnes gut.', [('اِسْتَحْسَنَ', 'fand gut'), ('الْأَبُ', 'der Vater'), ('سُلُوكَ', 'das Benehmen'), ('ابْنِهِ', 'seines Sohnes')]),
    (1205, 'اِنْصَرَفْنَا مِنَ الِاجْتِمَاعِ فِي الْمَسَاءِ.', 'Wir gingen am Abend aus der Sitzung weg.', [('اِنْصَرَفْنَا', 'wir gingen weg'), ('مِنَ', 'aus'), ('الِاجْتِمَاعِ', 'der Sitzung'), ('فِي', 'am'), ('الْمَسَاءِ', 'Abend')]),
    (1210, 'كَانَتِ الْمَلِكَةُ مَحْبُوبَةً عِنْدَ الشَّعْبِ.', 'Die Königin war beim Volk beliebt.', [('كَانَتِ', 'war'), ('الْمَلِكَةُ', 'die Königin'), ('مَحْبُوبَةً', 'beliebt'), ('عِنْدَ', 'beim'), ('الشَّعْبِ', 'Volk')]),
    (1215, 'أَسَّسَ الرَّجُلُ شَرِكَةً جَدِيدَةً.', 'Der Mann gründete eine neue Firma.', [('أَسَّسَ', 'gründete'), ('الرَّجُلُ', 'der Mann'), ('شَرِكَةً', 'eine Firma'), ('جَدِيدَةً', 'neue')]),
    (1220, 'اِشْتَرَى الرَّجُلُ بَضَاعَةً نَفِيسَةً.', 'Der Mann kaufte eine wertvolle Ware.', [('اِشْتَرَى', 'kaufte'), ('الرَّجُلُ', 'der Mann'), ('بَضَاعَةً', 'eine Ware'), ('نَفِيسَةً', 'wertvolle')]),
    (1225, 'وَسَّعْنَا الْمَجَالَ فِي الْبَحْثِ.', 'Wir erweiterten das Feld in der Forschung.', [('وَسَّعْنَا', 'wir erweiterten'), ('الْمَجَالَ', 'das Feld'), ('فِي', 'in'), ('الْبَحْثِ', 'der Forschung')]),
    (1230, 'اِنْضَمَّ الرَّجُلُ إِلَى الْجَمْعِيَّةِ الْخَيْرِيَّةِ.', 'Der Mann schloss sich dem Wohltätigkeitsverein an.', [('اِنْضَمَّ', 'schloss sich an'), ('الرَّجُلُ', 'der Mann'), ('إِلَى', 'dem'), ('الْجَمْعِيَّةِ', 'Verein'), ('الْخَيْرِيَّةِ', 'Wohltätigkeits-')]),
    (1235, 'رَشَّحُوا الْمُرَشَّحَ فِي الِاجْتِمَاعِ.', 'Man stellte den Kandidaten in der Sitzung auf.', [('رَشَّحُوا', 'stellten auf'), ('الْمُرَشَّحَ', 'den Kandidaten'), ('فِي', 'in'), ('الِاجْتِمَاعِ', 'der Sitzung')]),
    (1240, 'نَسْكُنُ فِي حَارَةٍ جَمِيلَةٍ.', 'Wir wohnen in einem schönen Viertel.', [('نَسْكُنُ', 'wir wohnen'), ('فِي', 'in'), ('حَارَةٍ', 'einem Viertel'), ('جَمِيلَةٍ', 'schönen')]),
    (1245, 'قَبِلَ الرَّجُلُ الْمَسْؤُولِيَّةَ بِشَجَاعَةٍ.', 'Der Mann übernahm die Verantwortung mutig.', [('قَبِلَ', 'übernahm'), ('الرَّجُلُ', 'der Mann'), ('الْمَسْؤُولِيَّةَ', 'die Verantwortung'), ('بِشَجَاعَةٍ', 'mutig')]),
    (1250, 'اِكْتَشَفَ الْمُعَلِّمُ الْمَوْهِبَةَ فِي الطِّفْلِ.', 'Der Lehrer entdeckte die Begabung beim Kind.', [('اِكْتَشَفَ', 'entdeckte'), ('الْمُعَلِّمُ', 'der Lehrer'), ('الْمَوْهِبَةَ', 'die Begabung'), ('فِي', 'beim'), ('الطِّفْلِ', 'Kind')]),
    (1255, 'اِتَّخَذَ الْمَجْلِسُ الْقَرَارَ فِي الصَّبَاحِ.', 'Der Rat traf die Entscheidung am Morgen.', [('اِتَّخَذَ', 'traf'), ('الْمَجْلِسُ', 'der Rat'), ('الْقَرَارَ', 'die Entscheidung'), ('فِي', 'am'), ('الصَّبَاحِ', 'Morgen')]),
    (1260, 'تَتَبَّعْنَا الْإِدَارَةَ بِدِقَّةٍ.', 'Wir verfolgten die Verwaltung genau.', [('تَتَبَّعْنَا', 'wir verfolgten'), ('الْإِدَارَةَ', 'die Verwaltung'), ('بِدِقَّةٍ', 'genau')]),
    (1265, 'وَضَعَ الْعَامِلُ الْأَسَاسَ لِلْمَشْرُوعِ.', 'Der Arbeiter legte die Grundlage für das Projekt.', [('وَضَعَ', 'legte'), ('الْعَامِلُ', 'der Arbeiter'), ('الْأَسَاسَ', 'die Grundlage'), ('لِلْمَشْرُوعِ', 'für das Projekt')]),
    (1270, 'نَظَرْنَا إِلَى الْمَصْلَحَةِ الْعَامَّةِ.', 'Wir sahen auf den allgemeinen Nutzen.', [('نَظَرْنَا', 'wir sahen'), ('إِلَى', 'auf'), ('الْمَصْلَحَةِ', 'den Nutzen'), ('الْعَامَّةِ', 'allgemeinen')]),
    (1275, 'تَجَنَّبْنَا الْمَضَرَّةَ فِي الْمَشْرُوعِ.', 'Wir vermieden den Schaden im Projekt.', [('تَجَنَّبْنَا', 'wir vermieden'), ('الْمَضَرَّةَ', 'den Schaden'), ('فِي', 'im'), ('الْمَشْرُوعِ', 'Projekt')]),
    (1280, 'دَرَسْنَا الطَّبَقَةَ فِي الْمُجْتَمَعِ.', 'Wir untersuchten die Schicht in der Gesellschaft.', [('دَرَسْنَا', 'wir untersuchten'), ('الطَّبَقَةَ', 'die Schicht'), ('فِي', 'in'), ('الْمُجْتَمَعِ', 'der Gesellschaft')]),
    (1285, 'عَاشَ الرَّجُلُ مُنْفَرِدًا فِي الْجِبَالِ.', 'Der Mann lebte allein in den Bergen.', [('عَاشَ', 'lebte'), ('الرَّجُلُ', 'der Mann'), ('مُنْفَرِدًا', 'allein'), ('فِي', 'in'), ('الْجِبَالِ', 'den Bergen')]),
    (1290, 'حَضَرَ الْغَائِبُ فِي الْمَسَاءِ.', 'Der Abwesende kam am Abend.', [('حَضَرَ', 'kam'), ('الْغَائِبُ', 'der Abwesende'), ('فِي', 'am'), ('الْمَسَاءِ', 'Abend')]),
    (1295, 'ذَكَرَ الْحُكُومِيَّ فِي الْخِطَابِ.', 'Er erwähnte das Staatliche in der Rede.', [('ذَكَرَ', 'erwähnte'), ('الْحُكُومِيَّ', 'das Staatliche'), ('فِي', 'in'), ('الْخِطَابِ', 'der Rede')]),
]

# ---------------------------------------------------------------------------
# Transliteration (DIN 31635), 1:1 in derselben Reihenfolge wie die Sätze
# oben. Die B1-Inhalte werden in der App NICHT mit Transliteration angezeigt
# (lib/core/word_groups.dart#showsTransliteration beschränkt die Anzeige auf
# A1/A2) — die Pipeline verlangt aber pro Satz einen Eintrag. Daher erzeugt
# der Konverter unten die Umschrift deterministisch aus dem arabischen Text
# (gleiche DIN-31635-Regeln wie im Bestand: Makron-Vokale für Madd-Buchstaben,
# Sonnenbuchstaben-Assimilation bei "al-", Shadda-Verdopplung, Hamzat-al-Wasl
# wird nicht über Wortgrenzen elidiert).
# ---------------------------------------------------------------------------

import re as _re
import unicodedata as _unicodedata

# DIN-31635 Buchstaben-Zuordnung (Konsonanten und Sonderzeichen).
_CHAR_TO_LATIN: dict[str, str] = {
    "ء": "ʾ", "أ": "ʾa", "إ": "ʾi", "آ": "ʾā", "ؤ": "ʾu", "ئ": "ʾi", "ا": "ā",
    "ب": "b", "ت": "t", "ث": "ṯ", "ج": "ǧ", "ح": "ḥ", "خ": "ḫ", "د": "d",
    "ذ": "ḏ", "ر": "r", "ز": "z", "س": "s", "ش": "š", "ص": "ṣ", "ض": "ḍ",
    "ط": "ṭ", "ظ": "ẓ", "ع": "ʿ", "غ": "ġ", "ف": "f", "ق": "q", "ك": "k",
    "ل": "l", "م": "m", "ن": "n", "ه": "h", "و": "w", "ي": "y", "ة": "a",
    "ى": "ā",
}

# Harakat: Fatha/Damma/Kasra setzen den Kurzvokal des VORANGEHENDEN
# Konsonanten; Sukun ist vokallos; Shadda geminiert denselben Konsonanten;
# Tanwin ergibt ein Schluss-n.
_FATHA = "\u064e"
_DAMMA = "\u064f"
_KASRA = "\u0650"
_SUKUN = "\u0652"
_SHADDA = "\u0651"
_TANWIN_FATH = "\u064b"
_TANWIN_DAMM = "\u064c"
_TANWIN_KASR = "\u064d"

_BASE_LETTERS = set("ابتثجحخدذرزسشصضطظعغفقكلهمنهوياءأةإآؤئى")

# Sonnenbuchstaben: "al-" -> assimilierter Artikel ("aš-šamsu" etc.).
_SUN_LETTERS = set("tṯdḏrzsšṣḍṭẓnl")


def _tokenize(word: str) -> list[tuple[str, str]]:
    """Zerlegt ein arabisches Wort in (Basisschriftzeichen, Haraka-String)."""
    tokens: list[tuple[str, str]] = []
    current_base = ""
    marks: list[str] = []
    for ch in word:
        if ch in _BASE_LETTERS:
            if current_base:
                tokens.append((current_base, "".join(marks)))
            current_base = ch
            marks = []
        elif ch in (_FATHA, _DAMMA, _KASRA, _SUKUN, _SHADDA,
                    _TANWIN_FATH, _TANWIN_DAMM, _TANWIN_KASR):
            marks.append(ch)
    if current_base:
        tokens.append((current_base, "".join(marks)))
    return tokens


def _vowel_of(marks: str) -> str:
    """a/u/i aus Fatha/Damma/Kasra (in dieser Reihenfolge gewertet)."""
    if _FATHA in marks:
        return "a"
    if _DAMMA in marks:
        return "u"
    if _KASRA in marks:
        return "i"
    return ""


def _geminated(marks: str) -> bool:
    return _SHADDA in marks


def _tanwin_of(marks: str) -> str:
    if _TANWIN_FATH in marks:
        return "an"
    if _TANWIN_DAMM in marks:
        return "un"
    if _TANWIN_KASR in marks:
        return "in"
    return ""


def _din_word(word: str) -> str:
    """Wandelt ein arabisches Wort in eine DIN-31635-Umschrift um.

    Deterministische, heuristische Umschrift für die B1-Daten (die App zeigt
    Transliterationen nur bei A1/A2 an — siehe word_groups.dart). Madd-Länge
    (ā/ū/ī) wird durch den Folge-Madd-Buchstaben repräsentiert wie im
    händischen Bestand (\"kāna\", \"sukūn\", \"qīla\").
    """
    tokens = _tokenize(word)
    out: list[str] = []
    is_article = (
        len(tokens) >= 2
        and tokens[0][0] == "ا"
        and tokens[1][0] == "ل"
        and _vowel_of(tokens[0][1]) in ("", "a")
    )
    for pos, (base, marks) in enumerate(tokens):
        vowel = _vowel_of(marks)
        tanwin = _tanwin_of(marks)
        double = _geminated(marks)

        if is_article and pos == 0:  # Alif der Artikelform
            out.append("al")
            continue
        if is_article and pos == 1:  # Lam des Artikels
            # Sun-Assimilation: "al-"+"r…" -> "ar-…"
            if len(tokens) > 2 and tokens[2][0] in _SUN_LETTERS:
                sun = _CHAR_TO_LATIN[tokens[2][0]]
                out[-1] = "a" + sun + "-"
            else:
                out.append("-")
            continue

        if base in ("آ",):
            out.append("ʾā")
            continue
        if base in ("أ", "إ", "ؤ", "ئ", "ء"):
            out.append("ʾ" + vowel)
            continue
        if base == "ا":
            # Madd-Alif: verlängert vorangegangenen a-Vokal, sofern ohne
            # eigene Vokalisierung; sonst vokalloser Träger.
            if not out:
                out.append("ʾ" + vowel if vowel else "ʾ")
            elif not vowel and out[-1].endswith("a"):
                out[-1] = out[-1][:-1] + "ā"
            elif vowel:
                out.append("ʾ" + vowel)
            continue
        if base == "ى":
            out.append("ā")
            if vowel:
                out[-1] += vowel
            continue
        if base == "ة":
            # Tāʾ-marbūṭa: im absoluten Auslaut "a"; vor Tanwīn („atun/atan")
            # übernimmt sie das Schluss-n des Tanwīns; mit Kasra/Damma des
            # Status constructs wird sie als "at"+Vokal hörbar ("riḥlati").
            if tanwin:
                piece = "at" + tanwin
            elif vowel:
                piece = "at" + vowel
            else:
                piece = "a"
            out.append(piece)
            continue

        latin = _CHAR_TO_LATIN[base]
        if base == "و":
            half = ("w" + vowel) if vowel else "w"
            if double:
                half = ("w" if not vowel else "w" + vowel) + half
            if not out:
                out.append(half)
            elif not vowel and out[-1].endswith("u"):
                out[-1] = out[-1][:-1] + "ū"
            elif not vowel and out[-1].endswith("a"):
                out[-1] += "w"
            else:
                out.append(half)
            if tanwin:
                out[-1] += tanwin
            continue
        if base == "ي":
            half = ("y" + vowel) if vowel else "y"
            if double:
                half = ("y" if not vowel else "y" + vowel) + half
            if not out:
                out.append(half)
            elif not vowel and out[-1].endswith("i"):
                out[-1] = out[-1][:-1] + "ī"
            elif not vowel and out[-1].endswith("a"):
                out[-1] += "y"
            else:
                out.append(half)
            if tanwin:
                out[-1] += tanwin
            continue

        piece = latin
        if double:
            piece = piece + piece
        if tanwin:
            piece += tanwin  # enthält bereits seinen Kurzvokal („un/\"an/…\")
        elif vowel:
            piece += vowel
        out.append(piece)

    return "".join(out)


def _transliterate_sentence(arabic: str) -> str:
    """Erzeugt eine DIN-31635-Satz-Transliteration aus arabischem Text."""
    arabic = _unicodedata.normalize("NFC", arabic)
    words: list[str] = []
    for raw in _re.split(r"[ \s]+", arabic.strip()):
        if not raw:
            continue
        word = _din_word(raw)
        if word.startswith("al-") and len(word) > 3 and word[3] in _SUN_LETTERS:
            word = "a" + word[3] + "-" + word[4:]
        words.append(word)
    sentence = " ".join(words)
    for punct, _rep in (("؟", "?"), ("،", ",")):
        sentence = sentence.replace(" " + punct, punct)
    return sentence


# 1:1 in derselben Reihenfolge wie B1_SENTENCES_ETAPPE1; die Zeilen werden
# deterministisch erzeugt und hier dokumentierend ausgegeben.
B1_TRANSLITERATIONS_ETAPPE1: list[str] = [
    _transliterate_sentence(s[1]) for s in B1_SENTENCES_ETAPPE1
]