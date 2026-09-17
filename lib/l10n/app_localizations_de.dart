// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Jumlah — Klassisches Arabisch Lern-App';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get restart => 'Neu starten';

  @override
  String get next => 'Weiter';

  @override
  String get back => 'Zurück';

  @override
  String get done => 'Fertig';

  @override
  String get retry => 'Wiederholen';

  @override
  String loadError(String message) {
    return 'Fehler beim Laden: $message';
  }

  @override
  String get tabLearn => 'Lernen';

  @override
  String get tabQuiz => 'Quiz';

  @override
  String get tabStats => 'Statistik';

  @override
  String get tabInfo => 'Info';

  @override
  String get dictionaryTooltip => 'Wörterbuch';

  @override
  String get examTitle => 'Prüfung';

  @override
  String get examSubtitle => 'Prüfe dein Wissen Stufe für Stufe.';

  @override
  String get levelsHeading => 'Sprachniveaus';

  @override
  String levelPlannedSnack(String group) {
    return 'Sprachniveau $group ist in Vorbereitung — kommt bald.';
  }

  @override
  String levelLockedSnack(String group) {
    return 'Schließe zuerst das vorherige Sprachniveau ab, um $group freizuschalten.';
  }

  @override
  String levelTitle(String group, String label) {
    return 'Sprachniveau $group · $label';
  }

  @override
  String get levelLabelA1 => 'Grundstufe';

  @override
  String get levelLabelA2 => 'Sehr häufig';

  @override
  String get levelLabelB1 => 'Häufig';

  @override
  String get levelLabelB2 => 'Mittel';

  @override
  String get levelLabelC1 => 'Selten / Klassisch';

  @override
  String wordsRange(int start, int end) {
    return 'Wörter $start–$end';
  }

  @override
  String percentValue(int percent) {
    return '$percent %';
  }

  @override
  String get previousLevelLocked => 'Vorheriges Niveau abschließen';

  @override
  String get comingSoon => 'Bald verfügbar';

  @override
  String get levelComplete => 'Sprachniveau abgeschlossen ✅';

  @override
  String get startFirstLesson => 'Beginne die erste Lektion';

  @override
  String lessonsOfLevel(int done, int total) {
    return 'Lektion $done von $total im Sprachniveau';
  }

  @override
  String get heroWelcome => 'Willkommen bei Jumlah';

  @override
  String get heroSubtitle =>
      'Lerne klassisches Arabisch — offline & kostenlos.';

  @override
  String get statWords => 'Wörter';

  @override
  String get statLessons => 'Lektionen';

  @override
  String get statProgress => 'Fortschritt';

  @override
  String get continueLearning => 'Weiter lernen';

  @override
  String get startLearning => 'Beginne zu lernen';

  @override
  String continueSubtitleResume(int lesson, int word, String group) {
    return 'Lektion $lesson · Wort $word von 10 · $group';
  }

  @override
  String continueSubtitleStart(String group) {
    return 'Lektion 1 · Wörter 1–10 · $group';
  }

  @override
  String reviewDueOne(int count) {
    return '$count Wort fällig — Zeit für eine Wiederholung.';
  }

  @override
  String reviewDueMany(int count) {
    return '$count Wörter fällig — Zeit für eine Wiederholung.';
  }

  @override
  String get reviewEmptyHint =>
      'Bestehe Lektionen, um Wörter hier zu wiederholen.';

  @override
  String get reviewCardTitle => 'Wiederholen';

  @override
  String get batchListNoWords => 'Keine Wörter in dieser Gruppe gefunden.';

  @override
  String get finalExam => 'Gesamtprüfung';

  @override
  String lessonRange(int lesson, int start, int end) {
    return 'Lektion $lesson · Wörter $start–$end';
  }

  @override
  String get lessonLockedHint =>
      'Erst die vorherige Lektion fehlerfrei bestehen, um diese freizuschalten.';

  @override
  String get lessonNotLearnedHint =>
      'Zuerst diese Lektion lernen, bevor du das Quiz machst.';

  @override
  String get levelLockedHint =>
      'Schließe zuerst das vorherige Sprachniveau ab, um dieses freizuschalten.';

  @override
  String learnTitle(String group) {
    return 'Lernen · $group';
  }

  @override
  String get transliterationTooltip => 'Transliteration erklärt';

  @override
  String get restartTitle => 'Von vorne beginnen?';

  @override
  String get restartLearnBody =>
      'Der gespeicherte Zwischenstand dieser Lektion geht verloren.';

  @override
  String get restartQuizBody =>
      'Der bisherige Fortschritt in diesem Quiz geht verloren.';

  @override
  String get restartTooltip => 'Von vorne beginnen';

  @override
  String get learnNoWords =>
      'Keine Wörter in dieser Gruppe gefunden.\n(words.json muss zuerst importiert werden — Task D1)';

  @override
  String lessonTitle(int lesson) {
    return 'Lektion $lesson';
  }

  @override
  String get noContextSentence =>
      'Für dieses Wort ist noch kein Kontext-Satz verfügbar.';

  @override
  String sentenceCounter(int index, int total) {
    return 'Satz $index/$total';
  }

  @override
  String get rootSection => 'Wurzel';

  @override
  String get masdarSection => 'Masdar (Verbalnomen)';

  @override
  String get toQuiz => 'Zum Quiz';

  @override
  String get stageArabicToGerman => 'Stufe 1/6 · Arabisch → Deutsch';

  @override
  String get stageGermanToArabic => 'Stufe 2/6 · Deutsch → Arabisch';

  @override
  String get stageMixed => 'Stufe 3/6 · Abwechselnd';

  @override
  String get stageSentences => 'Stufe 4/6 · Sätze';

  @override
  String get stageAudio => 'Stufe 5/6 · Audio';

  @override
  String get stageStory => 'Stufe 6/6 · Geschichte';

  @override
  String get readStory => 'Lies die Geschichte:';

  @override
  String get continueToMatching => 'Weiter zur Zuordnung';

  @override
  String get audioPrompt => 'Höre zu und wähle die deutsche Bedeutung:';

  @override
  String get listenSentence => 'Satz anhören';

  @override
  String get sentencePrompt => 'Welche Bedeutung passt zu diesem Satz?';

  @override
  String get sharePassed => 'Bestanden ✅';

  @override
  String get shareFailed => 'Nicht bestanden';

  @override
  String get shareCompleted => 'Abgeschlossen';

  @override
  String shareResultLine(String status) {
    return 'Ergebnis: $status';
  }

  @override
  String shareCorrectLine(int score, int total) {
    return 'Richtige Antworten: $score von $total';
  }

  @override
  String shareErrorsLine(int wrong, int allowed) {
    return 'Fehler: $wrong von $allowed erlaubten';
  }

  @override
  String get copiedToClipboard => 'Ergebnis in die Zwischenablage kopiert.';

  @override
  String get passedTitle => 'Bestanden!';

  @override
  String get failedTitle => 'Nicht bestanden';

  @override
  String get resultTitle => 'Ergebnis';

  @override
  String errorsSummary(int wrong, int allowed) {
    return '$wrong Fehler von $allowed erlaubten';
  }

  @override
  String scoreCorrectAnswers(int score) {
    return '$score richtige Antworten';
  }

  @override
  String get lessonPassedUnlock =>
      'Lektion bestanden — nächste Lektion ist freigeschaltet!';

  @override
  String get lessonFailedRetry =>
      'Lektion nicht bestanden — bitte wiederholen, um die nächste Lektion freizuschalten.';

  @override
  String get practiceAgain => 'Nochmal üben:';

  @override
  String get shareResult => 'Ergebnis teilen';

  @override
  String get continueButton => 'Weiter';

  @override
  String groupCompletedTitle(String group) {
    return '$group abgeschlossen';
  }

  @override
  String get allLessonsDone => 'Alle Lektionen geschafft!';

  @override
  String get finalExamFailed =>
      'Die Gesamtprüfung war noch nicht fehlerfrei — versuch es nochmal.';

  @override
  String get finalExamIntro =>
      'Zum Abschluss folgt eine Gesamtprüfung über alle Wörter dieser Gruppe.';

  @override
  String get startFinalExam => 'Gesamtprüfung starten';

  @override
  String get finalExamPassedTitle => 'Gesamtprüfung bestanden!';

  @override
  String get levelUnlockedText =>
      'Das Sprachniveau ist abgeschlossen — die nächste Stufe ist freigeschaltet. Weitere Stufen folgen, sobald ihre Inhalte verfügbar sind.';

  @override
  String get backToLessons => 'Zur Lektionsübersicht';

  @override
  String get reviewAppBarTitle => 'Wiederholung';

  @override
  String get revealAnswer => 'Antwort zeigen';

  @override
  String get quality0 => 'Vergessen';

  @override
  String get quality1 => 'Fast';

  @override
  String get quality2 => 'Schwer';

  @override
  String get quality3 => 'Knapp';

  @override
  String get quality4 => 'Gut';

  @override
  String get quality5 => 'Perfekt';

  @override
  String get howWellQuestion => 'Wie gut hast du es gewusst?';

  @override
  String get reviewAllDone => 'Alles erledigt';

  @override
  String get reviewNoDue =>
      'Gerade sind keine Wörter fällig. Bestehe Lektionen im Quiz, um ihre Wörter in die Wiederholung aufzunehmen — und komm morgen wieder vorbei.';

  @override
  String get sessionComplete => 'Session abgeschlossen';

  @override
  String rememberedSummary(int correct, int total) {
    return '$correct von $total Wörtern erinnert.';
  }

  @override
  String get forgottenHint =>
      'Kein Problem — die vergessenen Wörter kommen morgen automatisch wieder.';

  @override
  String get noActivityTitle => 'Noch keine Lernaktivität';

  @override
  String get noActivityBody =>
      'Sobald du eine Lektion durchblätterst oder eine Quiz-Frage beantwortest, wertet Jumlah deine Serie und diese Heatmap aus — automatisch und komplett offline.';

  @override
  String get currentStreak => 'Tage Serie';

  @override
  String get bestStreak => 'Beste Serie';

  @override
  String get activeDays => 'Aktive Tage';

  @override
  String get today => 'Heute';

  @override
  String get wordsViewed => 'Wörter angesehen';

  @override
  String get quizAnswers => 'Quiz-Antworten';

  @override
  String get lessonsCompleted => 'Lektionen bestanden';

  @override
  String get heatmapTitle => 'Deine Lernaktivität';

  @override
  String heatmapSubtitle(int weeks) {
    return 'Letzte $weeks Wochen — jeden Tag eine Zelle';
  }

  @override
  String get weekdayMo => 'Mo';

  @override
  String get weekdayDi => 'Di';

  @override
  String get weekdayMi => 'Mi';

  @override
  String get weekdayDo => 'Do';

  @override
  String get weekdayFr => 'Fr';

  @override
  String get weekdaySa => 'Sa';

  @override
  String get weekdaySo => 'So';

  @override
  String heatmapTooltip(String date, int count) {
    return '$date · $count Aktivitäten';
  }

  @override
  String get legendLittle => 'wenig';

  @override
  String get legendMuch => 'viel';

  @override
  String get dictionaryTitle => 'Wörterbuch';

  @override
  String get dictionaryHint => 'Wort suchen (Arabisch, Deutsch, Umschrift)…';

  @override
  String get dictionaryEmptyHint =>
      'Suche nach einem arabischen Wort, seiner deutschen Bedeutung oder der wissenschaftlichen Umschrift.';

  @override
  String get noResults => 'Keine Treffer gefunden.';

  @override
  String rootTitle(String root) {
    return 'Wurzel $root';
  }

  @override
  String get contextSentences => 'Kontext-Sätze';

  @override
  String get supportLegalHeading => 'Support & Rechtliches';

  @override
  String get supportLegalBody =>
      'Unterstütze die Entwicklung oder rufe die gesetzlich erforderlichen Angaben auf.';

  @override
  String get supportTitle => 'Entwickler unterstützen ☕';

  @override
  String get supportSubtitle =>
      'Freiwillige Spende über Ko-fi — die App bleibt kostenlos.';

  @override
  String get legalTitle => 'Impressum & Datenschutz';

  @override
  String get legalSubtitle => 'Rechtliche Angaben und Datenschutzhinweise.';

  @override
  String get languageHeading => 'Sprache';

  @override
  String get languageBody =>
      'App-Oberfläche wählen — die Lerninhalte bleiben unverändert Arabisch ↔ Deutsch.';

  @override
  String get themeHeading => 'Design';

  @override
  String get themeBody => 'Helles oder dunkles Design wählen.';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Hell';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'English';

  @override
  String get languageAr => 'العربية';

  @override
  String get welcomeTitle => 'Willkommen bei Jumlah';

  @override
  String get welcomeSubtitle =>
      'Lerne klassisches Arabisch (Fusha / Qur’anisch) — Schritt für Schritt, offline & kostenlos, in deinem eigenen Tempo.';

  @override
  String get motivationTitle => 'Bleib am Ball 🔥';

  @override
  String get motivationBody =>
      'Konsequenz schlägt Talent: Schon 10 Minuten am Tag bringen dich Woche für Woche weiter — von den ersten Verben bis zu seltenen koranischen Ausdrücken.';

  @override
  String get whatToExpect => 'Das erwartet dich:';

  @override
  String get featureClassicalTitle => 'Klassisches Arabisch';

  @override
  String get featureClassicalBody =>
      'Die 500 häufigsten Wörter des klassischen Arabisch — jedes mit 3 echten Kontext-Sätzen, Wurzel-Familie, Masdar und DIN-31635-Umschrift.';

  @override
  String get featureAudioTitle => 'Audio-Aussprache';

  @override
  String get featureAudioBody =>
      'Jeder Kontext-Satz wird dir vorgelesen — lokal gebündelte Audios, ganz ohne Internet.';

  @override
  String get featureLessonsTitle => 'Lektion für Lektion mit Prüfung';

  @override
  String get featureLessonsBody =>
      '100 Lektionen à 10 Wörter. Nach jeder Lektion folgt die Prüfung in 6 Stufen (Wort, Sätze, Audio, Geschichte) mit höchstens 3 Fehlern — wer besteht, schaltet frei.';

  @override
  String get featureDictTitle => 'Offline-Wörterbuch';

  @override
  String get featureDictBody =>
      'Suche arabische Wörter und Sätze — harakat- und umschrift-insensitiv, damit du auch ohne Diakritik findest.';

  @override
  String get featureStatsTitle => 'Lernstatistik';

  @override
  String get featureStatsBody =>
      'Behalte deine Serie 🔥, aktiven Tage und eine 16-Wochen-Aktivitäts-Heatmap im Überblick.';

  @override
  String get featureReviewTitle => 'Wiederholungen';

  @override
  String get featureReviewBody =>
      'Fällige Wörter werden dir nach dem SM-2-Lernabstand erneut vorgelegt — für langfristigen Wortschatz.';

  @override
  String get featureOfflineTitle => 'Offline & kostenlos';

  @override
  String get featureOfflineBody =>
      'Alles funktioniert ohne Internet, dein Fortschritt bleibt auf deinem Gerät — und die App ist komplett kostenlos.';

  @override
  String get devNoteTitle => 'Jumlah wird aktiv weiterentwickelt';

  @override
  String get devNoteBody =>
      'Neue Lektionen, Sprachniveaus und Funktionen folgen regelmäßig — bleib dran und wachse mit der App mit.';

  @override
  String get supportHeading => 'Unterstütze die Entwicklung';

  @override
  String get supportBody =>
      'Jumlah ist kostenlos. Wenn dir die App gefällt, kannst du die Entwicklung freiwillig unterstützen:';

  @override
  String get letsGo => 'Los geht’s';

  @override
  String get transliterationTitle => 'Transliteration (DIN 31635)';

  @override
  String get transliterationIntro =>
      'Die arabische Umschrift in dieser App folgt DIN 31635, dem wissenschaftlichen Standard der Arabistik. Sie zeigt exakt, wie ein Wort geschrieben und gesprochen wird — inklusive Laute, die es im Deutschen nicht gibt. Ab Stufe B1 wird die Umschrift bewusst nicht mehr angezeigt, da du dann die arabische Schrift direkt lesen sollst.';

  @override
  String get lettersHeading => 'Buchstaben';

  @override
  String get diacriticsHeading => 'Kurzvokale & Zeichen';

  @override
  String get tlHamza =>
      'Stimmritzenverschluss (Hamza) — der Knacklaut vor Vokalen wie in „Verein“';

  @override
  String get tlAlef => 'langes „a“ wie in „Vater“';

  @override
  String get tlBa => 'wie deutsches „b“';

  @override
  String get tlTa => 'wie deutsches „t“';

  @override
  String get tlTha => 'stimmloses „th“ wie engl. „think“';

  @override
  String get tlJim => 'wie „dsch“ in „Dschungel“';

  @override
  String get tlHa => 'gepresster Rachen-h-Laut, schärfer als deutsches „h“';

  @override
  String get tlKha => 'wie „ch“ in „Bach“';

  @override
  String get tlDal => 'wie deutsches „d“';

  @override
  String get tlDhal => 'stimmhaftes „th“ wie engl. „this“';

  @override
  String get tlRa => 'gerolltes „r“';

  @override
  String get tlZay => 'stimmhaftes „s“ wie in „Sonne“';

  @override
  String get tlSin => 'stimmloses „s“ wie in „Wasser“';

  @override
  String get tlShin => 'wie deutsches „sch“';

  @override
  String get tlSad => 'emphatisches (velarisiertes) „s“';

  @override
  String get tlDad => 'emphatisches „d“';

  @override
  String get tlTaEmph => 'emphatisches „t“';

  @override
  String get tlZa => 'emphatisches „th“ (wie ذ, aber velarisiert)';

  @override
  String get tlAyn => 'stimmhafter Rachenlaut ohne deutsches Äquivalent (ʿAin)';

  @override
  String get tlGhayn => 'wie das französische „r“ (Reibelaut im Rachen)';

  @override
  String get tlFa => 'wie deutsches „f“';

  @override
  String get tlQaf => 'wie „k“, aber tief im Rachen gebildet (Uvular)';

  @override
  String get tlKaf => 'wie deutsches „k“';

  @override
  String get tlLam => 'wie deutsches „l“';

  @override
  String get tlMim => 'wie deutsches „m“';

  @override
  String get tlNun => 'wie deutsches „n“';

  @override
  String get tlHeh => 'wie deutsches „h“';

  @override
  String get tlWaw => 'Halbvokal „w“ oder langes „u“';

  @override
  String get tlYa => 'Halbvokal „j“ oder langes „i“';

  @override
  String get tlTaMarbuta =>
      'Tāʾ marbūṭa: „a“ am Wortende, vor Folgewort oft „-at“';

  @override
  String get tlAlifMaqsura => 'Alif maqṣūra: langes „a“ am Wortende';

  @override
  String get tdFatha => 'Fatha — kurzes „a“';

  @override
  String get tdKasra => 'Kasra — kurzes „i“';

  @override
  String get tdDamma => 'Damma — kurzes „u“';

  @override
  String get tdSukun => 'Sukun — der Konsonant trägt keinen Vokal';

  @override
  String get tdShadda => 'Shadda — der Konsonant wird doppelt gesprochen';

  @override
  String get tdSukunSymbol => '(kein Vokal)';

  @override
  String get tdShaddaSymbol => '(Verdopplung)';
}
