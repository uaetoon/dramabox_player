// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'UAETooNDrama';

  @override
  String get searchDramas => 'ابحث عن الدراما...';

  @override
  String get noResultsFound => 'لا توجد نتائج';

  @override
  String get history => 'السجل';

  @override
  String get episodes => 'الحلقات';

  @override
  String get ep => 'حلقة';

  @override
  String lastWatched(int epNum) {
    return 'آخر مشاهدة: الحلقة $epNum';
  }

  @override
  String get fetchingEpisodes => 'جارٍ تحميل الحلقات...';

  @override
  String get thisMayTake => 'قد يستغرق ذلك لحظة حسب سرعة اتصالك.';

  @override
  String get back => 'رجوع';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get videoDecryptionFailed => 'فشل فك تشفير الفيديو. حاول مرة أخرى.';

  @override
  String get keepTrack => 'تابع دراماك المفضلة';

  @override
  String get emptyHistory =>
      'سيظهر سجل مشاهدتك هنا. ابدأ بمشاهدة الدراما لتتبع مكان توقفت فيه!';

  @override
  String get sectionForYou => 'من أجلك';

  @override
  String get sectionLatest => 'الأحدث';

  @override
  String get sectionTrending => 'الأكثر رواجاً';

  @override
  String get sectionVip => 'VIP';

  @override
  String get settings => 'الإعدادات';

  @override
  String get platforms => 'المنصات';

  @override
  String get specialDubbed => 'مدبلج';

  @override
  String get specialAdult => '18+';

  @override
  String get similarOnPlatforms => 'مشابه على منصات أخرى';

  @override
  String get similarSectionHint => 'إظهار دراما مشابهة متاحة على منصات أخرى.';

  @override
  String get scanningPlatforms => 'جارٍ فحص المنصات...';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get about => 'حول التطبيق';

  @override
  String version(String version) {
    return 'الإصدار $version';
  }

  @override
  String checkingUpdates(String version) {
    return 'جارٍ التحقق من التحديثات... ($version)';
  }

  @override
  String downloadingPatch(String version) {
    return 'جارٍ تنزيل التحديث... ($version)';
  }

  @override
  String get updateReady => 'التحديث جاهز! أعد تشغيل التطبيق لتفعيله.';

  @override
  String get updateFailed => 'فشل التحديث';

  @override
  String get serverUnavailable => 'الخادم غير متاح';

  @override
  String get serverBlockedMessage =>
      'يقوم خادم API بحظر الطلبات مؤقتاً بسبب الازدحام. يرجى الانتظار قليلاً ثم حاول مرة أخرى.';

  @override
  String episodesCount(int count) {
    return '$count حلقات';
  }

  @override
  String get episodesTab => 'الحلقات';

  @override
  String get descriptionTab => 'الوصف';

  @override
  String get speedPlaying => 'تشغيل بسرعة 1.5x';

  @override
  String get subtitles => 'الترجمة';

  @override
  String get subtitleOff => 'إيقاف الترجمة';

  @override
  String get videoUrlEmpty => 'رابط الفيديو فارغ';

  @override
  String get search => 'بحث';

  @override
  String get myList => 'قائمتي';

  @override
  String get home => 'الرئيسية';

  @override
  String get watchHistory => 'سجل المشاهدة';

  @override
  String get theme => 'المظهر';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'تلقائي';

  @override
  String get searchHint => 'اكتب عنوان الدراما للبحث في جميع المزودين';

  @override
  String get emptyMyList => 'ستظهر الدراما التي تضيفها إلى قائمتك هنا';

  @override
  String get continueWatching => 'متابعة المشاهدة';

  @override
  String get play => 'تشغيل';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get download => 'تنزيل';

  @override
  String get emptyDownloads =>
      'ستظهر الحلقات التي تنزلها هنا. نزّل الحلقات من صفحة الدراما لمشاهدتها دون اتصال.';

  @override
  String get downloadPaused => 'متوقف مؤقتاً';

  @override
  String get downloadFailed => 'فشل التنزيل';

  @override
  String get downloadCompleted => 'تم التنزيل';

  @override
  String get downloadQueued => 'في قائمة الانتظار';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'استئناف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get deleteDownload => 'حذف التنزيل';

  @override
  String get deleteDownloadConfirm => 'حذف هذا التنزيل؟';

  @override
  String get downloadAllTooltip => 'تنزيل جميع الحلقات';

  @override
  String downloadsQueued(int count) {
    return 'تمت إضافة $count حلقة إلى قائمة الانتظار';
  }

  @override
  String get comingSoon => 'قريباً';

  @override
  String get episodeNotAvailable =>
      'هذه الحلقة غير متاحة بعد، حاول مرة أخرى لاحقاً';

  @override
  String get adultContent => 'محتوى الكبار';

  @override
  String get adultContentHint =>
      'إظهار منصة 18+ في شريط الرئيسية. يتطلب فتحها رمزاً.';

  @override
  String get enterCode => 'أدخل الرمز';

  @override
  String get wrongCode => 'الرمز غير صحيح. حاول مرة أخرى.';

  @override
  String get unlockAdultContent => 'فتح محتوى الكبار';

  @override
  String get lockAdultContent => 'قفل محتوى الكبار';

  @override
  String get unlocked => 'مفتوح';

  @override
  String get locked => 'مقفل';

  @override
  String get confirm => 'تأكيد';
}
