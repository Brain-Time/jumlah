#!/usr/bin/env python3
"""Adds the B1 Etappe 2 root definitions to scripts/root_definitions.csv.

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
    "أ-د-و": "auf einen Zweck hin richten, bereitstellen; أَدَاة (ʾadāt) „Gerät, Werkzeug, Instrument“",
    "أ-ز-ي": "gleichen, gegenüberstehen; إِزَاءَ (ʾizāʾa) „gegenüber, angesichts“",
    "أ-ك-د": "fest, gewiss machen, bestätigen; تَأْكِيد (taʾkīd) „Bestätigung“",
    "أ-و-ي": "sich zurückziehen, Zuflucht suchen; مَأْوًى (maʾwan) „Zufluchtsort“, إِيَاء (ʾīyāʾ) „Zufluchtsuchen“",
    "ب-د-و": "(in der Wüste) erscheinen, sichtbar werden; أَبْدَى (ʾabdā) „äußern, zeigen“",
    "ب-ر-أ": "frei sein von, (von Schuld) lossprechen; بَرِيء (barīʾ) „unschuldig, frei von“",
    "ب-ر-ر": "fromm, gütig sein; بَرَّرَ (barrara) „rechtfertigen“, بَرّ (barr) „Festland; Güte“",
    "ب-ر-ك": "niederwerfen, (Lasttier) niederknien lassen; بَارَكَ (bāraka) „segnen, beglückwünschen“, بَرَكَة (baraka) „Segen“",
    "ب-ش-ر": "Hautoberfläche; frohe Botschaft bringen; مُبَاشَرَةً (mubāšaratan) „direkt, unmittelbar“",
    "ب-ك-ر": "früh sein, zuerst sein; اِبْتَكَرَ (ibtakara) „neu schaffen, erstmals hervorbringen“",
    "ب-ل-ع": "verschlingen, hinunterschlucken; اِبْتِلَاع (ibtilāʿ) „das Schlucken“",
    "ب-و-ح": "offen aussprechen, kundtun; أَبَاحَ (ʾabāḥa) „freigeben, erlauben“, مُبَاح (mubāḥ) „erlaubt“",
    "ت-أ-م": "gepaart, doppelt sein; تَوْأَم (tawʾam) „Zwilling“",
    "ت-ح-ف": "erfreuen, ein Geschenk darbringen; مَتْحَف (matḥaf) „Museum“ (Schatzhaus der Kunst)",
    "ت-م-م": "vollenden, vollständig machen; تَمَامًا (tamāman) „völlig, ganz“",
    "ث-ب-ت": "feststehen, fest sein, dauerhaft sein; ثَابِت (ṯābit) „fest, beständig“, تَثْبِيت (taṯbīt) „Befestigung“",
    "ج-ح-د": "verweigern, ableugnen; جُحُود (ǧuḥūd) „die Verleugnung“, جَاحِد (ǧāḥid) „Leugner“",
    "ج-ر-ر": "ziehen, schleppen, nachschleifen; جَرَّ (ǧarra) „ziehen“, جَرّ (ǧarr) „das Ziehen; der Genitiv (Gramm.)“",
    "ج-ز-ي": "vergelten, belohnen, bestrafen; جَزَاء (ǧazāʾ) „Strafe, Vergeltung, Lohn“",
    "ج-م-د": "erstarren, gefrieren, fest werden; جَمَد (ǧamad) „Eis“, تَجَمَّدَ (taǧammada) „gefrieren“",
    "ح-ث-ث": "antreiben, anspornen, eilen lassen; حَثَّ (ḥaṯṯa) „antreiben“, حَثّ (ḥaṯṯ) „der Antrieb“",
    "ح-د-ر": "herabsteigen lassen, abwärtsführen; اِنْحَدَرَ (inḥadara) „absteigen, abfallen“, اِنْحِدَار (inḥidār) „Abstieg“",
    "ح-د-ي": "(den Gesang) antreiben, herausfordern; تَحَدَّى (taḥaddā) „herausfordern“, تَحَدٍّ (taḥaddin) „Herausforderung“",
    "ح-ر-ف": "abwenden, schräg abbiegen; حَرْف (ḥarf) „Buchstabe, Rand, Kante“, اِنْحَرَفَ (inḥarafa) „abweichen“",
    "ح-ر-ك": "sich bewegen, in Bewegung setzen; حَرَكَة (ḥaraka) „Bewegung, Vokalzeichen“, مُحَرِّك (muḥarrik) „Motor“",
    "ح-س-س": "empfinden, wahrnehmen, fühlen; حَاسَّة (ḥāssa) „Sinnesorgan“, إِحْسَاس (ʾiḥsās) „Empfindung, Gefühl“",
    "ح-س-م": "abschneiden, entscheiden, beenden; حَسَمَ (ḥasama) „entscheiden, beenden“, حَاسِم (ḥāsim) „endgültig“",
    "ح-ص-ص": "besonders zuteilen, abteilen; حِصَّة (ḥiṣṣa) „Anteil, Portion“",
    "ح-ص-ي": "zählen, erfassen, genau berechnen; أَحْصَى (ʾaḥṣā) „zählen, erfassen“, إِحْصَاء (ʾiḥṣāʾ) „statistische Erfassung“",
    "ح-ض-ض": "scharf antreiben, anstacheln; حَضَّ (ḥaḍḍa) „antreiben“, تَحْضِيض (taḥḍīḍ) „Ansporn“",
    "ح-ف-ر": "graben, ausschachten; حَفَرَ (ḥafara) „graben“, حُفْرَة (ḥufra) „Grube, Loch“",
    "ح-ل-ف": "einen Schwur ablegen, beschwören; حَلَفَ (ḥalafa) „schwören“, حَلِيف (ḥalīf) „Bündnispartner“",
    "ح-و-ض": "um etwas herumgehen, ein Becken fassen; حَوْض (ḥawḍ) „Becken, Bassin“, حَوْضَة „Teich“",
    "ح-ي-ث": "Ort und Stelle der Relativierung; حَيْثُ (ḥayṯu) „wo, wobei“ (Relativ-Adverb)",
    "خ-ب-أ": "verbergen, verstecken; خَبَأَ (ḫabaʾa) „verstecken“, خَبَأ „das Versteckte“",
    "خ-د-ع": "betrügen, täuschen, hintergehen; خَدَعَ (ḫadaʿa) „betrügen“, خِدَاع (ḫidāʿ) „Betrug“",
    "خ-ر-ب": "zerstören, verwüsten; خَرَّبَ (ḫarraba) „verwüsten“, خَرَاب (ḫarāb) „Verwüstung, Ruine“",
    "خ-ر-ع": "erfinden, neu hervorbringen; اِخْتَرَعَ (iḫtaraʿa) „erfinden“, اِخْتِرَاع (iḫtirāʿ) „Erfindung“",
"خ-ط-ط": "Linien ziehen, entwerfen, planen; خِطَّة (ḫiṭṭa) „Plan, Vorhaben“, خَطّ (ḫaṭṭ) „Linie, Schrift“",
    "خ-ف-ق": "den Puls schlagen lassen, fehlschlagen; أَخْفَقَ (ʾaḫfaqa) „scheitern“, إِخْفَاق (ʾiḫfāq) „Fehlschlag“",
    "خ-ل-ص": "rein, unvermischt sein, loskommen; خَلَاص (ḫalāṣ) „Rettung, Befreiung“, خُلَاصَة (ḫulāṣa) „Zusammenfassung, Extrakt“",
    "خ-ل-ط": "vermischen, durcheinanderbringen; اِخْتَلَطَ (iḫtalaṭa) „sich vermischen“",
    "خ-ل-ل": "durchbohren, durchdringen, zwischensein; خِلَالَ (ḫilāla) „während, im Laufe“, خِلَال „Lücke, Zwischenraum“",
    "خ-ل-و": "leer sein, allein sein; تَخَلَّى (taḫallā) „verzichten auf“, خَالٍ (ḫālin) „leer, frei“",
    "د-ب-ب": "kriechen, auf allen vieren gehen; دُبّ (dubb) „Bär“, دَبَّابَة „Panzer, Käfer“",
    "د-خ-ر": "zurücklegen, aufspeichern; اِدَّخَرَ (iddaḫara) „sparen, zurücklegen“, ذَخِيرَة (ḏaḫīra) „Vorrat“",
    "د-ر-ب": "(einen Weg) eben machen, üben; تَدْرِيب (tadrīb) „Training, Übung“",
    "د-ف-أ": "warm sein; دِفْء (difʾ) „Wärme“, مِدْفَأَة (midfaʾa) „Heizung, Ofen“, تَدَفَّأَ (tadaffaʾa) „sich wärmen“",
    "د-ف-ق": "strömen, sich ergießen; تَدَفَّقَ (tadaffaqa) „strömen“, تَدَفُّق (tadaffuq) „das Strömen“",
    "د-م-ر": "vernichten, zerstören; دَمَّرَ (dammara) „zerstören“, تَدْمِير (tadmīr) „Zerstörung“",
    "د-و-ن": "unter, ohne (Präposition); دُونَ (dūna) „ohne, unterhalb von, diesseits“",
    "ذ-ك-و": "lebendig, glühend sein, scharf (Geist); ذَكَاء (ḏakāʾ) „Intelligenz, Scharfsinn“",
    "ذ-ل-ك": "jener, das (Demonstrativ); لِذَلِكَ (li-ḏālika) „deshalb, deswegen“",
    "ذ-م-م": "tadeln, beschuldigen; ذَمَّ (ḏamma) „tadeln“, ذَمّ (ḏamm) „Tadel“",
    "ذ-و-ب": "zerfließen, schmelzen; ذَابَ (ḏāba) „schmelzen“, ذَوَبَان (ḏawabān) „das Schmelzen“",
    "ذ-و-ق": "schmecken, kosten; ذَاقَ (ḏāqa) „kosten“, تَذَوَّقَ (taḏawwaqa) „kosten“, ذَوْق (ḏawq) „Geschmack“",
    "ر-ح-ب": "breit sein, freundlich empfangen; رَحَّبَ (raḥḥaba) „willkommen heißen“, تَرْحِيب (tarḥīb) „Willkommensgruß“",
    "ر-ز-ق": "(den Unterhalt) gewähren, bescheren; رِزْق (rizq) „Lebensunterhalt, Nahrung“",
    "ر-ض-ع": "saugen, stillen; رَضِيع (raḍīʿ) „Säugling“, رَضَاعَة (raḍāʿa) „das Stillen“",
    "ر-ف-ف": "schweben, flattern, (Obst) reif herabhängen; رَفّ (raff) „Regal, Sims“",
    "ر-ق-ي": "hinaufsteigen, aufsteigen; اِرْتَقَى (irtaqā) „aufsteigen, aufrücken“, رُقِيّ (ruqiyy) „Aufstieg, Fortschritt“",
    "ز-ح-م": "drängen, zusammendrängen; مُزْدَحِم (muzdaḥim) „überfüllt, voll“, زَحْم (zaḥm) „Gedränge“",
    "ز-ق-ق": "eng machen, (eine Öffnung) verengen; زُقَاق (zuqāq) „Gasse, Sackgasse“",
    "ز-ل-ق": "gleiten, ausrutschen; اِنْزَلَقَ (inzalaqa) „ausrutschen“, زَلِيق „glatt“",
    "ز-ل-ل": "ausgleiten, einen Fehltritt tun; زَلَّ (zalla) „ausrutschen“, زَلَّة (zalla) „Fehltritt, Ausrutscher“",
    "س-ج-ل": "aufschreiben, (gerichtlich) protokollieren; سَجَّلَ (saǧǧala) „aufnehmen, registrieren“, سِجِلّ (siǧill) „Register“",
    "س-ج-م": "tropfenweise strömen, gleichmäßig fließen; اِنْسَجَمَ (insaǧama) „zusammenpassen, harmonieren“",
    "س-ط-ر": "eine Zeile schreiben, einreihen; مِسْطَرَة (misṭara) „Lineal“, سَطْر (saṭr) „Zeile“",
    "س-ع-ل": "husten; سَعَلَ (saʿala) „husten“, سُعَال (suʿāl) „Husten“",
    "س-ك-ب": "ausgießen, verschütten; سَكَبَ (sakaba) „gießen“, سَكْب (sakb) „das Gießen“",
    "س-ل-ب": "rauben, entziehen, (etwas) ausziehen; سَلَبَ (salaba) „rauben“, سَلْب (salb) „Raub, das Nehmen“",
    "س-ه-ر": "wach bleiben, schlaflos sein; سَهِرَ (sahira) „nachtwach sein“, سَهَر (sahar) „Nachtwachen, Schlaflosigkeit“",
    "س-و-م": "(einen Preis) ausrufen, feilschen; سَاوَمَ (sāwama) „feilschen, handeln“, مُسَاوَمَة (musāwama) „Feilschen“",
    "س-ي-ب": "freilassen, strömen lassen; اِنْسَابَ (insāba) „dahinfließen, sich ergießen“",
    "ش-أ-م": "unglücklich, unheilvoll sein; تَشَاءَمَ (tašāʾama) „pessimistisch sein“, شُؤْم (šuʾm) „Unheil, Pessimismus“",
    "ش-ع-ل": "aufflammen, anzünden; أَشْعَلَ (ʾašʿala) „anzünden“, اِشْتَعَلَ (ištaʿala) „brennen, entflammen“",
    "ش-ق-ق": "spalten, zerreißen; شَقَّ (šaqqa) „spalten“, شِقّ (šiqq) „Hälfte, Seite“",
    "ش-م-ع": "Wachskerze; شَمْع (šamʿ) „Wachs“, شَمْعَة (šamʿa) „Kerze“",
    "ش-و-ق": "heißes Verlangen haben; اِشْتَاقَ (ištāqa) „sich sehnen“, شَوْق (šawq) „Sehnsucht“",
    "ش-و-ل": "(den Schwanz) aufheben, hochheben; شَالَ (šāla) „hochheben“, شَوْل „das Hochheben“",
    "ش-ي-د": "hoch bauen, errichten; شَيَّدَ (šayyada) „errichten“, تَشْيِيد (tašyīd) „Errichtung“",
    "خ-ش-ي": "fürchten, sich scheuen; خَشِيَ (ḫašiya) „fürchten“, خَشْيَة (ḫašya) „Furcht, Scheu“",
    "خ-ص-ر": "eng machen, kürzen, einschränken; اِخْتَصَرَ (iḫtaṣara) „kürzen, zusammenfassen“",
"ص-ب-ب": "ausgießen, strömen lassen; صَبَّ (ṣabba) „gießen, ausgießen“, صَبّ (ṣabb) „das Gießen“",
    "ص-ن-ف": "einteilen, klassifizieren, sortieren; صَنَّفَ (ṣannafa) „einteilen“, تَصْنِيف (taṣnīf) „Klassifikation“",
    "ض-د-د": "entgegensetzen, widerstreiten; ضِدَّ (ḍidda) „gegen“, ضِدّ (ḍidd) „Gegenteil, Gegner“",
    "ض-غ-ط": "zusammendrücken, pressen, bedrücken; ضَغَطَ (ḍaġaṭa) „drücken“, ضَغْط (ḍaġṭ) „Druck“",
    "ض-م-ر": "(im Verborgenen) hegen; ضَمِير (ḍamīr) „Gewissen; innerer Gedanke“",
    "ض-م-ن": "verbürgen, einstehen für, enthalten; ضَمَان (ḍamān) „Garantie“, ضَمِين (ḍamīn) „Bürge“",
    "ض-و-أ": "leuchten, hell sein; ضَوْء (ḍawʾ) „Licht, Schein“, أَضَاءَ (ʾaḍāʾa) „beleuchten“",
    "ط-ر-ف": "einen Zipfel/Ende haben, blinzeln; طَرَف (ṭaraf) „Seite, Ende, Partei“",
    "ط-ر-و": "frisch, neu sein; طَرِيّ (ṭariyy) „frisch, neu, zart“",
    "ط-ف-أ": "löschen, erlöschen; أَطْفَأَ (ʾaṭfaʾa) „auslöschen“, اِنْطَفَأَ (inṭafaʾa) „erlöschen“",
    "ط-و-ي": "falten, zusammenlegen, durchwandern; طَوَى (ṭawā) „falten, durchreisen“, طَيّ (ṭayy) „das Falten“",
    "ع-ث-ر": "stolpern, straucheln, (zufällig) finden; عَثَرَ (ʿaṯara) „stolpern, finden“, عُثُور „das Finden“",
    "ع-س-ر": "schwer, schwierig sein; عَسِير (ʿasīr) „schwierig, schwer“, عُسْر (ʿusr) „Not, Schwierigkeit“",
    "ع-ط-س": "niesen; عَطَسَ (ʿaṭasa) „niesen“, عُطَاس (ʿuṭās) „das Niesen“",
    "ع-ف-و": "verzeihen, auslöschen, genesen; تَعَافَى (taʿāfā) „genesen“, عَفْو (ʿafw) „Verzeihung“",
    "ع-ك-س": "umkehren, umdrehen, reflektieren; اِنْعَكَسَ (inʿakasa) „sich spiegeln, sich umkehren“, عَكْس (ʿaks) „Gegenteil“",
    "ع-م-ر": "lange leben, bebauen, besiedeln; عِمَارَة (ʿimāra) „Gebäude, Bauwerk“, عُمْرَان „zivilisierte Erschließung“",
    "ع-و-ض": "(mit etwas) ersetzen, entschädigen; عَوَّضَ (ʿawwaḍa) „entschädigen“, تَعْوِيض (taʿwīḍ) „Entschädigung“",
    "غ-ب-و": "stumpf, unverständig sein; غَبَاء (ġabāʾ) „Dummheit, Unverstand“, غَبِيّ (ġabiyy) „dumm, unerfahren“",
    "غ-ر-م": "schulden, eine Buße zahlen müssen; غَرَامَة (ġarāma) „Bußgeld, Strafzahlung“, غُرْم (ġurm) „Schuld“",
    "غ-ل-ب": "überwinden, besiegen; غَلَبَ (ġalaba) „besiegen“, غَالِبًا (ġāliban) „meistens, gewöhnlich“",
    "غ-ل-ي": "sieden, kochen, wallen; غَلَى (ġalā) „sieden, aufkochen“, غَلَيَان (ġalayān) „das Sieden“",
    "ف-أ-ل": "(günstige Vorbedeutung) erhoffen; تَفَاءَلَ (tafāʾala) „optimistisch sein“, مُتَفَائِل (mutafāʾil) „optimistisch“",
    "ف-أ-ي": "sich zerteilen, (in Gruppen) teilen; فِئَة (fiʾa) „Kategorie, Gruppe, Schar“",
    "ف-ت-ش": "durchsuchen, untersuchen, auskundschaften; فَتَّشَ (fattaša) „durchsuchen“, تَفْتِيش (taftīš) „Durchsuchung“",
    "ف-ح-ص": "genau untersuchen, prüfen; فَحَصَ (faḥaṣa) „untersuchen“, فَحْص (faḥṣ) „Untersuchung“",
    "ف-ر-ع": "(einen Zweig) treiben, sich ausbreiten; فَرْع (farʿ) „Zweig, Filiale, Teilbereich“",
    "ف-س-د": "verderben, verfaulen, untauglich sein; فَاسِد (fāsid) „verdorben, korrupt“, فَسَاد (fasād) „Verderbnis“",
    "ف-س-ر": "erklären, deuten, auslegen; فَسَّرَ (fassara) „erklären“, تَفْسِير (tafsīr) „Deutung, Kommentar“",
    "ف-ض-ل": "übertreffen, vorzüglich sein; فَضِيلَة (faḍīla) „Tugend, Vorzug“, فَاضِل (fāḍil) „tugendhaft“",
    "ف-ك-ك": "lösen, aufbinden, (Gefangenen) freikaufen; فَكَّ (fakka) „lösen, aufmachen“, فَكّ (fakk) „das Lösen“",
    "ف-و-ر": "(Quelle) sprudeln, hervorströmen; فَوْرًا (fawran) „sofort, auf der Stelle“, فَوَرَان „das Sprudeln“",
    "ف-و-ض": "hin und her gehen lassen, verhandeln; فَاوَضَ (fāwaḍa) „verhandeln“, مُفَاوَضَة (mufāwaḍa) „Verhandlung“",
    "ق-ب-ض": "ergreifen, fassen, (die Hand) zusammenziehen; قَبَضَ (qabaḍa) „ergreifen, einziehen“, قَبْض (qabḍ) „Griff, Festnahme“",
    "ق-ذ-ر": "schmutzig, unrein sein; قَذِر (qaḏir) „schmutzig, ekelvoll“, قَذَر (qaḏar) „Schmutz, Unrat“",
    "ك-ر-ر": "wiederholen, zurückkehren (lassen); كَرَّرَ (karrara) „wiederholen“, تَكْرَار (takrār) „Wiederholung“",
    "ك-ف-أ": "gleichkommen, entsprechen, (jemanden) belohnen; كَافَأَ (kāfaʾa) „belohnen“, كُفْء (kufʾ) „Ebenbürtiger“",
    "ك-ف-ف": "aufhören, zurückhalten, abhalten; كَفَّ (kaffa) „aufhören, abhalten“, كَفّ (kaff) „Handfläche; das Aufhören“",
    "ك-ف-ل": "verbürgen, sorgen für, in Pflege nehmen; كَفَالَة (kafāla) „Bürgschaft, Garantie“, كَفِيل (kafīl) „Bürge“",
    "ل-ح-ق": "einholen, erreichen, nachfolgen; لَحِقَ (laḥiqa) „einholen, erreichen“, لُحُوق (luḥūq) „das Einholen“",
    "ل-د-ي": "bei, anwesend bei (Präposition); لَدَى (ladā) „bei, an, in Gegenwart von“",
    "ل-ز-م": "fest anliegen, notwendig sein; لَازِم (lāzim) „notwendig, nötig“, لُزُوم (luzūm) „Notwendigkeit“",
    "ل-ص-ص": "stehlen, als Dieb rauben; لِصّ (liṣṣ) „Dieb, Räuber“",
    "ل-غ-ي": "(ein Gesetz) aufheben, für ungültig erklären; أَلْغَى (ʾalġā) „absagen, aufheben“, إِلْغَاء (ʾilġāʾ) „Absage, Annullierung“",
    "ل-ف-ت": "herumwenden, sich umdrehen; اِلْتَفَتَ (iltafata) „sich umwenden“, اِلْتِفَات (iltifāt) „Hinwendung, Aufmerksamkeit“",
    "ل-ف-ف": "wickeln, umhüllen; لَفَّ (laffa) „wickeln, einrollen“, لَفّ (laff) „das Wickeln; Umschlag“",
"ل-ق-م": "(einen Bissen) in den Mund nehmen; لُقْمَة (luqma) „Bissen, Happen“",
    "ل-م-س": "berühren, betasten, (er)suchen; اِلْتَمَسَ (iltamasa) „ersuchen, suchen“, لَمْس (lams) „Berührung“",
    "ل-م-ع": "glänzen, aufblitzen; لَمَعَ (lamaʿa) „glänzen, blitzen“, لَمَعَان (lamaʿān) „Glanz, Funkeln“",
    "م-د-ح": "loben, preisen; اِمْتَدَحَ (imtadaḥa) „loben“, مَدْح (madḥ) „Lob, Lobpreis“",
    "م-ز-ج": "vermischen, umrühren; مِزَاج (mizāǧ) „Gemüt, Temperament, Mischung“",
    "م-ز-ق": "zerreißen, zerfetzen; مَزَّقَ (mazzaqa) „zerreißen“, تَمْزِيق (tamzīq) „das Zerreißen“",
    "م-ش-ط": "kämmen; مُشْط (mušt) „Kamm“, تَمْشِيط „das Kämmen“",
    "م-ن-ي": "(sich) wünschen, erhoffen; تَمَنَّى (tamannā) „sich wünschen“, تَمَنٍّ (tamannin) „der Wunsch“",
    "م-ي-ز": "absondern, auszeichnen; اِمْتِيَاز (imtiyāz) „Vorzug, Privileg“",
    "ن-ث-ر": "ausstreuen, verstreuen; تَنَاثَرَ (tanāṯara) „sich zerstreuen“, نَثْر (naṯr) „Prosa; das Ausstreuen“",
    "ن-ح-و": "sich hinwenden zu, grammatikalisch bilden; نَاحِيَة (nāḥiya) „Gegend, Seite, Richtung“, نَحْو (naḥw) „Richtung; Grammatik“",
    "ن-د-م": "bereuen, Reue empfinden; نَدِمَ (nadima) „bereuen“, نَدَم (nadam) „Reue“",
    "ن-س-خ": "abschreiben, kopieren, auslöschen; نُسْخَة (nusḫa) „Kopie, Abschrift, Ausgabe“, نَسْخ (nasḫ) „das Kopieren“",
    "ن-ش-أ": "entstehen lassen, (auf)ziehen, gründen; أَنْشَأَ (ʾanšaʾa) „gründen, errichten“, نَشْأَة „Entstehung, Jugend“",
    "ن-ش-ف": "austrocknen, abwischen, (Wasser) aufsaugen; مُنَشْفَة (munaššafa) „Handtuch“",
    "ن-ش-ق": "einatmen, (Duft) einsaugen; اِسْتَنْشَقَ (istanšaqa) „einatmen, riechen“",
    "ن-ض-ج": "reif, gar werden; نَاضِج (nāḍiǧ) „reif, gar, ausgereift“, نُضْج (nudǧ) „Reife“",
    "ن-ك-ر": "nicht kennen, ableugnen; أَنْكَرَ (ʾankara) „leugnen, missbilligen“, مُنْكَر (munkar) „verwerflich“",
    "ن-ه-ج": "einen deutlichen Weg gehen; اِنْتَهَجَ (intahadǧa) „einschlagen, folgen“, نَهْج (nahǧ) „Weg, Methode“",
    "ن-ي-ل": "erreichen, erlangen; نَالَ (nāla) „erlangen, erhalten“, مَنَال (manāl) „Erreichbares“",
    "ه-ز-ز": "heftig schütteln, erschüttern; هَزَّ (hazza) „schütteln“, اِهْتَزَّ (ihtazza) „vibrieren, beben“",
    "ه-ن-أ": "beglückwünschen, (jemandem) Gutes wünschen; هَنَّأَ (hannaʾa) „gratulieren“, تَهْنِئَة (tahniʾa) „Glückwunsch“",
    "ه-و-ر": "herabstürzen, einstürzen; اِنْهَارَ (inhāra) „zusammenstürzen“, هَار „abrutschig, einstürzend“",
    "و-ح-ي": "eingeben, offenbaren; اِسْتَوْحَى (istawḥā) „entnehmen, ableiten“, وَحْي (waḥy) „Eingebung, Offenbarung“",
    "و-ر-ث": "erben; تُرَاث (turāṯ) „Kulturerbe, Erbgut“, مِيرَاث (mīrāṯ) „Erbschaft, Erbe“",
    "و-ص-ي": "nachdrücklich anempfehlen, (letztwillig) verfügen; وَصِيَّة (wasiyya) „Testament, Vermächtnis“",
    "و-ف-ر": "reichlich, zahlreich sein; وَفِير (wafīr) „reichlich“, تَوْفِير (tawfīr) „Ersparnis, Bereitstellung“",
    "و-ف-ي": "vollständig einhalten, erfüllen; وَفَّى (waffā) „erfüllen, einlösen“, وَفَاء (wafāʾ) „Treue, Erfüllung“",
    "و-ق-ظ": "wach sein, aufwecken; اِسْتَوْقَظَ (istawqaẓa) „aufwachen, erwachen“, يَقَظَة (yaqaẓa) „Wachheit“",
    "و-ق-ي": "schützen, bewahren, (sich) hüten; تَوَقَّى (tawaqqā) „sich hüten, verhüten“, وِقَايَة (wiqāya) „Schutz“",
    "و-ك-ل": "beauftragen, anvertrauen; وَكِيل (wakīl) „Vertreter, Anwalt, Bevollmächtigter“, تَوْكِيل (tawkīl) „Bevollmächtigung“",
    "و-ه-م": "wähnen, sich einbilden; اِتَّهَمَ (ittahama) „beschuldigen, verdächtigen“, وَهْم (wahm) „Wahn, Einbildung“",
    "ي-ت-م": "verwaist sein; يَتِيم (yatīm) „Waise, verwaist“",
    "ي-س-ر": "leicht, geringfügig sein; يَسِير (yasīr) „einfach, leicht, gering“, يُسْر (yusr) „Leichtigkeit, Fügung“",
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