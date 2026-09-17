// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jumlah — Classical Arabic Learning App';

  @override
  String get cancel => 'Cancel';

  @override
  String get restart => 'Restart';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String loadError(String message) {
    return 'Error while loading: $message';
  }

  @override
  String get tabLearn => 'Learn';

  @override
  String get tabQuiz => 'Quiz';

  @override
  String get tabStats => 'Stats';

  @override
  String get tabInfo => 'Info';

  @override
  String get dictionaryTooltip => 'Dictionary';

  @override
  String get examTitle => 'Exam';

  @override
  String get examSubtitle => 'Test your knowledge, level by level.';

  @override
  String get levelsHeading => 'Levels';

  @override
  String levelPlannedSnack(String group) {
    return 'Level $group is in preparation — coming soon.';
  }

  @override
  String levelLockedSnack(String group) {
    return 'Finish the previous level first to unlock $group.';
  }

  @override
  String levelTitle(String group, String label) {
    return 'Level $group · $label';
  }

  @override
  String get levelLabelA1 => 'Beginner';

  @override
  String get levelLabelA2 => 'Very common';

  @override
  String get levelLabelB1 => 'Common';

  @override
  String get levelLabelB2 => 'Intermediate';

  @override
  String get levelLabelC1 => 'Rare / Classical';

  @override
  String wordsRange(int start, int end) {
    return 'Words $start–$end';
  }

  @override
  String percentValue(int percent) {
    return '$percent %';
  }

  @override
  String get previousLevelLocked => 'Complete previous level';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get levelComplete => 'Level completed ✅';

  @override
  String get startFirstLesson => 'Start the first lesson';

  @override
  String lessonsOfLevel(int done, int total) {
    return 'Lesson $done of $total in the level';
  }

  @override
  String get heroWelcome => 'Welcome to Jumlah';

  @override
  String get heroSubtitle => 'Learn classical Arabic — offline & free.';

  @override
  String get statWords => 'Words';

  @override
  String get statLessons => 'Lessons';

  @override
  String get statProgress => 'Progress';

  @override
  String get continueLearning => 'Continue learning';

  @override
  String get startLearning => 'Start learning';

  @override
  String continueSubtitleResume(int lesson, int word, String group) {
    return 'Lesson $lesson · Word $word of 10 · $group';
  }

  @override
  String continueSubtitleStart(String group) {
    return 'Lesson 1 · Words 1–10 · $group';
  }

  @override
  String reviewDueOne(int count) {
    return '$count word due — time for a review.';
  }

  @override
  String reviewDueMany(int count) {
    return '$count words due — time for a review.';
  }

  @override
  String get reviewEmptyHint => 'Pass lessons to review their words here.';

  @override
  String get reviewCardTitle => 'Review';

  @override
  String get batchListNoWords => 'No words found in this group.';

  @override
  String get finalExam => 'Final exam';

  @override
  String lessonRange(int lesson, int start, int end) {
    return 'Lesson $lesson · Words $start–$end';
  }

  @override
  String get lessonLockedHint =>
      'Pass the previous lesson without errors to unlock this one.';

  @override
  String get lessonNotLearnedHint =>
      'Learn this lesson first before taking the quiz.';

  @override
  String get levelLockedHint =>
      'Finish the previous level first to unlock this one.';

  @override
  String learnTitle(String group) {
    return 'Learn · $group';
  }

  @override
  String get transliterationTooltip => 'How transliteration works';

  @override
  String get restartTitle => 'Start over from the beginning?';

  @override
  String get restartLearnBody =>
      'The saved progress of this lesson will be lost.';

  @override
  String get restartQuizBody => 'The progress of this quiz will be lost.';

  @override
  String get restartTooltip => 'Start over from the beginning';

  @override
  String get learnNoWords =>
      'No words found in this group.\n(words.json needs to be imported first — Task D1)';

  @override
  String lessonTitle(int lesson) {
    return 'Lesson $lesson';
  }

  @override
  String get noContextSentence =>
      'No context sentence is available for this word yet.';

  @override
  String sentenceCounter(int index, int total) {
    return 'Sentence $index/$total';
  }

  @override
  String get rootSection => 'Root';

  @override
  String get masdarSection => 'Masdar (verbal noun)';

  @override
  String get toQuiz => 'Start exam';

  @override
  String get stageArabicToGerman => 'Stage 1/6 · Arabic → German';

  @override
  String get stageGermanToArabic => 'Stage 2/6 · German → Arabic';

  @override
  String get stageMixed => 'Stage 3/6 · Alternating';

  @override
  String get stageSentences => 'Stage 4/6 · Sentences';

  @override
  String get stageAudio => 'Stage 5/6 · Audio';

  @override
  String get stageStory => 'Stage 6/6 · Story';

  @override
  String get readStory => 'Read the story:';

  @override
  String get continueToMatching => 'Continue to matching';

  @override
  String get audioPrompt => 'Listen and choose the German meaning:';

  @override
  String get listenSentence => 'Play sentence';

  @override
  String get sentencePrompt => 'Which meaning fits this sentence?';

  @override
  String get sharePassed => 'Passed ✅';

  @override
  String get shareFailed => 'Not passed';

  @override
  String get shareCompleted => 'Completed';

  @override
  String shareResultLine(String status) {
    return 'Result: $status';
  }

  @override
  String shareCorrectLine(int score, int total) {
    return 'Correct answers: $score of $total';
  }

  @override
  String shareErrorsLine(int wrong, int allowed) {
    return 'Errors: $wrong of $allowed allowed';
  }

  @override
  String get copiedToClipboard => 'Result copied to clipboard.';

  @override
  String get passedTitle => 'Passed!';

  @override
  String get failedTitle => 'Not passed';

  @override
  String get resultTitle => 'Result';

  @override
  String errorsSummary(int wrong, int allowed) {
    return '$wrong errors of $allowed allowed';
  }

  @override
  String scoreCorrectAnswers(int score) {
    return '$score correct answers';
  }

  @override
  String get lessonPassedUnlock =>
      'Lesson passed — the next lesson is now unlocked!';

  @override
  String get lessonFailedRetry =>
      'Lesson not passed — please try again to unlock the next lesson.';

  @override
  String get practiceAgain => 'Practice again:';

  @override
  String get shareResult => 'Share result';

  @override
  String get continueButton => 'Continue';

  @override
  String groupCompletedTitle(String group) {
    return '$group completed';
  }

  @override
  String get allLessonsDone => 'All lessons completed!';

  @override
  String get finalExamFailed =>
      'The final exam was not error-free yet — try again.';

  @override
  String get finalExamIntro =>
      'To finish, a final exam covers all words of this group.';

  @override
  String get startFinalExam => 'Start final exam';

  @override
  String get finalExamPassedTitle => 'Final exam passed!';

  @override
  String get levelUnlockedText =>
      'The level is complete — the next stage is now unlocked. Further stages will follow as soon as their content is available.';

  @override
  String get backToLessons => 'Back to lessons';

  @override
  String get reviewAppBarTitle => 'Review';

  @override
  String get revealAnswer => 'Show answer';

  @override
  String get quality0 => 'Forgot';

  @override
  String get quality1 => 'Almost';

  @override
  String get quality2 => 'Hard';

  @override
  String get quality3 => 'Close';

  @override
  String get quality4 => 'Good';

  @override
  String get quality5 => 'Perfect';

  @override
  String get howWellQuestion => 'How well did you know it?';

  @override
  String get reviewAllDone => 'All done';

  @override
  String get reviewNoDue =>
      'No words are due right now. Pass lessons in the exam to add their words to the review — and come back tomorrow.';

  @override
  String get sessionComplete => 'Session completed';

  @override
  String rememberedSummary(int correct, int total) {
    return '$correct of $total words remembered.';
  }

  @override
  String get forgottenHint =>
      'No problem — the forgotten words will automatically come back tomorrow.';

  @override
  String get noActivityTitle => 'No learning activity yet';

  @override
  String get noActivityBody =>
      'As soon as you flip through a lesson or answer a quiz question, Jumlah tracks your streak and this heatmap — automatically and fully offline.';

  @override
  String get currentStreak => 'Day streak';

  @override
  String get bestStreak => 'Best streak';

  @override
  String get activeDays => 'Active days';

  @override
  String get today => 'Today';

  @override
  String get wordsViewed => 'Words viewed';

  @override
  String get quizAnswers => 'Quiz answers';

  @override
  String get lessonsCompleted => 'Lessons passed';

  @override
  String get heatmapTitle => 'Your learning activity';

  @override
  String heatmapSubtitle(int weeks) {
    return 'Last $weeks weeks — one cell per day';
  }

  @override
  String get weekdayMo => 'Mo';

  @override
  String get weekdayDi => 'Tu';

  @override
  String get weekdayMi => 'We';

  @override
  String get weekdayDo => 'Th';

  @override
  String get weekdayFr => 'Fr';

  @override
  String get weekdaySa => 'Sa';

  @override
  String get weekdaySo => 'Su';

  @override
  String heatmapTooltip(String date, int count) {
    return '$date · $count activities';
  }

  @override
  String get legendLittle => 'Little';

  @override
  String get legendMuch => 'Much';

  @override
  String get dictionaryTitle => 'Dictionary';

  @override
  String get dictionaryHint =>
      'Search a word (Arabic, German, transliteration)…';

  @override
  String get dictionaryEmptyHint =>
      'Search for an Arabic word, its German meaning or the scholarly transliteration.';

  @override
  String get noResults => 'No matches found.';

  @override
  String rootTitle(String root) {
    return 'Root $root';
  }

  @override
  String get contextSentences => 'Context sentences';

  @override
  String get supportLegalHeading => 'Support & Legal';

  @override
  String get supportLegalBody =>
      'Support development or view the legally required information.';

  @override
  String get supportTitle => 'Support the developer ☕';

  @override
  String get supportSubtitle =>
      'Voluntary donation via Ko-fi — the app stays free.';

  @override
  String get legalTitle => 'Imprint & Privacy';

  @override
  String get legalSubtitle => 'Legal notice and privacy information.';

  @override
  String get languageHeading => 'Language';

  @override
  String get languageBody =>
      'Choose the app interface — the learning content stays Arabic ↔ German.';

  @override
  String get themeHeading => 'Theme';

  @override
  String get themeBody => 'Choose a light or dark design.';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'English';

  @override
  String get languageAr => 'العربية';

  @override
  String get welcomeTitle => 'Welcome to Jumlah';

  @override
  String get welcomeSubtitle =>
      'Learn classical Arabic (Fusha / Quranic) — step by step, offline & free, at your own pace.';

  @override
  String get motivationTitle => 'Stay on the ball 🔥';

  @override
  String get motivationBody =>
      'Consistency beats talent: Just 10 minutes a day keeps you moving forward week after week — from the first verbs to rare Quranic expressions.';

  @override
  String get whatToExpect => 'What to expect:';

  @override
  String get featureClassicalTitle => 'Classical Arabic';

  @override
  String get featureClassicalBody =>
      'The 500 most common words of classical Arabic — each with 3 authentic context sentences, root family, masdar and DIN 31635 transliteration.';

  @override
  String get featureAudioTitle => 'Audio pronunciation';

  @override
  String get featureAudioBody =>
      'Every context sentence is read out to you — locally bundled audio, no internet needed.';

  @override
  String get featureLessonsTitle => 'Lesson by lesson with exam';

  @override
  String get featureLessonsBody =>
      '100 lessons of 10 words each. After every lesson an exam in 6 stages (word, sentences, audio, story) with at most 3 errors — pass to unlock.';

  @override
  String get featureDictTitle => 'Offline dictionary';

  @override
  String get featureDictBody =>
      'Search Arabic words and sentences — harakat- and transliteration-insensitive, so you find results even without diacritics.';

  @override
  String get featureStatsTitle => 'Learning statistics';

  @override
  String get featureStatsBody =>
      'Keep an eye on your streak 🔥, active days and a 16-week activity heatmap.';

  @override
  String get featureReviewTitle => 'Reviews';

  @override
  String get featureReviewBody =>
      'Due words are shown again according to the SM-2 spacing interval — for long-term vocabulary.';

  @override
  String get featureOfflineTitle => 'Offline & free';

  @override
  String get featureOfflineBody =>
      'Everything works without internet, your progress stays on your device — and the app is completely free.';

  @override
  String get devNoteTitle => 'Jumlah is under active development';

  @override
  String get devNoteBody =>
      'New lessons, levels and features arrive regularly — stay tuned and grow with the app.';

  @override
  String get supportHeading => 'Support the development';

  @override
  String get supportBody =>
      'Jumlah is free. If you like the app, you can voluntarily support its development:';

  @override
  String get letsGo => 'Let\'s go';

  @override
  String get transliterationTitle => 'Transliteration (DIN 31635)';

  @override
  String get transliterationIntro =>
      'The Arabic transliteration in this app follows DIN 31635, the scholarly standard of Arabic studies. It shows exactly how a word is written and pronounced — including sounds that do not exist in German. From level B1 on, the transliteration is intentionally no longer shown, because by then you should read the Arabic script directly.';

  @override
  String get lettersHeading => 'Letters';

  @override
  String get diacriticsHeading => 'Short vowels & signs';

  @override
  String get tlHamza =>
      'Glottal stop (Hamza) — the catch sound before vowels, as in \"uh-oh\"';

  @override
  String get tlAlef => 'long \"ā\" as in \"father\"';

  @override
  String get tlBa => 'like English \"b\"';

  @override
  String get tlTa => 'like English \"t\"';

  @override
  String get tlTha => 'voiceless \"th\" as in \"think\"';

  @override
  String get tlJim => 'like \"j\" in \"jam\"';

  @override
  String get tlHa => 'pressed throat-h sound, sharper than English \"h\"';

  @override
  String get tlKha => 'like \"ch\" in Scottish \"loch\"';

  @override
  String get tlDal => 'like English \"d\"';

  @override
  String get tlDhal => 'voiced \"th\" as in \"this\"';

  @override
  String get tlRa => 'rolled \"r\"';

  @override
  String get tlZay => 'voiced \"s\" as in \"rose\"';

  @override
  String get tlSin => 'voiceless \"s\" as in \"sun\"';

  @override
  String get tlShin => 'like \"sh\" in \"ship\"';

  @override
  String get tlSad => 'emphatic (velarized) \"s\"';

  @override
  String get tlDad => 'emphatic \"d\"';

  @override
  String get tlTaEmph => 'emphatic \"t\"';

  @override
  String get tlZa => 'emphatic \"th\" (like the letter ذ, but velarized)';

  @override
  String get tlAyn =>
      'voiced throat consonant without English equivalent (ʿAin)';

  @override
  String get tlGhayn => 'like the French \"r\" (fricative in the throat)';

  @override
  String get tlFa => 'like English \"f\"';

  @override
  String get tlQaf => 'like \"k\", but formed deep in the throat (uvular)';

  @override
  String get tlKaf => 'like English \"k\"';

  @override
  String get tlLam => 'like English \"l\"';

  @override
  String get tlMim => 'like English \"m\"';

  @override
  String get tlNun => 'like English \"n\"';

  @override
  String get tlHeh => 'like English \"h\"';

  @override
  String get tlWaw => 'semi-vowel \"w\" or long \"ū\"';

  @override
  String get tlYa => 'semi-vowel \"y\" or long \"ī\"';

  @override
  String get tlTaMarbuta =>
      'Tāʾ marbūṭa: \"a\" at the end of a word, before a following word often \"-at\"';

  @override
  String get tlAlifMaqsura => 'Alif maqṣūra: long \"ā\" at the end of a word';

  @override
  String get tdFatha => 'Fatha — short \"a\"';

  @override
  String get tdKasra => 'Kasra — short \"i\"';

  @override
  String get tdDamma => 'Damma — short \"u\"';

  @override
  String get tdSukun => 'Sukun — the consonant carries no vowel';

  @override
  String get tdShadda => 'Shadda — the consonant is pronounced doubled';

  @override
  String get tdSukunSymbol => '(no vowel)';

  @override
  String get tdShaddaSymbol => '(doubling)';
}
