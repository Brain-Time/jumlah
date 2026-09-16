import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Jumlah — Klassisches Arabisch Lern-App'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @restart.
  ///
  /// In de, this message translates to:
  /// **'Neu starten'**
  String get restart;

  /// No description provided for @next.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get next;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get back;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In de, this message translates to:
  /// **'Wiederholen'**
  String get retry;

  /// No description provided for @loadError.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden: {message}'**
  String loadError(String message);

  /// No description provided for @tabLearn.
  ///
  /// In de, this message translates to:
  /// **'Lernen'**
  String get tabLearn;

  /// No description provided for @tabQuiz.
  ///
  /// In de, this message translates to:
  /// **'Quiz'**
  String get tabQuiz;

  /// No description provided for @tabStats.
  ///
  /// In de, this message translates to:
  /// **'Statistik'**
  String get tabStats;

  /// No description provided for @tabInfo.
  ///
  /// In de, this message translates to:
  /// **'Info'**
  String get tabInfo;

  /// No description provided for @dictionaryTooltip.
  ///
  /// In de, this message translates to:
  /// **'Wörterbuch'**
  String get dictionaryTooltip;

  /// No description provided for @examTitle.
  ///
  /// In de, this message translates to:
  /// **'Prüfung'**
  String get examTitle;

  /// No description provided for @examSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Prüfe dein Wissen Stufe für Stufe.'**
  String get examSubtitle;

  /// No description provided for @levelsHeading.
  ///
  /// In de, this message translates to:
  /// **'Sprachniveaus'**
  String get levelsHeading;

  /// No description provided for @levelPlannedSnack.
  ///
  /// In de, this message translates to:
  /// **'Sprachniveau {group} ist in Vorbereitung — kommt bald.'**
  String levelPlannedSnack(String group);

  /// No description provided for @levelLockedSnack.
  ///
  /// In de, this message translates to:
  /// **'Schließe zuerst das vorherige Sprachniveau ab, um {group} freizuschalten.'**
  String levelLockedSnack(String group);

  /// No description provided for @levelTitle.
  ///
  /// In de, this message translates to:
  /// **'Sprachniveau {group} · {label}'**
  String levelTitle(String group, String label);

  /// No description provided for @levelLabelA1.
  ///
  /// In de, this message translates to:
  /// **'Grundstufe'**
  String get levelLabelA1;

  /// No description provided for @levelLabelA2.
  ///
  /// In de, this message translates to:
  /// **'Sehr häufig'**
  String get levelLabelA2;

  /// No description provided for @levelLabelB1.
  ///
  /// In de, this message translates to:
  /// **'Häufig'**
  String get levelLabelB1;

  /// No description provided for @levelLabelB2.
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get levelLabelB2;

  /// No description provided for @levelLabelC1.
  ///
  /// In de, this message translates to:
  /// **'Selten / Klassisch'**
  String get levelLabelC1;

  /// No description provided for @wordsRange.
  ///
  /// In de, this message translates to:
  /// **'Wörter {start}–{end}'**
  String wordsRange(int start, int end);

  /// No description provided for @percentValue.
  ///
  /// In de, this message translates to:
  /// **'{percent} %'**
  String percentValue(int percent);

  /// No description provided for @previousLevelLocked.
  ///
  /// In de, this message translates to:
  /// **'Vorheriges Niveau abschließen'**
  String get previousLevelLocked;

  /// No description provided for @comingSoon.
  ///
  /// In de, this message translates to:
  /// **'Bald verfügbar'**
  String get comingSoon;

  /// No description provided for @levelComplete.
  ///
  /// In de, this message translates to:
  /// **'Sprachniveau abgeschlossen ✅'**
  String get levelComplete;

  /// No description provided for @startFirstLesson.
  ///
  /// In de, this message translates to:
  /// **'Beginne die erste Lektion'**
  String get startFirstLesson;

  /// No description provided for @lessonsOfLevel.
  ///
  /// In de, this message translates to:
  /// **'Lektion {done} von {total} im Sprachniveau'**
  String lessonsOfLevel(int done, int total);

  /// No description provided for @heroWelcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei Jumlah'**
  String get heroWelcome;

  /// No description provided for @heroSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Lerne klassisches Arabisch — offline & kostenlos.'**
  String get heroSubtitle;

  /// No description provided for @statWords.
  ///
  /// In de, this message translates to:
  /// **'Wörter'**
  String get statWords;

  /// No description provided for @statLessons.
  ///
  /// In de, this message translates to:
  /// **'Lektionen'**
  String get statLessons;

  /// No description provided for @statProgress.
  ///
  /// In de, this message translates to:
  /// **'Fortschritt'**
  String get statProgress;

  /// No description provided for @continueLearning.
  ///
  /// In de, this message translates to:
  /// **'Weiter lernen'**
  String get continueLearning;

  /// No description provided for @startLearning.
  ///
  /// In de, this message translates to:
  /// **'Beginne zu lernen'**
  String get startLearning;

  /// No description provided for @continueSubtitleResume.
  ///
  /// In de, this message translates to:
  /// **'Lektion {lesson} · Wort {word} von 10 · {group}'**
  String continueSubtitleResume(int lesson, int word, String group);

  /// No description provided for @continueSubtitleStart.
  ///
  /// In de, this message translates to:
  /// **'Lektion 1 · Wörter 1–10 · {group}'**
  String continueSubtitleStart(String group);

  /// No description provided for @reviewDueOne.
  ///
  /// In de, this message translates to:
  /// **'{count} Wort fällig — Zeit für eine Wiederholung.'**
  String reviewDueOne(int count);

  /// No description provided for @reviewDueMany.
  ///
  /// In de, this message translates to:
  /// **'{count} Wörter fällig — Zeit für eine Wiederholung.'**
  String reviewDueMany(int count);

  /// No description provided for @reviewEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Bestehe Lektionen, um Wörter hier zu wiederholen.'**
  String get reviewEmptyHint;

  /// No description provided for @reviewCardTitle.
  ///
  /// In de, this message translates to:
  /// **'Wiederholen'**
  String get reviewCardTitle;

  /// No description provided for @batchListNoWords.
  ///
  /// In de, this message translates to:
  /// **'Keine Wörter in dieser Gruppe gefunden.'**
  String get batchListNoWords;

  /// No description provided for @finalExam.
  ///
  /// In de, this message translates to:
  /// **'Gesamtprüfung'**
  String get finalExam;

  /// No description provided for @lessonRange.
  ///
  /// In de, this message translates to:
  /// **'Lektion {lesson} · Wörter {start}–{end}'**
  String lessonRange(int lesson, int start, int end);

  /// No description provided for @lessonLockedHint.
  ///
  /// In de, this message translates to:
  /// **'Erst die vorherige Lektion fehlerfrei bestehen, um diese freizuschalten.'**
  String get lessonLockedHint;

  /// No description provided for @lessonNotLearnedHint.
  ///
  /// In de, this message translates to:
  /// **'Zuerst diese Lektion lernen, bevor du das Quiz machst.'**
  String get lessonNotLearnedHint;

  /// No description provided for @levelLockedHint.
  ///
  /// In de, this message translates to:
  /// **'Schließe zuerst das vorherige Sprachniveau ab, um dieses freizuschalten.'**
  String get levelLockedHint;

  /// No description provided for @learnTitle.
  ///
  /// In de, this message translates to:
  /// **'Lernen · {group}'**
  String learnTitle(String group);

  /// No description provided for @transliterationTooltip.
  ///
  /// In de, this message translates to:
  /// **'Transliteration erklärt'**
  String get transliterationTooltip;

  /// No description provided for @restartTitle.
  ///
  /// In de, this message translates to:
  /// **'Von vorne beginnen?'**
  String get restartTitle;

  /// No description provided for @restartLearnBody.
  ///
  /// In de, this message translates to:
  /// **'Der gespeicherte Zwischenstand dieser Lektion geht verloren.'**
  String get restartLearnBody;

  /// No description provided for @restartQuizBody.
  ///
  /// In de, this message translates to:
  /// **'Der bisherige Fortschritt in diesem Quiz geht verloren.'**
  String get restartQuizBody;

  /// No description provided for @restartTooltip.
  ///
  /// In de, this message translates to:
  /// **'Von vorne beginnen'**
  String get restartTooltip;

  /// No description provided for @learnNoWords.
  ///
  /// In de, this message translates to:
  /// **'Keine Wörter in dieser Gruppe gefunden.\n(words.json muss zuerst importiert werden — Task D1)'**
  String get learnNoWords;

  /// No description provided for @lessonTitle.
  ///
  /// In de, this message translates to:
  /// **'Lektion {lesson}'**
  String lessonTitle(int lesson);

  /// No description provided for @noContextSentence.
  ///
  /// In de, this message translates to:
  /// **'Für dieses Wort ist noch kein Kontext-Satz verfügbar.'**
  String get noContextSentence;

  /// No description provided for @sentenceCounter.
  ///
  /// In de, this message translates to:
  /// **'Satz {index}/{total}'**
  String sentenceCounter(int index, int total);

  /// No description provided for @rootSection.
  ///
  /// In de, this message translates to:
  /// **'Wurzel'**
  String get rootSection;

  /// No description provided for @masdarSection.
  ///
  /// In de, this message translates to:
  /// **'Masdar (Verbalnomen)'**
  String get masdarSection;

  /// No description provided for @toQuiz.
  ///
  /// In de, this message translates to:
  /// **'Zum Quiz'**
  String get toQuiz;

  /// No description provided for @stageArabicToGerman.
  ///
  /// In de, this message translates to:
  /// **'Stufe 1/6 · Arabisch → Deutsch'**
  String get stageArabicToGerman;

  /// No description provided for @stageGermanToArabic.
  ///
  /// In de, this message translates to:
  /// **'Stufe 2/6 · Deutsch → Arabisch'**
  String get stageGermanToArabic;

  /// No description provided for @stageMixed.
  ///
  /// In de, this message translates to:
  /// **'Stufe 3/6 · Abwechselnd'**
  String get stageMixed;

  /// No description provided for @stageSentences.
  ///
  /// In de, this message translates to:
  /// **'Stufe 4/6 · Sätze'**
  String get stageSentences;

  /// No description provided for @stageAudio.
  ///
  /// In de, this message translates to:
  /// **'Stufe 5/6 · Audio'**
  String get stageAudio;

  /// No description provided for @stageStory.
  ///
  /// In de, this message translates to:
  /// **'Stufe 6/6 · Geschichte'**
  String get stageStory;

  /// No description provided for @readStory.
  ///
  /// In de, this message translates to:
  /// **'Lies die Geschichte:'**
  String get readStory;

  /// No description provided for @continueToMatching.
  ///
  /// In de, this message translates to:
  /// **'Weiter zur Zuordnung'**
  String get continueToMatching;

  /// No description provided for @audioPrompt.
  ///
  /// In de, this message translates to:
  /// **'Höre zu und wähle die deutsche Bedeutung:'**
  String get audioPrompt;

  /// No description provided for @listenSentence.
  ///
  /// In de, this message translates to:
  /// **'Satz anhören'**
  String get listenSentence;

  /// No description provided for @sentencePrompt.
  ///
  /// In de, this message translates to:
  /// **'Welche Bedeutung passt zu diesem Satz?'**
  String get sentencePrompt;

  /// No description provided for @sharePassed.
  ///
  /// In de, this message translates to:
  /// **'Bestanden ✅'**
  String get sharePassed;

  /// No description provided for @shareFailed.
  ///
  /// In de, this message translates to:
  /// **'Nicht bestanden'**
  String get shareFailed;

  /// No description provided for @shareCompleted.
  ///
  /// In de, this message translates to:
  /// **'Abgeschlossen'**
  String get shareCompleted;

  /// No description provided for @shareResultLine.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis: {status}'**
  String shareResultLine(String status);

  /// No description provided for @shareCorrectLine.
  ///
  /// In de, this message translates to:
  /// **'Richtige Antworten: {score} von {total}'**
  String shareCorrectLine(int score, int total);

  /// No description provided for @shareErrorsLine.
  ///
  /// In de, this message translates to:
  /// **'Fehler: {wrong} von {allowed} erlaubten'**
  String shareErrorsLine(int wrong, int allowed);

  /// No description provided for @copiedToClipboard.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis in die Zwischenablage kopiert.'**
  String get copiedToClipboard;

  /// No description provided for @passedTitle.
  ///
  /// In de, this message translates to:
  /// **'Bestanden!'**
  String get passedTitle;

  /// No description provided for @failedTitle.
  ///
  /// In de, this message translates to:
  /// **'Nicht bestanden'**
  String get failedTitle;

  /// No description provided for @resultTitle.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis'**
  String get resultTitle;

  /// No description provided for @errorsSummary.
  ///
  /// In de, this message translates to:
  /// **'{wrong} Fehler von {allowed} erlaubten'**
  String errorsSummary(int wrong, int allowed);

  /// No description provided for @scoreCorrectAnswers.
  ///
  /// In de, this message translates to:
  /// **'{score} richtige Antworten'**
  String scoreCorrectAnswers(int score);

  /// No description provided for @lessonPassedUnlock.
  ///
  /// In de, this message translates to:
  /// **'Lektion bestanden — nächste Lektion ist freigeschaltet!'**
  String get lessonPassedUnlock;

  /// No description provided for @lessonFailedRetry.
  ///
  /// In de, this message translates to:
  /// **'Lektion nicht bestanden — bitte wiederholen, um die nächste Lektion freizuschalten.'**
  String get lessonFailedRetry;

  /// No description provided for @practiceAgain.
  ///
  /// In de, this message translates to:
  /// **'Nochmal üben:'**
  String get practiceAgain;

  /// No description provided for @shareResult.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis teilen'**
  String get shareResult;

  /// No description provided for @continueButton.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get continueButton;

  /// No description provided for @groupCompletedTitle.
  ///
  /// In de, this message translates to:
  /// **'{group} abgeschlossen'**
  String groupCompletedTitle(String group);

  /// No description provided for @allLessonsDone.
  ///
  /// In de, this message translates to:
  /// **'Alle Lektionen geschafft!'**
  String get allLessonsDone;

  /// No description provided for @finalExamFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Gesamtprüfung war noch nicht fehlerfrei — versuch es nochmal.'**
  String get finalExamFailed;

  /// No description provided for @finalExamIntro.
  ///
  /// In de, this message translates to:
  /// **'Zum Abschluss folgt eine Gesamtprüfung über alle Wörter dieser Gruppe.'**
  String get finalExamIntro;

  /// No description provided for @startFinalExam.
  ///
  /// In de, this message translates to:
  /// **'Gesamtprüfung starten'**
  String get startFinalExam;

  /// No description provided for @finalExamPassedTitle.
  ///
  /// In de, this message translates to:
  /// **'Gesamtprüfung bestanden!'**
  String get finalExamPassedTitle;

  /// No description provided for @levelUnlockedText.
  ///
  /// In de, this message translates to:
  /// **'Das Sprachniveau ist abgeschlossen — die nächste Stufe ist freigeschaltet. Weitere Stufen folgen, sobald ihre Inhalte verfügbar sind.'**
  String get levelUnlockedText;

  /// No description provided for @backToLessons.
  ///
  /// In de, this message translates to:
  /// **'Zur Lektionsübersicht'**
  String get backToLessons;

  /// No description provided for @reviewAppBarTitle.
  ///
  /// In de, this message translates to:
  /// **'Wiederholung'**
  String get reviewAppBarTitle;

  /// No description provided for @revealAnswer.
  ///
  /// In de, this message translates to:
  /// **'Antwort zeigen'**
  String get revealAnswer;

  /// No description provided for @quality0.
  ///
  /// In de, this message translates to:
  /// **'Vergessen'**
  String get quality0;

  /// No description provided for @quality1.
  ///
  /// In de, this message translates to:
  /// **'Fast'**
  String get quality1;

  /// No description provided for @quality2.
  ///
  /// In de, this message translates to:
  /// **'Schwer'**
  String get quality2;

  /// No description provided for @quality3.
  ///
  /// In de, this message translates to:
  /// **'Knapp'**
  String get quality3;

  /// No description provided for @quality4.
  ///
  /// In de, this message translates to:
  /// **'Gut'**
  String get quality4;

  /// No description provided for @quality5.
  ///
  /// In de, this message translates to:
  /// **'Perfekt'**
  String get quality5;

  /// No description provided for @howWellQuestion.
  ///
  /// In de, this message translates to:
  /// **'Wie gut hast du es gewusst?'**
  String get howWellQuestion;

  /// No description provided for @reviewAllDone.
  ///
  /// In de, this message translates to:
  /// **'Alles erledigt'**
  String get reviewAllDone;

  /// No description provided for @reviewNoDue.
  ///
  /// In de, this message translates to:
  /// **'Gerade sind keine Wörter fällig. Bestehe Lektionen im Quiz, um ihre Wörter in die Wiederholung aufzunehmen — und komm morgen wieder vorbei.'**
  String get reviewNoDue;

  /// No description provided for @sessionComplete.
  ///
  /// In de, this message translates to:
  /// **'Session abgeschlossen'**
  String get sessionComplete;

  /// No description provided for @rememberedSummary.
  ///
  /// In de, this message translates to:
  /// **'{correct} von {total} Wörtern erinnert.'**
  String rememberedSummary(int correct, int total);

  /// No description provided for @forgottenHint.
  ///
  /// In de, this message translates to:
  /// **'Kein Problem — die vergessenen Wörter kommen morgen automatisch wieder.'**
  String get forgottenHint;

  /// No description provided for @noActivityTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Lernaktivität'**
  String get noActivityTitle;

  /// No description provided for @noActivityBody.
  ///
  /// In de, this message translates to:
  /// **'Sobald du eine Lektion durchblätterst oder eine Quiz-Frage beantwortest, wertet Jumlah deine Serie und diese Heatmap aus — automatisch und komplett offline.'**
  String get noActivityBody;

  /// No description provided for @currentStreak.
  ///
  /// In de, this message translates to:
  /// **'Tage Serie'**
  String get currentStreak;

  /// No description provided for @bestStreak.
  ///
  /// In de, this message translates to:
  /// **'Beste Serie'**
  String get bestStreak;

  /// No description provided for @activeDays.
  ///
  /// In de, this message translates to:
  /// **'Aktive Tage'**
  String get activeDays;

  /// No description provided for @today.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get today;

  /// No description provided for @wordsViewed.
  ///
  /// In de, this message translates to:
  /// **'Wörter angesehen'**
  String get wordsViewed;

  /// No description provided for @quizAnswers.
  ///
  /// In de, this message translates to:
  /// **'Quiz-Antworten'**
  String get quizAnswers;

  /// No description provided for @lessonsCompleted.
  ///
  /// In de, this message translates to:
  /// **'Lektionen bestanden'**
  String get lessonsCompleted;

  /// No description provided for @heatmapTitle.
  ///
  /// In de, this message translates to:
  /// **'Deine Lernaktivität'**
  String get heatmapTitle;

  /// No description provided for @heatmapSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Letzte {weeks} Wochen — jeden Tag eine Zelle'**
  String heatmapSubtitle(int weeks);

  /// No description provided for @weekdayMo.
  ///
  /// In de, this message translates to:
  /// **'Mo'**
  String get weekdayMo;

  /// No description provided for @weekdayDi.
  ///
  /// In de, this message translates to:
  /// **'Di'**
  String get weekdayDi;

  /// No description provided for @weekdayMi.
  ///
  /// In de, this message translates to:
  /// **'Mi'**
  String get weekdayMi;

  /// No description provided for @weekdayDo.
  ///
  /// In de, this message translates to:
  /// **'Do'**
  String get weekdayDo;

  /// No description provided for @weekdayFr.
  ///
  /// In de, this message translates to:
  /// **'Fr'**
  String get weekdayFr;

  /// No description provided for @weekdaySa.
  ///
  /// In de, this message translates to:
  /// **'Sa'**
  String get weekdaySa;

  /// No description provided for @weekdaySo.
  ///
  /// In de, this message translates to:
  /// **'So'**
  String get weekdaySo;

  /// No description provided for @heatmapTooltip.
  ///
  /// In de, this message translates to:
  /// **'{date} · {count} Aktivitäten'**
  String heatmapTooltip(String date, int count);

  /// No description provided for @legendLittle.
  ///
  /// In de, this message translates to:
  /// **'wenig'**
  String get legendLittle;

  /// No description provided for @legendMuch.
  ///
  /// In de, this message translates to:
  /// **'viel'**
  String get legendMuch;

  /// No description provided for @dictionaryTitle.
  ///
  /// In de, this message translates to:
  /// **'Wörterbuch'**
  String get dictionaryTitle;

  /// No description provided for @dictionaryHint.
  ///
  /// In de, this message translates to:
  /// **'Wort suchen (Arabisch, Deutsch, Umschrift)…'**
  String get dictionaryHint;

  /// No description provided for @dictionaryEmptyHint.
  ///
  /// In de, this message translates to:
  /// **'Suche nach einem arabischen Wort, seiner deutschen Bedeutung oder der wissenschaftlichen Umschrift.'**
  String get dictionaryEmptyHint;

  /// No description provided for @noResults.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer gefunden.'**
  String get noResults;

  /// No description provided for @rootTitle.
  ///
  /// In de, this message translates to:
  /// **'Wurzel {root}'**
  String rootTitle(String root);

  /// No description provided for @contextSentences.
  ///
  /// In de, this message translates to:
  /// **'Kontext-Sätze'**
  String get contextSentences;

  /// No description provided for @supportLegalHeading.
  ///
  /// In de, this message translates to:
  /// **'Support & Rechtliches'**
  String get supportLegalHeading;

  /// No description provided for @supportLegalBody.
  ///
  /// In de, this message translates to:
  /// **'Unterstütze die Entwicklung oder rufe die gesetzlich erforderlichen Angaben auf.'**
  String get supportLegalBody;

  /// No description provided for @supportTitle.
  ///
  /// In de, this message translates to:
  /// **'Entwickler unterstützen ☕'**
  String get supportTitle;

  /// No description provided for @supportSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Freiwillige Spende über Ko-fi — die App bleibt kostenlos.'**
  String get supportSubtitle;

  /// No description provided for @legalTitle.
  ///
  /// In de, this message translates to:
  /// **'Impressum & Datenschutz'**
  String get legalTitle;

  /// No description provided for @legalSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Rechtliche Angaben und Datenschutzhinweise.'**
  String get legalSubtitle;

  /// No description provided for @languageHeading.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get languageHeading;

  /// No description provided for @languageBody.
  ///
  /// In de, this message translates to:
  /// **'App-Oberfläche wählen — die Lerninhalte bleiben unverändert Arabisch ↔ Deutsch.'**
  String get languageBody;

  /// No description provided for @languageDe.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageDe;

  /// No description provided for @languageEn.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageAr.
  ///
  /// In de, this message translates to:
  /// **'العربية'**
  String get languageAr;

  /// No description provided for @welcomeTitle.
  ///
  /// In de, this message translates to:
  /// **'Willkommen bei Jumlah'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Lerne klassisches Arabisch (Fusha / Qur’anisch) — Schritt für Schritt, offline & kostenlos, in deinem eigenen Tempo.'**
  String get welcomeSubtitle;

  /// No description provided for @motivationTitle.
  ///
  /// In de, this message translates to:
  /// **'Bleib am Ball 🔥'**
  String get motivationTitle;

  /// No description provided for @motivationBody.
  ///
  /// In de, this message translates to:
  /// **'Konsequenz schlägt Talent: Schon 10 Minuten am Tag bringen dich Woche für Woche weiter — von den ersten Verben bis zu seltenen koranischen Ausdrücken.'**
  String get motivationBody;

  /// No description provided for @whatToExpect.
  ///
  /// In de, this message translates to:
  /// **'Das erwartet dich:'**
  String get whatToExpect;

  /// No description provided for @featureClassicalTitle.
  ///
  /// In de, this message translates to:
  /// **'Klassisches Arabisch'**
  String get featureClassicalTitle;

  /// No description provided for @featureClassicalBody.
  ///
  /// In de, this message translates to:
  /// **'Die 500 häufigsten Wörter des klassischen Arabisch — jedes mit 3 echten Kontext-Sätzen, Wurzel-Familie, Masdar und DIN-31635-Umschrift.'**
  String get featureClassicalBody;

  /// No description provided for @featureAudioTitle.
  ///
  /// In de, this message translates to:
  /// **'Audio-Aussprache'**
  String get featureAudioTitle;

  /// No description provided for @featureAudioBody.
  ///
  /// In de, this message translates to:
  /// **'Jeder Kontext-Satz wird dir vorgelesen — lokal gebündelte Audios, ganz ohne Internet.'**
  String get featureAudioBody;

  /// No description provided for @featureLessonsTitle.
  ///
  /// In de, this message translates to:
  /// **'Lektion für Lektion mit Prüfung'**
  String get featureLessonsTitle;

  /// No description provided for @featureLessonsBody.
  ///
  /// In de, this message translates to:
  /// **'100 Lektionen à 10 Wörter. Nach jeder Lektion folgt die Prüfung in 6 Stufen (Wort, Sätze, Audio, Geschichte) mit höchstens 3 Fehlern — wer besteht, schaltet frei.'**
  String get featureLessonsBody;

  /// No description provided for @featureDictTitle.
  ///
  /// In de, this message translates to:
  /// **'Offline-Wörterbuch'**
  String get featureDictTitle;

  /// No description provided for @featureDictBody.
  ///
  /// In de, this message translates to:
  /// **'Suche arabische Wörter und Sätze — harakat- und umschrift-insensitiv, damit du auch ohne Diakritik findest.'**
  String get featureDictBody;

  /// No description provided for @featureStatsTitle.
  ///
  /// In de, this message translates to:
  /// **'Lernstatistik'**
  String get featureStatsTitle;

  /// No description provided for @featureStatsBody.
  ///
  /// In de, this message translates to:
  /// **'Behalte deine Serie 🔥, aktiven Tage und eine 16-Wochen-Aktivitäts-Heatmap im Überblick.'**
  String get featureStatsBody;

  /// No description provided for @featureReviewTitle.
  ///
  /// In de, this message translates to:
  /// **'Wiederholungen'**
  String get featureReviewTitle;

  /// No description provided for @featureReviewBody.
  ///
  /// In de, this message translates to:
  /// **'Fällige Wörter werden dir nach dem SM-2-Lernabstand erneut vorgelegt — für langfristigen Wortschatz.'**
  String get featureReviewBody;

  /// No description provided for @featureOfflineTitle.
  ///
  /// In de, this message translates to:
  /// **'Offline & kostenlos'**
  String get featureOfflineTitle;

  /// No description provided for @featureOfflineBody.
  ///
  /// In de, this message translates to:
  /// **'Alles funktioniert ohne Internet, dein Fortschritt bleibt auf deinem Gerät — und die App ist komplett kostenlos.'**
  String get featureOfflineBody;

  /// No description provided for @devNoteTitle.
  ///
  /// In de, this message translates to:
  /// **'Jumlah wird aktiv weiterentwickelt'**
  String get devNoteTitle;

  /// No description provided for @devNoteBody.
  ///
  /// In de, this message translates to:
  /// **'Neue Lektionen, Sprachniveaus und Funktionen folgen regelmäßig — bleib dran und wachse mit der App mit.'**
  String get devNoteBody;

  /// No description provided for @supportHeading.
  ///
  /// In de, this message translates to:
  /// **'Unterstütze die Entwicklung'**
  String get supportHeading;

  /// No description provided for @supportBody.
  ///
  /// In de, this message translates to:
  /// **'Jumlah ist kostenlos. Wenn dir die App gefällt, kannst du die Entwicklung freiwillig unterstützen:'**
  String get supportBody;

  /// No description provided for @letsGo.
  ///
  /// In de, this message translates to:
  /// **'Los geht’s'**
  String get letsGo;

  /// No description provided for @transliterationTitle.
  ///
  /// In de, this message translates to:
  /// **'Transliteration (DIN 31635)'**
  String get transliterationTitle;

  /// No description provided for @transliterationIntro.
  ///
  /// In de, this message translates to:
  /// **'Die arabische Umschrift in dieser App folgt DIN 31635, dem wissenschaftlichen Standard der Arabistik. Sie zeigt exakt, wie ein Wort geschrieben und gesprochen wird — inklusive Laute, die es im Deutschen nicht gibt. Ab Stufe B1 wird die Umschrift bewusst nicht mehr angezeigt, da du dann die arabische Schrift direkt lesen sollst.'**
  String get transliterationIntro;

  /// No description provided for @lettersHeading.
  ///
  /// In de, this message translates to:
  /// **'Buchstaben'**
  String get lettersHeading;

  /// No description provided for @diacriticsHeading.
  ///
  /// In de, this message translates to:
  /// **'Kurzvokale & Zeichen'**
  String get diacriticsHeading;

  /// No description provided for @tlHamza.
  ///
  /// In de, this message translates to:
  /// **'Stimmritzenverschluss (Hamza) — der Knacklaut vor Vokalen wie in „Verein“'**
  String get tlHamza;

  /// No description provided for @tlAlef.
  ///
  /// In de, this message translates to:
  /// **'langes „a“ wie in „Vater“'**
  String get tlAlef;

  /// No description provided for @tlBa.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „b“'**
  String get tlBa;

  /// No description provided for @tlTa.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „t“'**
  String get tlTa;

  /// No description provided for @tlTha.
  ///
  /// In de, this message translates to:
  /// **'stimmloses „th“ wie engl. „think“'**
  String get tlTha;

  /// No description provided for @tlJim.
  ///
  /// In de, this message translates to:
  /// **'wie „dsch“ in „Dschungel“'**
  String get tlJim;

  /// No description provided for @tlHa.
  ///
  /// In de, this message translates to:
  /// **'gepresster Rachen-h-Laut, schärfer als deutsches „h“'**
  String get tlHa;

  /// No description provided for @tlKha.
  ///
  /// In de, this message translates to:
  /// **'wie „ch“ in „Bach“'**
  String get tlKha;

  /// No description provided for @tlDal.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „d“'**
  String get tlDal;

  /// No description provided for @tlDhal.
  ///
  /// In de, this message translates to:
  /// **'stimmhaftes „th“ wie engl. „this“'**
  String get tlDhal;

  /// No description provided for @tlRa.
  ///
  /// In de, this message translates to:
  /// **'gerolltes „r“'**
  String get tlRa;

  /// No description provided for @tlZay.
  ///
  /// In de, this message translates to:
  /// **'stimmhaftes „s“ wie in „Sonne“'**
  String get tlZay;

  /// No description provided for @tlSin.
  ///
  /// In de, this message translates to:
  /// **'stimmloses „s“ wie in „Wasser“'**
  String get tlSin;

  /// No description provided for @tlShin.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „sch“'**
  String get tlShin;

  /// No description provided for @tlSad.
  ///
  /// In de, this message translates to:
  /// **'emphatisches (velarisiertes) „s“'**
  String get tlSad;

  /// No description provided for @tlDad.
  ///
  /// In de, this message translates to:
  /// **'emphatisches „d“'**
  String get tlDad;

  /// No description provided for @tlTaEmph.
  ///
  /// In de, this message translates to:
  /// **'emphatisches „t“'**
  String get tlTaEmph;

  /// No description provided for @tlZa.
  ///
  /// In de, this message translates to:
  /// **'emphatisches „th“ (wie ذ, aber velarisiert)'**
  String get tlZa;

  /// No description provided for @tlAyn.
  ///
  /// In de, this message translates to:
  /// **'stimmhafter Rachenlaut ohne deutsches Äquivalent (ʿAin)'**
  String get tlAyn;

  /// No description provided for @tlGhayn.
  ///
  /// In de, this message translates to:
  /// **'wie das französische „r“ (Reibelaut im Rachen)'**
  String get tlGhayn;

  /// No description provided for @tlFa.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „f“'**
  String get tlFa;

  /// No description provided for @tlQaf.
  ///
  /// In de, this message translates to:
  /// **'wie „k“, aber tief im Rachen gebildet (Uvular)'**
  String get tlQaf;

  /// No description provided for @tlKaf.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „k“'**
  String get tlKaf;

  /// No description provided for @tlLam.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „l“'**
  String get tlLam;

  /// No description provided for @tlMim.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „m“'**
  String get tlMim;

  /// No description provided for @tlNun.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „n“'**
  String get tlNun;

  /// No description provided for @tlHeh.
  ///
  /// In de, this message translates to:
  /// **'wie deutsches „h“'**
  String get tlHeh;

  /// No description provided for @tlWaw.
  ///
  /// In de, this message translates to:
  /// **'Halbvokal „w“ oder langes „u“'**
  String get tlWaw;

  /// No description provided for @tlYa.
  ///
  /// In de, this message translates to:
  /// **'Halbvokal „j“ oder langes „i“'**
  String get tlYa;

  /// No description provided for @tlTaMarbuta.
  ///
  /// In de, this message translates to:
  /// **'Tāʾ marbūṭa: „a“ am Wortende, vor Folgewort oft „-at“'**
  String get tlTaMarbuta;

  /// No description provided for @tlAlifMaqsura.
  ///
  /// In de, this message translates to:
  /// **'Alif maqṣūra: langes „a“ am Wortende'**
  String get tlAlifMaqsura;

  /// No description provided for @tdFatha.
  ///
  /// In de, this message translates to:
  /// **'Fatha — kurzes „a“'**
  String get tdFatha;

  /// No description provided for @tdKasra.
  ///
  /// In de, this message translates to:
  /// **'Kasra — kurzes „i“'**
  String get tdKasra;

  /// No description provided for @tdDamma.
  ///
  /// In de, this message translates to:
  /// **'Damma — kurzes „u“'**
  String get tdDamma;

  /// No description provided for @tdSukun.
  ///
  /// In de, this message translates to:
  /// **'Sukun — der Konsonant trägt keinen Vokal'**
  String get tdSukun;

  /// No description provided for @tdShadda.
  ///
  /// In de, this message translates to:
  /// **'Shadda — der Konsonant wird doppelt gesprochen'**
  String get tdShadda;

  /// No description provided for @tdSukunSymbol.
  ///
  /// In de, this message translates to:
  /// **'(kein Vokal)'**
  String get tdSukunSymbol;

  /// No description provided for @tdShaddaSymbol.
  ///
  /// In de, this message translates to:
  /// **'(Verdopplung)'**
  String get tdShaddaSymbol;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
