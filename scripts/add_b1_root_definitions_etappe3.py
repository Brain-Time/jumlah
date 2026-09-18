#!/usr/bin/env python3
"""Adds the B1 Etappe 3 root definitions to scripts/root_definitions.csv.

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
    "أ-ث-ن": "an einem Zeitpunkt hängen, zeitlich festlegen; أَثْنَاءَ (aṯnāʾa) „während, im Laufe von“",
    "أ-س-ف": "betrübt sein, bedauern; تَأَسَّفَ (taʾassafa) „bedauern, sich entschuldigen“, أَسَف (ʾasaf) „Reue, Bedauern“",
    "أ-ه-ل": "bewohnt sein, ansässig sein; أَهْل (ʾahl) „Leute, Familie, Angehörige“",
    "ب-ر-ع": "gut, vortrefflich sein; تَبَرَّعَ (tabarruʿa) „freiwillig spenden“, تَبَرُّع (tabarruʿ) „Spende“",
    "ب-ص-ر": "sehen, wahrnehmen, einsichtig sein; بَصِير (baṣīr) „einsichtig, sehend“, بَصَر (baṣar) „Sehkraft, Blick“",
    "ب-ه-ج": "heiter, freudig sein; بَهِيج (bahīǧ) „strahlend, fröhlich“, بَهْجَة (bahǧa) „Freude, Heiterkeit“",
    "ب-ه-ي": "anstaunen, sich brüsten; تَبَاهَى (tabāhā) „stolz sein, prahlen“, تَبَاهٍ (tabāhin) „das Prahlen“",
    "ت-ل-ل": "aufhäufen, emporragen; تَلّ (tall) „Hügel, Anhöhe“",
    "ج-ر-أ": "kühn, verwegen sein; جَرِيء (ǧarīʾ) „kühn, wagemutig“, جُرْأَة (ǧurʾa) „Kühnheit“",
    "ج-ر-ح": "(die Haut) verletzen, verwunden; جَرْح (ǧarḥ) „Wunde“, جِرَاحَة (ǧirāḥa) „Wunde, Chirurgie“",
    "ج-م-ه-ر": "sich in Menge versammeln; جُمْهُور (ǧumhūr) „Publikum, Masse, Volksmenge“",
    "ج-و-ه": "eine Stellung einnehmen, Würde besitzen; جَاه (ǧāh) „Ansehen, Würde, Rang“",
    "ح-ج-ز": "abtrennen, absperren, zurückhalten; حَجَزَ (ḥaǧaza) „reservieren, zurückhalten“, حَجْز (ḥaǧz) „Reservierung, Sperre“",
    "ح-ج-م": "zusammenballen, ein Ganzes sein; حَجْم (ḥaǧm) „Volumen, Umfang, Größe“",
    "ح-س-د": "beneiden, neidisch sein; حَسُود (ḥasūd) „neidisch“, حَسَد (ḥasad) „Neid, Missgunst“",
    "ح-ص-ر": "eingrenzen, einschließen; اِنْحَصَرَ (inḥaṣara) „beschränkt sein, sich eingrenzen“, حَصْر (ḥaṣr) „Beschränkung“",
    "ح-م-س": "glühen, entflammt sein; حَمَاسَة (ḥamāsa) „Begeisterung, Enthusiasmus“, مُتَحَمِّس (mutaḥammis) „begeistert“",
    "خ-ر-ط": "zurechtschneiden, zeichnen; خَرِيطَة (ḫarīṭa) „Landkarte“",
    "خ-ص-ب": "fruchtbar, üppig sein; خَصِب (ḫaṣib) „fruchtbar, ergiebig“, خِصْب (ḫiṣb) „Fruchtbarkeit“",
    "خ-ط-ب": "(eine Rede) halten, ansprechen; خِطَاب (ḫiṭāb) „Rede, Ansprache“, خُطْبَة (ḫuṭba) „Ansprache, Predigt“",
    "خ-ط-و": "schreiten, einen Schritt tun; تَخَطَّى (taḫaṭṭā) „überschreiten, hinwegschreiten“, خَطْوَة (ḫaṭwa) „Schritt“",
    "د-ب-ر": "hinterherkommen, (die Dinge) ordnen; دَبَّرَ (dabbara) „planen, verwalten“, تَدْبِير (tadbīr) „Planung, Verwaltung“",
    "د-خ-ن": "rauchen, qualmen; دُخَان (duḫān) „Rauch, Qualm“",
    "د-س-ت-ر": "(pers. Lehnwort) die Ordnung des Staates; دُسْتُور (dustūr) „Verfassung, Grundgesetz“",
    "د-ه-ر": "lange Zeit dauern; دَهْر (dahr) „Zeit, Zeitalter, Welt“",
    "د-ه-ش": "betroffen, verblüfft sein; اِنْدَهَشَ (indahaša) „verblüfft sein, staunen“, دَهْشَة (dahša) „Verblüffung“",
    "ر-ب-م": "(Partikel) vielleicht, möglicherweise; رُبَّمَا (rubbamā) „vielleicht, womöglich“",
    "ر-س-خ": "fest, tief verwurzelt sein; رَاسِخ (rāsiḫ) „gefestigt, fest verankert“, رُسُوخ (rusūḫ) „Festigkeit, Festgegründetsein“",
    "ر-ش-د": "den rechten Weg finden, mündig sein; اِسْتَرْشَدَ (istaršada) „um Rat bitten, sich führen lassen“, رُشْد (rušd) „Rechtleitung, Reife“",
    "ر-ض-ي": "zufrieden sein, wohlgefällig sein; أَرْضَى (ʾarḍā) „zufriedenstellen“, رِضًا (riḍan) „Zufriedenheit, Wohlgefallen“",
    "ر-ع-ي": "weiden, hüten, fürsorgen; رِعَايَة (riʿāya) „Fürsorge, Pflege, Obhut“, رَاعٍ (rāʿin) „Hirte, Beschützer“",
    "ر-غ-م": "gegen den Willen, unwillig sein; رُغْم (ruġm) „trotz, ungeachtet“, رَغْمًا (raġman) „trotzdem“",
    "ر-م-د": "(zur Asche) verbrennen; رَمَاد (ramād) „Asche“",
    "ز-ب-ن": "drängen, abstoßen (im Kauf); زَبُون (zabūn) „Kunde, Abnehmer“",
    "ز-ر-ر": "fest zusammenziehen, zuknöpfen; زِرّ (zirr) „Knopf“",
    "ز-ع-م": "behaupten, Führung beanspruchen; زَعِيم (zaʿīm) „Führer, Wortführer“, زَعَامَة (zaʿāma) „Führerschaft“",
    "س-ر-ف": "übermäßig ausgeben, verschwenden; أَسْرَفَ (ʾasrafa) „verschwenden, übertreiben“, إِسْرَاف (ʾisrāf) „Verschwendung“",
    "س-ط-ع": "hell leuchten, glänzen; سَاطِع (sāṭiʿ) „hell, strahlend“, سُطُوع (sutūʿ) „das Strahlen, Leuchten“",
    "س-ع-ر": "anzünden, (den Preis) festsetzen; سِعْر (siʿr) „Preis, Kurs“",
    "س-ل-ك": "einen Weg gehen, sich verhalten; سَلَكَ (salaka) „gehen, einschlagen“, سُلُوك (sulūk) „Verhalten, Benehmen“",
    "س-م-ي": "hoch sein, benannt werden; سَمَّى (sammā) „nennen, benennen“, تَسْمِيَة (tasmiya) „Benennung“, اِسْم (ism) „Name“",
    "ص-ب-ن": "mit Seife behandeln; صَابُون (ṣābūn) „Seife“",
    "ص-ح-ب": "begleiten, in Gesellschaft sein; صَاحِب (ṣāḥib) „Besitzer, Gefährte“, مُصَاحَبَة (muṣāḥaba) „Begleitung“",
    "ص-ل-ب": "hart, fest sein; صُلْب (ṣulb) „hart, fest; Rückgrat“, صَلَابَة (ṣalāba) „Härte, Festigkeit“",
    "ص-و-ب": "richtig treffen, zielen; أَصَابَ (ʾaṣāba) „treffen, richtig liegen“, صَوَاب (ṣawāb) „das Richtige, Treffende“",
    "ض-ج-ج": "laut schreien, lärmen; ضَجِيج (ḍaǧīǧ) „Lärm, Getöse“, ضَجَّة (ḍaǧǧa) „Lärm, Tumult“",
    "ض-ح-ي": "(zur Mittagszeit) opfern; ضَحِيَّة (ḍaḥiyya) „Opfer, Opfertier“",
    "ط-ر-ح": "hinwerfen, (eine Frage) aufwerfen; طَرَّحَ (ṭarraḥa) „aufwerfen, vorlegen“, طَرْح (ṭarḥ) „das Aufwerfen, Vorlage, Subtraktion“",
    "ع-ج-ز": "unfähig sein, zurückbleiben; عَاجِز (ʿāǧiz) „unfähig, machtlos“, عَجْز (ʿaǧz) „Unfähigkeit, Schwäche“",
    "ع-د-ن": "(an einem Ort) verweilen, bleiben; مَعْدِن (maʿdin) „Metall, Bergwerk; Ursprung“",
    "ع-ض-و": "(in Glieder) zerteilen; عُضْو (ʿuḍw) „Mitglied, Glied“",
    "ع-ط-ل": "leer stehen, unbeschäftigt sein; عَطْلَة (ʿaṭla) „Urlaub, Muße“, عُطْلَة (ʿuṭla) „Arbeitslosigkeit“",
    "غ-ذ-و": "nähren, speisen; تَغَذَّى (taġaḏḏā) „sich ernähren“, غِذَاء (ġiḏāʾ) „Nahrung, Speise“",
    "غ-ز-ر": "reichlich geben, reichlich sein; غَزِير (ġazīr) „ergiebig, reichlich“, غَزَارَة (ġazāra) „Fülle, Überfluss“",
    "غ-ص-ن": "einen Zweig treiben; غُصْن (ġuṣn) „Zweig, Ast“",
    "غ-ل-و": "übertrieben teuer sein; غَلَاء (ġalāʾ) „Teuerung, Preissteigerung“, غَالٍ (ġālin) „teuer, kostspielig“",
    "ف-خ-ر": "rühmen, stolz sein; تَفَاخَرَ (tafāḫara) „prahlen, sich rühmen“, فَخْر (faḫr) „Stolz, Ruhm“",
    "ف-ل-ك": "die Himmelskugel umkreisen; فَلَك (falak) „Himmelsphäre, Sphäre“, فَلَكِيّ (falakiyy) „astronomisch“",
    "ف-ل-م": "(Lehnwort für das Kunstwerk Film); فِلْم (film) „Film, Streifen“",
    "ف-و-ت": "entgehen, vorbeigehen; تَفَاوَتَ (tafāwata) „sich unterscheiden, auseinandergehen“, فَوْت (fawt) „das Entgehen, Überschreitung“",
    "ق-د-ح": "(Holz) krumm schneiden, drechseln; قَدَح (qadaḥ) „Becher, Trinkgefäß“",
    "ق-ل-د": "(den Hals) umhängen, nachahmen; تَقْلِيد (taqlīd) „Tradition, Nachahmung“, قِلَادَة (qilāda) „Halskette“",
    "ق-ن-ع": "zufrieden, genügsam sein; أَقْنَعَ (ʾaqnaʿa) „überzeugen“, قَنُوع (qanūʿ) „genügsam“, قِنَاعَة (qināʿa) „Überzeugung, Genügsamkeit“",
    "ك-م-م": "bedecken, überdecken; كَمِّيَّة (kammiyya) „Menge, Quantität“",
    "ل-خ-ص": "das Wesentliche zusammenfassen; مُلَخَّص (mulaḫḫaṣ) „Zusammenfassung, Abriss“, تَلْخِيص (talḫīṣ) „Zusammenfassung“",
    "ل-ش-ي": "vergehen, verblassen; تَلَاشَى (talāšā) „verblassen, verschwinden“, تَلَاشٍ (talāšin) „das Verblassen, die Auflösung“",
    "ل-ه-ب": "brennen, (zur Flamme) auflodern; لَهَب (lahab) „Flamme, Lohe“",
    "م-ت-ن": "fest, stämmig sein; مَتِين (matīn) „stabil, fest, zuverlässig“, مَتَانَة (matāna) „Festigkeit, Stabilität“",
    "م-ر-س": "geübt sein, (etwas) betreiben; مَارَسَ (mārasa) „ausüben, betreiben“, مُمَارَسَة (mumārasa) „Ausübung, Praxis“",
    "م-و-ج": "wogen, wallen; مَوْجَة (mawǧa) „Welle“, مَوْج (mawǧ) „Wogen, Wellen“",
    "ن-ز-ه": "(ins Freie) hinausziehen; نُزْهَة (nuzha) „Ausflug, Vergnügungsfahrt“, تَنَزُّه (tanazzuh) „Spaziergang“",
    "ن-ش-د": "laut rufen, (ein Gedicht) vortragen; نَشِيد (našīd) „Hymne, Gesang“, أَنْشَدَ (ʾanšada) „vortragen, singen“",
    "ن-ص-ص": "an die richtige Stelle setzen, ordnen; نَصّ (naṣṣ) „Text, Wortlaut“",
    "ن-ط-ق": "sprechen, deutlich aussprechen; نُطْق (nuṭq) „Rede, Sprache“, مِنْطَقَة (minṭaqa) „Zone, Gebiet“ (urspr. „Gürtel“)",
    "ن-غ-م": "angenehm tönen, musizieren; نَغْمَة (naġma) „Melodie, Ton“, نَغَم (naġam) „Wohlklang“",
    "ن-و-ب": "abwechseln, stellvertreten; نَائِب (nāʾib) „Stellvertreter, Abgeordneter“, نِيَابَة (niyāba) „Stellvertretung“",
    "ن-و-ي": "beabsichtigen, im Sinn haben; نِيَّة (niyya) „Absicht, Vorhaben“",
    "ه-ن-ك": "(Ortsadverb) dort, dorthin; هُنَاكَ (hunāka) „dort, dorthin“",
    "و-ج-ع": "Schmerz fühlen, schmerzen; أَوْجَعَ (ʾawǧaʿa) „Schmerz zufügen“, وَجَع (waǧʿ) „Schmerz, Wehtun“",
    "ي-ق-ن": "sicher sein, gewiss sein; يَقِين (yaqīn) „Gewissheit, Gewissheit“, أَيْقَنَ (ʾayqana) „gewiss sein, überzeugt sein“",
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