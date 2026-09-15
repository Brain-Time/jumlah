// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'جُمْلَة — تعلّم اللغة العربية الفصحى';

  @override
  String get cancel => 'إلغاء';

  @override
  String get restart => 'البدء من جديد';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get done => 'تمّ';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String loadError(String message) {
    return 'خطأ أثناء التحميل: $message';
  }

  @override
  String get tabLearn => 'تعلّم';

  @override
  String get tabQuiz => 'اختبار';

  @override
  String get tabStats => 'إحصائيات';

  @override
  String get tabInfo => 'معلومات';

  @override
  String get dictionaryTooltip => 'القاموس';

  @override
  String get examTitle => 'الاختبار';

  @override
  String get examSubtitle => 'اختبر معلوماتك مستوىً بمستوى.';

  @override
  String get levelsHeading => 'المستويات';

  @override
  String levelPlannedSnack(String group) {
    return 'المستوى $group قيد التحضير — قريبًا.';
  }

  @override
  String levelLockedSnack(String group) {
    return 'أكمل المستوى السابق أولًا لفتح $group.';
  }

  @override
  String levelTitle(String group, String label) {
    return 'المستوى $group · $label';
  }

  @override
  String get levelLabelA1 => 'أساسي';

  @override
  String get levelLabelA2 => 'شائع جدًا';

  @override
  String get levelLabelB1 => 'شائع';

  @override
  String get levelLabelB2 => 'متوسط';

  @override
  String get levelLabelC1 => 'نادر / كلاسيكي';

  @override
  String wordsRange(int start, int end) {
    return 'الرتب $start–$end';
  }

  @override
  String percentValue(int percent) {
    return '$percent٪';
  }

  @override
  String get previousLevelLocked => 'أكمل المستوى السابق';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get levelComplete => 'اكتمل المستوى ✅';

  @override
  String get startFirstLesson => 'ابدأ الدرس الأول';

  @override
  String lessonsOfLevel(int done, int total) {
    return 'الدرس $done من $total في المستوى';
  }

  @override
  String get heroWelcome => 'مرحبًا بك في جُمْلَة';

  @override
  String get heroSubtitle => 'تعلّم العربية الفصحى — دون إنترنت وبالمجان.';

  @override
  String get statWords => 'كلمات';

  @override
  String get statLessons => 'دروس';

  @override
  String get statProgress => 'التقدّم';

  @override
  String get continueLearning => 'واصل التعلّم';

  @override
  String get startLearning => 'ابدأ التعلّم';

  @override
  String continueSubtitleResume(int lesson, int word, String group) {
    return 'الدرس $lesson · الكلمة $word من 10 · $group';
  }

  @override
  String continueSubtitleStart(String group) {
    return 'الدرس 1 · الرتب 1–10 · $group';
  }

  @override
  String reviewDueOne(int count) {
    return '$count كلمة مستحقة — حان وقت المراجعة.';
  }

  @override
  String reviewDueMany(int count) {
    return '$count كلمات مستحقة — حان وقت المراجعة.';
  }

  @override
  String get reviewEmptyHint => 'اجتز الدروس لتراجع كلماتها هنا.';

  @override
  String get reviewCardTitle => 'مراجعة';

  @override
  String get batchListNoWords => 'لم تُعثر على كلمات في هذه المجموعة.';

  @override
  String get finalExam => 'الاختبار الشامل';

  @override
  String lessonRange(int lesson, int start, int end) {
    return 'الدرس $lesson · الرتب $start–$end';
  }

  @override
  String get lessonLockedHint => 'اجتز الدرس السابق دون أخطاء لفتح هذا الدرس.';

  @override
  String get lessonNotLearnedHint =>
      'تعلّم هذا الدرس أولًا قبل إجراء الاختبار.';

  @override
  String get levelLockedHint => 'أكمل المستوى السابق أولًا لفتح هذا المستوى.';

  @override
  String learnTitle(String group) {
    return 'تعلّم · $group';
  }

  @override
  String get transliterationTooltip => 'شرح الكتابة الصوتية';

  @override
  String get restartTitle => 'تبدأ من البداية؟';

  @override
  String get restartLearnBody => 'سيضيع التقدّم المحفوظ لهذا الدرس.';

  @override
  String get restartQuizBody => 'سيضيع التقدّم الحالي في هذا الاختبار.';

  @override
  String get restartTooltip => 'البدء من البداية';

  @override
  String get learnNoWords =>
      'لم تُعثر على كلمات في هذه المجموعة.\n(يجب استيراد words.json أولًا — Task D1)';

  @override
  String lessonTitle(int lesson) {
    return 'الدرس $lesson';
  }

  @override
  String get noContextSentence => 'لا توجد جملة سياق لهذه الكلمة بعد.';

  @override
  String sentenceCounter(int index, int total) {
    return 'الجملة $index/$total';
  }

  @override
  String get rootSection => 'الجذر';

  @override
  String get masdarSection => 'المصدر';

  @override
  String get toQuiz => 'إلى الاختبار';

  @override
  String get stageArabicToGerman => 'المرحلة 1/6 · عربي ← ألماني';

  @override
  String get stageGermanToArabic => 'المرحلة 2/6 · ألماني ← عربي';

  @override
  String get stageMixed => 'المرحلة 3/6 · بالتناوب';

  @override
  String get stageSentences => 'المرحلة 4/6 · الجمل';

  @override
  String get stageAudio => 'المرحلة 5/6 · الصوت';

  @override
  String get stageStory => 'المرحلة 6/6 · القصة';

  @override
  String get readStory => 'اقرأ القصة:';

  @override
  String get continueToMatching => 'المتابعة إلى المطابقة';

  @override
  String get audioPrompt => 'استمع واختر المعنى الألماني:';

  @override
  String get listenSentence => 'استمع إلى الجملة';

  @override
  String get sentencePrompt => 'أي معنى يناسب هذه الجملة؟';

  @override
  String get sharePassed => 'ناجح ✅';

  @override
  String get shareFailed => 'غير ناجح';

  @override
  String get shareCompleted => 'مكتمل';

  @override
  String shareResultLine(String status) {
    return 'النتيجة: $status';
  }

  @override
  String shareCorrectLine(int score, int total) {
    return 'الإجابات الصحيحة: $score من $total';
  }

  @override
  String shareErrorsLine(int wrong, int allowed) {
    return 'الأخطاء: $wrong من أصل $allowed مسموح بها';
  }

  @override
  String get copiedToClipboard => 'نُسخت النتيجة إلى الحافظة.';

  @override
  String get passedTitle => 'نجحت!';

  @override
  String get failedTitle => 'غير ناجح';

  @override
  String get resultTitle => 'النتيجة';

  @override
  String errorsSummary(int wrong, int allowed) {
    return '$wrong أخطاء من أصل $allowed مسموح بها';
  }

  @override
  String scoreCorrectAnswers(int score) {
    return '$score إجابات صحيحة';
  }

  @override
  String get lessonPassedUnlock => 'نجح الدرس — الدرس التالي مفتوح الآن!';

  @override
  String get lessonFailedRetry =>
      'لم ينجح الدرس — كرر المحاولة لفتح الدرس التالي.';

  @override
  String get practiceAgain => 'تدرّب مجددًا:';

  @override
  String get shareResult => 'شارك النتيجة';

  @override
  String get continueButton => 'متابعة';

  @override
  String groupCompletedTitle(String group) {
    return 'اكتمل $group';
  }

  @override
  String get allLessonsDone => 'أنهيت جميع الدروس!';

  @override
  String get finalExamFailed =>
      'لم يكن الاختبار الشامل خاليًا من الأخطاء بعد — حاول مجددًا.';

  @override
  String get finalExamIntro =>
      'في الختام يأتي اختبار شامل لكل كلمات هذه المجموعة.';

  @override
  String get startFinalExam => 'ابدأ الاختبار الشامل';

  @override
  String get finalExamPassedTitle => 'نجح الاختبار الشامل!';

  @override
  String get levelUnlockedText =>
      'اكتمل المستوى — المستوى التالي مفتوح الآن. ستأتي مستويات أخرى فور توفّر محتواها.';

  @override
  String get backToLessons => 'إلى نظرة الدروس';

  @override
  String get reviewAppBarTitle => 'مراجعة';

  @override
  String get revealAnswer => 'أظهر الإجابة';

  @override
  String get quality0 => 'نسيت';

  @override
  String get quality1 => 'تقريبًا';

  @override
  String get quality2 => 'صعب';

  @override
  String get quality3 => 'قريب';

  @override
  String get quality4 => 'جيد';

  @override
  String get quality5 => 'ممتاز';

  @override
  String get howWellQuestion => 'إلى أي مدى كنت تعرفها؟';

  @override
  String get reviewAllDone => 'كل شيء تمّ';

  @override
  String get reviewNoDue =>
      'لا توجد كلمات مستحقة الآن. اجتز الدروس في الاختبار لتُضاف كلماتها إلى المراجعة — وعُد غدًا.';

  @override
  String get sessionComplete => 'اكتملت الجلسة';

  @override
  String rememberedSummary(int correct, int total) {
    return 'تذكّرت $correct من أصل $total كلمات.';
  }

  @override
  String get forgottenHint => 'لا بأس — ستعود الكلمات المنسية تلقائيًا غدًا.';

  @override
  String get noActivityTitle => 'لا نشاط تعليمي بعد';

  @override
  String get noActivityBody =>
      'ما إن تتصفّح درسًا أو تجيب عن سؤال في اختبار حتى يحسب جُمْلَة سلسلتك وهذه الخريطة الحرارية — تلقائيًا وبدون إنترنت تمامًا.';

  @override
  String get currentStreak => 'أيام السلسلة';

  @override
  String get bestStreak => 'أفضل سلسلة';

  @override
  String get activeDays => 'أيام نشطة';

  @override
  String get today => 'اليوم';

  @override
  String get wordsViewed => 'كلمات مُطالَعة';

  @override
  String get quizAnswers => 'إجابات الاختبار';

  @override
  String get lessonsCompleted => 'دروس ناجحة';

  @override
  String get heatmapTitle => 'نشاطك التعليمي';

  @override
  String heatmapSubtitle(int weeks) {
    return 'آخر $weeks أسبوعًا — خلية لكل يوم';
  }

  @override
  String get weekdayMo => 'إث';

  @override
  String get weekdayDi => 'ث';

  @override
  String get weekdayMi => 'أر';

  @override
  String get weekdayDo => 'خ';

  @override
  String get weekdayFr => 'ج';

  @override
  String get weekdaySa => 'س';

  @override
  String get weekdaySo => 'أح';

  @override
  String heatmapTooltip(String date, int count) {
    return '$date · $count أنشطة';
  }

  @override
  String get legendLittle => 'قليل';

  @override
  String get legendMuch => 'كثير';

  @override
  String get dictionaryTitle => 'القاموس';

  @override
  String get dictionaryHint => 'ابحث عن كلمة (عربي، ألماني، كتابة صوتية)…';

  @override
  String get dictionaryEmptyHint =>
      'ابحث عن كلمة عربية أو معناها الألماني أو كتابتها الصوتية العلمية.';

  @override
  String get noResults => 'لا نتائج.';

  @override
  String rootTitle(String root) {
    return 'الجذر $root';
  }

  @override
  String get contextSentences => 'جمل سياق';

  @override
  String get supportLegalHeading => 'الدعم والقانون';

  @override
  String get supportLegalBody =>
      'ادعم التطوير أو اطّلع على المعلومات القانونية المطلوبة.';

  @override
  String get supportTitle => 'ادعم المطوّر ☕';

  @override
  String get supportSubtitle => 'تبرّع طوعي عبر Ko-fi — التطبيق يبقى مجانيًا.';

  @override
  String get legalTitle => 'بيانات الناشر والخصوصية';

  @override
  String get legalSubtitle => 'بيانات الناشر وملاحظات الخصوصية.';

  @override
  String get languageHeading => 'اللغة';

  @override
  String get languageBody =>
      'اختر لغة الواجهة — تبقى محتويات التعلّم عربي ↔ ألماني كما هي.';

  @override
  String get languageDe => 'Deutsch';

  @override
  String get languageEn => 'English';

  @override
  String get languageAr => 'العربية';

  @override
  String get welcomeTitle => 'مرحبًا بك في جُمْلَة';

  @override
  String get welcomeSubtitle =>
      'تعلّم العربية الفصحى (فصحى / قرآنية) — خطوة بخطوة، دون إنترنت وبالمجان، وبسرعتك الخاصة.';

  @override
  String get motivationTitle => 'واصل 🔥';

  @override
  String get motivationBody =>
      'المواظبة تتفوّق على الموهبة: عشر دقائق يوميًا تدفعك قدمًا أسبوعًا بعد أسبوع — من الأفعال الأولى إلى التعابير القرآنية النادرة.';

  @override
  String get whatToExpect => 'ما الذي ينتظرك:';

  @override
  String get featureClassicalTitle => 'العربية الفصحى';

  @override
  String get featureClassicalBody =>
      'أكثر 500 كلمة شيوعًا في العربية الفصحى — كل واحدة مع 3 جمل سياق حقيقية والعائلة الجذرية والمصدر والكتابة الصوتية DIN 31635.';

  @override
  String get featureAudioTitle => 'النطق الصوتي';

  @override
  String get featureAudioBody =>
      'تُقرأ لك كل جملة سياق — ملفات صوتية محمّلة محليًا، دون إنترنت إطلاقًا.';

  @override
  String get featureLessonsTitle => 'درسًا تلو درس مع اختبار';

  @override
  String get featureLessonsBody =>
      '50 درسًا × 10 كلمات. بعد كل درس اختبار من 6 مراحل (كلمة، جمل، صوت، قصة) بأخطاء لا تتجاوز 3 — من ينجح يفتح التالي.';

  @override
  String get featureDictTitle => 'قاموس دون إنترنت';

  @override
  String get featureDictBody =>
      'ابحث عن الكلمات والجمل العربية — دون حساسية للحركات أو الكتابة الصوتية، فتجد النتائج حتى بدون التشكيل.';

  @override
  String get featureStatsTitle => 'إحصائيات التعلّم';

  @override
  String get featureStatsBody =>
      'تتبّع سلسلتك 🔥 وأيامك النشطة وخريطة نشاط حرارية لآخر 16 أسبوعًا.';

  @override
  String get featureReviewTitle => 'المراجعات';

  @override
  String get featureReviewBody =>
      'تُعرض عليك الكلمات المستحقة وفق أسلوب التكرار المتباعد SM-2 — لبناء مفردات دائمة.';

  @override
  String get featureOfflineTitle => 'دون إنترنت وبالمجان';

  @override
  String get featureOfflineBody =>
      'كل شيء يعمل دون إنترنت، ويبقى تقدّمك على جهازك — والتطبيق مجاني تمامًا.';

  @override
  String get devNoteTitle => 'جُمْلَة قيد التطوير النشط';

  @override
  String get devNoteBody =>
      'تأتي دروس ومستويات وميزات جديدة بانتظام — تابعنا وانمُ مع التطبيق.';

  @override
  String get supportHeading => 'ادعم التطوير';

  @override
  String get supportBody =>
      'جُمْلَة مجانية. إذا أعجبك التطبيق يمكنك دعم تطويره طوعيًا:';

  @override
  String get letsGo => 'هيَّا نبدأ';

  @override
  String get transliterationTitle => 'الكتابة الصوتية (DIN 31635)';

  @override
  String get transliterationIntro =>
      'تتبع الكتابة الصوتية العربية في هذا التطبيق معيار DIN 31635، المعيار العلمي في الدراسات العربية. وهي تُظهر بالضبط كيف يُكتب الكلام ويُلفظ — بما في ذلك أصوات لا وجود لها في الألمانية. ابتداءً من المستوى B1 لا تُعرض الكتابة الصوتية عمدًا؛ لأن المفروض أنك تقرأ الخط العربي مباشرة حينها.';

  @override
  String get lettersHeading => 'الحروف';

  @override
  String get diacriticsHeading => 'الحركات القصيرة والعلامات';

  @override
  String get tlHamza => 'همزة القطع — الصوت الحنجري قبل الحركات';

  @override
  String get tlAlef => 'ألف طويلة (ā) كما في «قال»';

  @override
  String get tlBa => 'كما في الباء';

  @override
  String get tlTa => 'كما في التاء';

  @override
  String get tlTha => 'ثاء — صوت بين السين والتاء';

  @override
  String get tlJim => 'جيم — مثل «جِيم»';

  @override
  String get tlHa => 'حاء — صوت حلقي شديد أدقّ من الهاء';

  @override
  String get tlKha => 'خاء — مثل «خ» في «بخ»';

  @override
  String get tlDal => 'دال — مثل دال البيت';

  @override
  String get tlDhal => 'ذال — صوت بين الزاي والثاء';

  @override
  String get tlRa => 'راء — راء مفخّمة ملتوية';

  @override
  String get tlZay => 'زاي — صوت «س» مجهور مثل «زاد»';

  @override
  String get tlSin => 'سين — ساكنة رقيقة';

  @override
  String get tlShin => 'شين — مثل «شمس»';

  @override
  String get tlSad => 'صاد — سين مفخّمة';

  @override
  String get tlDad => 'ضاد — دال مفخّمة';

  @override
  String get tlTaEmph => 'طاء — تاء مفخّمة';

  @override
  String get tlZa => 'ظاء — ثاء/ذال مفخّمة';

  @override
  String get tlAyn => 'عين — صوت حنجري مجهور لا مقابل له في اللاتينية (ʿAin)';

  @override
  String get tlGhayn => 'غين — كالراء الفرنسية (احتكاك في الحلق)';

  @override
  String get tlFa => 'فاء — مثل «فرح»';

  @override
  String get tlQaf => 'قاف — كالكاف لكن عميقًا في الحلق';

  @override
  String get tlKaf => 'كاف — كالكاف في «كتاب»';

  @override
  String get tlLam => 'لام — كما في «ليلة»';

  @override
  String get tlMim => 'ميم — كما في «ماء»';

  @override
  String get tlNun => 'نون — كما في «نور»';

  @override
  String get tlHeh => 'هاء — كالهاء في «هواء»';

  @override
  String get tlWaw => 'واو — شبه حركة «و» أو «ū» طويلة';

  @override
  String get tlYa => 'ياء — شبه حركة «ي» أو «ī» طويلة';

  @override
  String get tlTaMarbuta =>
      'تاء مربوطة: «a» في نهاية الكلمة، وقبل كلمة لاحقة غالبًا «-at»';

  @override
  String get tlAlifMaqsura => 'ألف مقصورة: «ā» طويلة في نهاية الكلمة';

  @override
  String get tdFatha => 'فتحة — «a» قصيرة';

  @override
  String get tdKasra => 'كسرة — «i» قصيرة';

  @override
  String get tdDamma => 'ضمة — «u» قصيرة';

  @override
  String get tdSukun => 'سكون — الحرف الساكن لا يحمل حركة';

  @override
  String get tdShadda => 'شدة — يُنطق الحرف مشدّدًا (مضاعفًا)';

  @override
  String get tdSukunSymbol => '(ساكن)';

  @override
  String get tdShaddaSymbol => '(تضعيف)';
}
