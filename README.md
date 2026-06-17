# TO Best Flutter Monorepo

نظام Flutter متكامل لأكاديمية TO Best يتكون من تطبيقين وحزمة مشتركة.

---

## 🏗️ هيكل المشروع

```
tobest_monorepo/
├── apps/
│   ├── tobest/              # تطبيق المستخدمين (USER + COACH)
│   └── tobest_management/   # تطبيق الإدارة (MANAGER + SUPPORT + SUBSCRIPTIONS)
├── packages/
│   └── shared/              # الحزمة المشتركة (Domain + Data + Design + Utils)
└── .github/workflows/
    ├── ci.yml               # Analyze + Test على كل PR
    ├── cd_tobest.yml        # Build APK لـ TO Best
    └── cd_management.yml    # Build APK لـ Management
```

---

## 🚀 البدء السريع

### المتطلبات
- Flutter ≥ 3.44.0
- Dart ≥ 3.3.0
- Melos: `dart pub global activate melos`

### الإعداد
```bash
git clone <repo>
cd tobest_monorepo

# تهيئة Melos
melos bootstrap

# توليد الكود (Isar + Riverpod)
melos run generate

# إنشاء ملف الأسرار (ضروري قبل التشغيل)
cp packages/shared/lib/config/secrets.dart.example \
   packages/shared/lib/config/secrets.dart
# ثم أدخل القيم الحقيقية
```

### تشغيل التطبيق
```bash
# TO Best
cd apps/tobest
flutter run

# Management
cd apps/tobest_management
flutter run
```

---

## 🔐 إدارة الأسرار

**⚠️ مهم جداً:**

- `packages/shared/lib/config/secrets.dart` في `.gitignore` دائماً
- القيم الحقيقية تُدار من شاشة الإعدادات في تطبيق Management (MANAGER فقط)
- تُخزَّن في `FlutterSecureStorage` (مشفرة على الجهاز)
- في CI/CD تُقرأ من GitHub Secrets

### GitHub Secrets المطلوبة
| Secret | الوصف |
|--------|-------|
| `GAS_BASE_URL` | رابط Google Apps Script |
| `GAS_SECRET_KEY` | مفتاح التوثيق مع GAS |
| `GEMINI_API_KEY` | مفتاح Gemini AI |
| `ANDROID_KEYSTORE_BASE64` | Keystore لـ TO Best (Base64) |
| `KEYSTORE_STORE_PASSWORD` | كلمة سر الـ Keystore |
| `KEYSTORE_KEY_PASSWORD` | كلمة سر المفتاح |
| `KEYSTORE_KEY_ALIAS` | اسم المفتاح |
| `MANAGEMENT_KEYSTORE_BASE64` | Keystore لـ Management (Base64) |
| `MGMT_KEYSTORE_STORE_PASSWORD` | كلمة سر Keystore الإدارة |
| `MGMT_KEYSTORE_KEY_PASSWORD` | كلمة سر المفتاح |
| `MGMT_KEYSTORE_KEY_ALIAS` | اسم المفتاح |

---

## 📦 الحزمة المشتركة (shared)

```
packages/shared/lib/
├── config/           # app_config.dart + secrets.dart
├── domain/
│   ├── entities/     # UserEntity, WorkoutEntity, NutritionEntity...
│   └── repositories/ # Abstract interfaces
├── data/
│   ├── models/       # Isar schemas (@Collection)
│   └── datasources/  # Remote (GAS) + Local (Isar)
├── infrastructure/
│   ├── gas_client.dart       # HTTP client مع Retry
│   ├── isar_service.dart     # قاعدة البيانات المحلية
│   ├── video_service*.dart   # فيديو + Cache
│   ├── notification_service  # Local Notifications
│   ├── polling_service       # Adaptive Polling للشات
│   ├── background_service    # workmanager
│   └── sync_service          # Field-Level Merge مع GAS
├── design/
│   ├── tokens.dart           # ألوان + مسافات + typography
│   ├── themes.dart           # 5 ثيمات
│   └── widgets/
│       └── breathing_animation.dart  # Loading + Rest Timer
└── utils/
    ├── evaluator.dart         # ترجمة evaluator.js كاملاً
    ├── validators.dart        # فحص المدخلات
    └── extensions.dart        # Extensions مفيدة
```

---

## 🎯 ميزات TO Best

| الميزة | التفاصيل |
|--------|---------|
| التمارين | Accordion + Video Carousel + Set Logging + Rest Timer |
| التقييم | محرك evaluate() مُرجَّم من JS — s1/s2/s3/rv/gd/st/ws/dn/beg |
| التغذية | محلل نص عربي + Fuzzy Match + اقتراح وجبة + حلقات ماكرو |
| الشات | Adaptive Polling + Reply + Delete + Image + Voice |
| AI Coach | Gemini 1.5 Flash مع context المستخدم |
| الصحة | Pedometer + نوم + قياسات + Navy Method |
| التقدم | PR History + Steps Chart + Body Chart + Heatmap |
| 5 ثيمات | Auto/Light/Dark/Blue/Pink |
| Offline | Isar + Field-Level Merge + Weekly Cleanup |

## 🎯 ميزات Management

| الدور | الصلاحيات |
|------|----------|
| MANAGER | كل شيء + إعدادات الاتصال + تعيين كوتشات + إيرادات |
| SUPPORT | عرض المستخدمين + طلب تعديل اشتراك |
| SUBSCRIPTIONS | الموافقة/الرفض على طلبات الاشتراك |

---

## 🔄 CI/CD

### Triggers
```
# CI (تحليل + اختبارات)
كل PR → main أو develop

# CD TO Best
git tag v1.0.0-tobest && git push origin v1.0.0-tobest

# CD Management
git tag v1.0.0-management && git push origin v1.0.0-management
```

### Weekly Cleanup Flow
```
1. Sync Local → GAS (لا تُحذف بيانات قبل الرفع)
2. Clear Isar + Video Cache
3. Sync GAS → Local (استعادة كاملة)
```

---

## 📱 نشر التطبيق

الـ APK يُنتج كـ GitHub Release Asset تلقائياً.
الفريق يثبته مباشرة (لا متجر).

---

## ⚠️ ملاحظات تقنية

- **Google Drive Streaming**: لا يدعم HTTP Range بالكامل — Seeking محدود
- **Polling vs WebSocket**: اختيار واعٍ — GAS لا يدعم WebSocket
- **Video URL**: لا يظهر في الـ UI أبداً — يُمرَّر مباشرة لـ VideoPlayerController
- **secrets.dart**: في `.gitignore` — يُنشأ يدوياً أو من CI
