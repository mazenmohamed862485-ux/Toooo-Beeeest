// packages/shared/lib/shared.dart
//
// المصدر الرئيسي للحزمة المشتركة
// يصدّر جميع الأجزاء العامة بمسار واحد

// ── Config ────────────────────────────────────────────────────
export 'config/app_config.dart';
// ملاحظة: secrets.dart مستثنى عمداً — لا يُصدَّر لمنع الكشف

// ── Domain Entities ───────────────────────────────────────────
export 'domain/entities/user_entity.dart';
export 'domain/entities/workout_entity.dart';
export 'domain/entities/nutrition_entity.dart';
export 'domain/entities/chat_entity.dart';
export 'domain/entities/health_entity.dart';
export 'domain/entities/subscription_entity.dart';
export 'domain/entities/video_entity.dart';

// ── Domain Repositories ───────────────────────────────────────
export 'domain/repositories/auth_repository.dart';
export 'domain/repositories/workout_repository.dart';

// ── Infrastructure ────────────────────────────────────────────
export 'infrastructure/gas_client.dart';
export 'infrastructure/isar_service.dart';
export 'infrastructure/video_service.dart';
export 'infrastructure/video_service_drive.dart';
export 'infrastructure/notification_service.dart';
export 'infrastructure/polling_service.dart';
export 'infrastructure/background_service.dart';
export 'infrastructure/sync_service.dart';

// ── Data Models ───────────────────────────────────────────────
export 'data/models/user_model.dart';
export 'data/models/workout_model.dart';
export 'data/models/food_model.dart';
export 'data/models/meal_model.dart';
export 'data/models/health_model.dart';
export 'data/models/chat_model.dart';
export 'data/models/subscription_model.dart';
export 'data/models/video_model.dart';

// ── Design System ─────────────────────────────────────────────
export 'design/tokens.dart';
export 'design/themes.dart';
export 'design/widgets/breathing_animation.dart';

// ── Utils ─────────────────────────────────────────────────────
export 'utils/evaluator.dart';
export 'utils/validators.dart';
export 'utils/extensions.dart';
