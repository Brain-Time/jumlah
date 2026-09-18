#!/usr/bin/env python3
"""Adds the B1 Etappe 1 root definitions to scripts/root_definitions.csv.

The definitions follow the established editorial style (own summary based on
classical Arabic lexicography / Lane's Lexicon, no verbatim copy). Idempotent:
roots already present in root_definitions.csv are skipped.
"""

from __future__ import annotations

import csv
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFINITIONS_PATH = ROOT / "scripts" / "root_definitions.csv"

SOURCE = (
    "Eigene Zusammenfassung nach klassischer arabischer Lexikographie "
    "(Lisān al-ʿArab, Lane's Lexicon) - keine wörtliche Übernahme aus hawramani.com"
)

# root -> classical definition (added only if the root is missing).
NEW_DEFINITIONS: dict[str, str] = {
    "أ-ث-ر": "einen Eindruck hinterlassen, nachwirken, beeinflussen; أَثَر (ʾaṯar) „Spur, Überbleibsel, Einfluss“",
    "أ-د-ي": "leisten, ausführen, zahlen (eine Schuld); أَدَاء (ʾadāʾ) „Leistung, Ausführung“",
    "أ-س-س": "fest gründen, ein Fundament legen; أَسَاس (ʾasās) „Grundlage, Fundament“, مُؤَسَّسَة (muʾassasa) „Institution“",
    "أ-ف-ق": "am Horizont erscheinen, erhaben sein; أُفُق (ʾufuq) „Horizont“",
    "أ-ل-م": "Schmerz empfinden, schmerzen; أَلَم (ʾalam) „Schmerz“",
    "أ-و-ل": "zuerst sein, an der Spitze stehen; أَوَّل (ʾawwal) „erster“",
    "ب-ر-ز": "hervortreten, sich auszeichnen; بَارِز (bāriz) „hervorragend, deutlich sichtbar“",
    "ب-ض-ع": "ein Stück Fleisch abschneiden; بَضَائِع (baḍāʾiʿ) „Waren, Handelsgüter“",
    "ب-ه-ر": "blenden, in Staunen versetzen; اِنْبَهَرَ (inbahara) „geblendet/überwältigt sein“",
    "ت-ل-و": "folgen, nachfolgen, nacheinander kommen; تَالٍ (tālin) „folgender“",
    "ث-ر-و": "reich sein, Vermögen anhäufen; ثَرْوَة (ṯarwa) „Reichtum“",
    "ج-و-ل": "umherziehen, herumschweifen; مَجَال (maǧāl) „Feld, Bereich, Spielraum“",
    "ح-ز-ب": "sich zu einer Gruppe zusammenschließen; حِزْب (ḥizb) „Partei, Gruppe“",
    "ح-ل-ب": "melken; حَلِيب (ḥalīb) „Milch“",
    "ح-ن-ي": "sich krümmen, sich biegen; اِنْحَنَى (inḥanā) „sich beugen“",
    "ح-و-ر": "sich wenden, zurückkehren; حِوَار (ḥiwār) „Wechselrede, Dialog“, حَارَة (ḥāra) „Stadtviertel“",
    "ح-و-ط": "einfassen, umgeben, behutsam behandeln; اِحْتَاطَ (iḥtāṭa) „Vorsicht üben, Vorkehrungen treffen“",
    "ح-ي-ن": "Zeitpunkt, Zeit; أَحْيَانًا (ʾaḥyānan) „manchmal, zu Zeiten“",
    "ح-ي-و": "leben; حَيَوَان (ḥayawān) „Tier, Lebewesen“",
    "خ-ي-ل": "sich einbilden, sich vorstellen; تَخَيَّلَ (taḫayyala) „sich vorstellen“",
    "د-ل-ل": "den Weg weisen, führen, bezeichnen; دَلِيل (dalīl) „Führer, Beweis, Anhaltspunkt“",
    "د-ل-و": "Wasser mit dem Eimer schöpfen; دَلْو (dalw) „Eimer“",
    "د-و-ر": "sich drehen, kreisen, umlaufen; دَوْر (dawr) „Runde, Rolle“, إِدَارَة (idāra) „Verwaltung, Leitung“",
    "د-و-م": "dauern, fortbestehen; دَائِمًا (dāʾiman) „immer, dauerhaft“",
    "ر-خ-و": "schlaff/weich sein; اِسْتَرَخَّ (istaraḫḫa) „erschlaffen, sich entspannen“",
    "ر-ش-ح": "ausschwitzen, (heraus)sickern; مُرَشَّح (muraššaḥ) „(aufgestellter) Kandidat“",
    "ر-غ-ب": "wünschen, begehren, verlangen; رَغْبَة (raġba) „Wunsch, Begehren“",
    "ر-ف-ض": "zurückweisen, ablehnen, verweigern; رَفْض (rafḍ) „Ablehnung“",
    "ر-و-ع": "Angst einjagen, in Erstaunen versetzen; رَائِع (rāʾiʿ) „wunderbar, großartig“",
    "ز-ع-ج": "vertreiben, belästigen; اِنْزَعَجَ (inzaʿaǧa) „sich ärgern, beunruhigt sein“",
    "ز-ل-ز-ل": "heftig erschüttern; زَلْزَال (zalzāl) „Erdbeben“",
    "ز-م-ل": "mitführen, (Reise)gefährte sein; زَمِيل (zamīl) „Kollege, Gefährte“",
    "س-ق-ف": "mit einem Dach versehen, überdecken; سَقْف (saqf) „Dach, Decke“",
    "س-م-ح": "freigiebig sein, erlauben, zulassen; سَمَاح (samāḥ) „Erlaubnis, Großzügigkeit“",
    "س-و-س": "leiten, verwalten, regeln; سِيَاسَة (siyāsa) „Politik, Staatsführung“",
    "ش-أ-ن": "betreffen, angehen; شَأْن (šaʾn) „Angelegenheit, Sache“",
    "ش-ف-ي": "heilen, genesen lassen; مُسْتَشْفًى (mustašfā) „Krankenhaus, Heilstätte“",
    "ش-و-ك": "dornig sein, mit Dornen versehen; شَوْكَة (šawka) „Dorn, Gabel (Besteck)“",
    "ط-ب-ع": "(mit einem Siegel) prägen, von Natur aus beschaffen sein; طَبِيعَة (ṭabīʿa) „Natur, Wesensart“",
    "ط-ب-ق": "überdecken, aufeinanderschichten; طَبَق (ṭabaq) „Teller, Schale; Stockwerk, Schicht“",
    "ط-م-ن": "ruhig/geborgen sein; اِطْمَأَنَّ (iṭmaʾanna) „sich beruhigen, Vertrauen fassen“",
    "ط-و-ر": "sich entwickeln, stufenweise fortschreiten; تَطْوِير (taṭwīr) „Entwicklung, Ausbau“",
    "ظ-ر-ف": "feinsinnig/höflich sein; ظَرْف (ẓarf) „Umstand, Bedingung, Briefumschlag“",
    "ع-ر-ك": "(in der Schlacht) hart kämpfen, reiben; مَعْرَكَة (maʿraka) „Schlacht“",
    "ع-ز-ز": "stark/mächtig sein; اِعْتَزَّ (iʿtazza) „stark sein, sich stark fühlen“",
    "ع-ز-ل": "sich absondern, sich zurückziehen; اِعْتَزَلَ (iʿtazala) „sich zurückziehen“",
    "ع-ز-م": "fest entschlossen sein, fest vorhaben; عَزْم (ʿazm) „Entschluss, fester Wille“",
    "ع-ش-و": "Abend werden, am Abend kommen; عَشَاء (ʿašāʾ) „Abendessen“",
    "ع-ل-ق": "hängen, anhaften, verknüpft sein; عِلَاقَة (ʿilāqa) „Beziehung, Verhältnis“",
    "ع-ل-ن": "offenbar/öffentlich machen; أَعْلَنَ (ʾaʿlana) „ankündigen, bekannt geben“",
    "ع-ن-ي": "sich kümmern, bedacht sein; اِعْتَنَى (iʿtanā) „sich kümmern, Sorge tragen“",
    "ع-و-ن": "helfen, unterstützen, beistehen; تَعَاوُن (taʿāwun) „Zusammenarbeit“, اِسْتِعَانَة (istiʿāna) „Bitte um Hilfe“",
    "غ-ر-ق": "ertrinken, untergehen, (in etwas) versinken; استغراق (istiġrāq) „Vertiefung, Versunkensein“",
    "غ-ل-ل": "eindringen, hineingehen; اِسْتَغَلَّ (istaġalla) „ausnutzen, verwerten, nutzbar machen“",
    "غ-م-ض": "das Auge schließen; غَامِض (ġāmiḍ) „unklar, geheimnisvoll“",
    "ف-ت-ر": "eine Pause machen, nachlassen; فَتْرَة (fatrā) „Zeitraum, Zwischenzeit“",
    "ف-د-ي": "lösen, auslösen, (sich) freikaufen; تَفَادَى (tafādā) „vermeiden, ausweichen“",
    "ف-ر-د": "allein sein, einzeln sein; اِنْفَرَدَ (infarada) „allein sein/bleiben“, مُنْفَرِد (munfarid) „einzeln, allein“",
    "ف-ض-و": "leer/weit sein, ausdehnen; فَضَاء (faḍāʾ) „Raum, (Welt)raum“",
    "ف-ط-ر": "spalten, (den Faden) durchschneiden; فُطُور (fuṭūr) „Frühstück“",
    "ف-ن-ج-ن": "(Lehnwort) Tasse, Schale; فِنْجَان (finǧān) „Tasse“",
    "ف-و-د": "reichen, übersenden; اِسْتَفَادَ (istafāda) „Nutzen ziehen, profitieren“",
    "ف-ي-ض": "überfließen, überfluten; فَيَضَان (fayaḍān) „Überschwemmung, Hochwasser“",
    "ف-ي-ق": "erwachen, zu sich kommen; اِسْتَفَاقَ (istafāqa) „zu sich kommen, aufwachen“",
    "ق-د-ر": "vermögen, fähig sein, (Gott) bestimmen; مِقْدَار (miqdār) „Menge, Betrag, Ausmaß“",
    "ق-ر-ح": "(eine Wunde) aufschlagen, vorschlagen; اِقْتَرَحَ (iqtaraḥa) „vorschlagen“",
    "ق-ص-و": "ans Ende gelangen, genau erforschen; اِسْتَقْصَى (istaqṣā) „gründlich untersuchen“",
    "ق-ع-د": "sitzen, sich setzen; قَاعِدَة (qāʿida) „Basis, Grundlage, Regel“",
    "ق-و-ع": "emporragen; قَاعَة (qāʿa) „Halle, Saal“",
    "ق-ي-م": "von Wert sein, bestehen; قِيمَة (qīma) „Wert, Geltung“",
    "ك-س-ل": "träge/faul sein; كَسْلَان (kaslān) „faul, träge“",
    "م-ع-د": "zur Zeit von etwas sein; مَعِدَة (maʿida) „Magen“",
    "م-ن-أ": "(den Ort) schützen; مِينَاء (mīnāʾ) „Hafen“",
    "م-ه-ر": "geschickt/kundig sein; مَهَارَة (mahāra) „Fertigkeit, Geschicklichkeit“",
    "ن-ب-ت": "wachsen, sprießen; نَبَات (nabāt) „Pflanze, Gewächs“",
    "ن-ج-ز": "erledigen, vollenden, hinausführen; أَنْجَزَ (ʾanǧaza) „erledigen, vollbringen“",
    "ن-خ-ب": "auswählen, bevorzugt erwählen; اِنْتِخَابَات (intikhābāt) „Wahlen“, نَخْبَة (nuḫba) „Elite“",
    "ن-د-ر": "selten vorkommen; نَادِرًا (nādiran) „selten“",
    "ن-ص-ب": "aufstellen, (ein Ehrenamt) übertragen, plagen (Mühsal); مَنْصِب (manṣib) „Amt, Posten“",
    "ن-ص-ف": "die Hälfte sein/bilden; نِصْف (niṣf) „Hälfte“",
    "ن-ف-ع": "nützen, von Nutzen sein; مَنْفَعَة (manfaʿa) „Nutzen, Vorteil“",
    "ن-ق-ب": "durchstechen, durchbohren; نِقَابَة (niqāba) „Gewerkschaft, Berufsverband“",
    "ن-ق-ش": "(ein-)ritzen, ausarbeiten, erörtern; مُنَاقَشَة (munāqaša) „Diskussion, Erörterung“",
    "ن-ق-ط": "punktieren, (mit Punkten) verzieren; نُقْطَة (nuqṭa) „Punkt“",
    "ن-ق-م": "rächen, ahnden; اِنْتَقَمَ (intaqama) „sich rächen“",
    "ن-و-ع": "verschieden/artig sein; نَوْع (nawʿ) „Art, Sorte, Gattung“",
    "ه-ب-ط": "herabsteigen, hinabgehen; هُبُوط (hubūṭ) „das Hinabsteigen“",
    "ه-ت-ف": "rufen, schreien, (leise) rufen; هَاتِف (hātif) „(unsichtbar) Rufender; Telefon (modern)“",
    "ه-د-د": "zerstören, niederreißen; هَدَّدَ (haddada) „drohen“",
    "ه-ز-م": "in die Flucht schlagen, besiegen; هَزِيمَة (hazīma) „Niederlage“",
    "ه-ي-أ": "bereiten, einrichten, gestalten; هَيْئَة (hayʾa) „Gremium, Behörde, Gestalt“",
    "و-ر-أ": "hinter sein/stehen; وَرَاءَ (warāʾa) „hinter“",
    "و-س-ل": "(den Weg) ebnen; وَسِيلَة (wasīla) „Mittel, Weg“",
    "و-ط-ن": "in der Heimat wohnen, sesshaft sein; مُوَاطِن (muwāṭin) „Bürger, Landsmann“",
    "و-ظ-ف": "als Dienst/Aufgabe zuweisen; وِظِيفَة (waẓīfa) „Arbeitsstelle, Amt; Funktion“",
    "و-ع-ب": "in sich aufnehmen, fassen; اِسْتَوْعَبَ (istawʿaba) „umfassen, aufnehmen“",
}


def main() -> int:
    rows: list[dict] = []
    with DEFINITIONS_PATH.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        for row in reader:
            rows.append(row)

    existing = {unicodedata.normalize("NFC", r["root"]) for r in rows}
    added = []
    for root, definition in NEW_DEFINITIONS.items():
        root = unicodedata.normalize("NFC", root)
        if root in existing:
            continue
        rows.append({"root": root, "classical_definition": definition, "source": SOURCE, "example_noun_arabic": ""})
        existing.add(root)
        added.append(root)

    with DEFINITIONS_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"ok: {len(added)} neue Wurzel-Definitionen; {len(rows)} gesamt")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())