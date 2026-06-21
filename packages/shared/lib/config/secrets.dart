// packages/shared/lib/config/secrets.dart
//
// ⚠️  هذا الملف في .gitignore — يُملأ يدوياً قبل كل Build
// ⚠️  لا ترفع هذا الملف لأي Repository تحت أي ظرف
// ⚠️  MANAGER يعدّله من شاشة الإعدادات في التطبيق
//
// طريقة الاستخدام:
//   1. انسخ هذا الملف من مثال secrets.dart.example
//   2. أدخل القيم الحقيقية
//   3. لا تلمس .gitignore — secrets.dart مُدرج دائماً

/// أسرار التطبيق — قيم حساسة لا تُرفع على GitHub
class AppSecrets {
  AppSecrets._();

  /// رابط Google Apps Script الأساسي
  static const String gasBaseUrl = 'https://script.google.com/macros/s/AKfycbyStz-EIhRptXAbduoJPkhyh5scnWHhO2Tw9PDC6RdKkRq2LUNb5CrAaXhvRXXN1V13/exec';

  /// مفتاح التوثيق بين Flutter وGAS
  static const String gasSecretKey = 'Mazen124261';

  /// مفتاح Gemini API للذكاء الاصطناعي
  static const String geminiApiKey = 'REPLACE_WITH_GEMINI_KEY';
}

