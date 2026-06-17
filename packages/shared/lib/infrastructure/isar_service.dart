// packages/shared/lib/infrastructure/isar_service.dart
//
// خدمة قاعدة البيانات المحلية — Isar
// تُهيَّأ مرة واحدة عند تشغيل التطبيق وتُستخدم كـ Singleton

import 'dart:developer' as developer;

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/data/models/chat_model.dart';
import 'package:shared/data/models/food_model.dart';
import 'package:shared/data/models/health_model.dart';
import 'package:shared/data/models/meal_model.dart';
import 'package:shared/data/models/subscription_model.dart';
import 'package:shared/data/models/user_model.dart';
import 'package:shared/data/models/video_model.dart';
import 'package:shared/data/models/workout_model.dart';

part 'isar_service.g.dart';

/// خدمة Isar المركزية
///
/// توفر وصولاً آمناً لقاعدة البيانات المحلية
/// تُفتح مرة واحدة فقط ثم تُعاد استخدامها (Singleton pattern)
class IsarService {
  IsarService._(this._isar);

  final Isar _isar;

  /// فتح قاعدة البيانات — يُستدعى مرة واحدة عند Bootstrap
  static Future<IsarService> open() async {
    final dir = await getApplicationDocumentsDirectory();

    final isar = await Isar.open(
      [
        // ── User ──────────────────────────────────────────
        UserModelSchema,

        // ── Workout ───────────────────────────────────────
        WorkoutLogModelSchema,
        ExerciseModelSchema,

        // ── Nutrition ─────────────────────────────────────
        FoodItemModelSchema,
        MealEntryModelSchema,

        // ── Health ────────────────────────────────────────
        StepsModelSchema,
        SleepModelSchema,
        MeasurementModelSchema,

        // ── Chat ──────────────────────────────────────────
        ChatMessageModelSchema,
        ConversationModelSchema,

        // ── Subscription ──────────────────────────────────
        SubscriptionRequestModelSchema,

        // ── Video ─────────────────────────────────────────
        VideoMetadataModelSchema,
      ],
      directory: dir.path,
      name:      'tobest_db',
    );

    developer.log('Isar database opened at: ${dir.path}', name: 'IsarService');
    return IsarService._(isar);
  }

  /// الوصول المباشر لـ Isar (للـ Repositories)
  Isar get db => _isar;

  // ── عمليات الـ User ───────────────────────────────────────

  Future<UserModel?> getCurrentUser() =>
      _isar.userModels.where().findFirst();

  Future<void> saveUser(UserModel user) =>
      _isar.writeTxn(() => _isar.userModels.put(user));

  Future<void> clearUser() =>
      _isar.writeTxn(() => _isar.userModels.clear());

  // ── عمليات Workout ────────────────────────────────────────

  Future<List<WorkoutLogModel>> getWorkoutHistory({
    required String userId,
    required String exerciseId,
    int limit = 30,
  }) =>
      _isar.workoutLogModels
          .filter()
          .userIdEqualTo(userId)
          .exerciseIdEqualTo(exerciseId)
          .sortByDateDesc()
          .limit(limit)
          .findAll();

  Future<void> saveWorkoutLog(WorkoutLogModel log) =>
      _isar.writeTxn(() => _isar.workoutLogModels.put(log));

  // ── عمليات Food ───────────────────────────────────────────

  Future<int> getFoodCount() => _isar.foodItemModels.count();

  Future<void> seedFoods(List<FoodItemModel> foods) =>
      _isar.writeTxn(() => _isar.foodItemModels.putAll(foods));

  Future<List<FoodItemModel>> searchFoods(String query, {int limit = 20}) =>
      _isar.foodItemModels
          .filter()
          .nameContains(query, caseSensitive: false)
          .limit(limit)
          .findAll();

  // ── عمليات الشات ──────────────────────────────────────────

  Future<List<ChatMessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
  }) =>
      _isar.chatMessageModels
          .filter()
          .conversationIdEqualTo(conversationId)
          .sortBySentAtDesc()
          .limit(limit)
          .findAll();

  Future<void> saveMessages(List<ChatMessageModel> messages) =>
      _isar.writeTxn(() => _isar.chatMessageModels.putAll(messages));

  // ── عمليات Health ─────────────────────────────────────────

  Future<void> saveSteps(StepsModel steps) =>
      _isar.writeTxn(() => _isar.stepsModels.put(steps));

  Future<void> saveSleep(SleepModel sleep) =>
      _isar.writeTxn(() => _isar.sleepModels.put(sleep));

  Future<void> saveMeasurement(MeasurementModel m) =>
      _isar.writeTxn(() => _isar.measurementModels.put(m));

  // ── Weekly Cleanup ────────────────────────────────────────

  /// تنظيف أسبوعي — يُستدعى فقط بعد نجاح الـ Sync
  ///
  /// يحذف البيانات القديمة بترتيب آمن:
  /// Step 1: Sync أولاً → Step 2: Cleanup → Step 3: Sync مرة أخرى
  Future<void> clearForWeeklyCleanup() async {
    developer.log('Starting weekly cleanup...', name: 'IsarService');
    await _isar.writeTxn(() async {
      await _isar.workoutLogModels.clear();
      await _isar.mealEntryModels.clear();
      await _isar.stepsModels.clear();
      await _isar.sleepModels.clear();
      await _isar.chatMessageModels.clear();
    });
    developer.log('Weekly cleanup completed', name: 'IsarService');
  }

  /// إغلاق قاعدة البيانات
  Future<void> close() => _isar.close();
}

/// مزود IsarService للـ Riverpod
@riverpod
Future<IsarService> isarService(IsarServiceRef ref) async {
  final service = await IsarService.open();

  // إغلاق عند dispose
  ref.onDispose(service.close);

  return service;
}
