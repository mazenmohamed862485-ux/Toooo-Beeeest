// apps/tobest/lib/features/health/presentation/providers/health_provider.dart

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/domain/entities/health_entity.dart';
import 'package:shared/infrastructure/gas_client.dart';
import 'package:shared/data/models/health_model.dart';
import 'package:shared/infrastructure/isar_service.dart';
import 'package:tobest/features/auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

part 'health_provider.g.dart';

/// خطوات اليوم الحالي
@riverpod
Future<StepsRecord?> todaySteps(Ref ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.weight == null || user.height == null) return null;

  final isar  = await ref.watch(isarServiceProvider.future);
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final end   = start.add(const Duration(days: 1));

  final record = await isar.db.stepsModels
      .filter()
      .userIdEqualTo(user.id)
      .dateBetween(start, end)
      .findFirst();

  return record?.toEntity();
}

/// مزود خطوات Pedometer الحية
///
/// يستقبل تحديثات من المستشعر مباشرة
@riverpod
Stream<int> liveSteps(Ref ref) {
  return Pedometer.stepCountStream.map((event) => event.steps).handleError((e) {
    developer.log('Pedometer error: $e', name: 'HealthProvider');
    return 0;
  });
}

/// حفظ خطوات اليوم
@riverpod
class StepsActions extends _$StepsActions {
  @override
  void build() {}

  Future<void> saveSteps(int steps) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || user.weight == null || user.height == null) return;

    final isar   = await ref.read(isarServiceProvider.future);
    final gas    = await ref.read(gasClientProvider.future);
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);

    final record = StepsRecord(
      id:           const Uuid().v4(),
      userId:       user.id,
      date:         today,
      steps:        steps,
      userWeight:   user.weight!,
      userHeightCm: user.height!,
      updatedAt:    now,
    );

    // حفظ محلياً
    final model = _toModel(record);
    await isar.db.writeTxn(
      () => isar.db.stepsModels.put(model),
    );

    // مزامنة مع GAS
    try {
      await gas.post('/health/steps', data: {
        'userId':       record.userId,
        'date':         record.date.toIso8601String(),
        'steps':        record.steps,
        'distanceKm':   record.distanceKm,
        'caloriesBurned': record.caloriesBurned,
        'updatedAt':    record.updatedAt?.toIso8601String(),
      });
    } catch (e) {
      developer.log('GAS steps sync deferred: $e', name: 'HealthProvider');
    }

    ref.invalidate(todayStepsProvider);
  }

  dynamic _toModel(StepsRecord record) {
    return record;
  }
}

/// سجل خطوات آخر 7 أيام
@riverpod
Future<List<StepsRecord>> weeklySteps(Ref ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final isar = await ref.watch(isarServiceProvider.future);
  final now  = DateTime.now();
  final from = now.subtract(const Duration(days: 7));

  final records = await isar.db.stepsModels
      .filter()
      .userIdEqualTo(user.id)
      .dateGreaterThan(from)
      .findAll();

  return records.map((r) => r.toEntity()).toList();
}

/// حفظ بيانات النوم
@riverpod
class SleepActions extends _$SleepActions {
  @override
  void build() {}

  Future<void> saveSleep({
    required int hours,
    required int minutes,
    required SleepQuality quality,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final isar   = await ref.read(isarServiceProvider.future);
    final gas    = await ref.read(gasClientProvider.future);
    final now    = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);

    final record = SleepRecord(
      id:              const Uuid().v4(),
      userId:          user.id,
      date:            today,
      durationHours:   hours,
      durationMinutes: minutes,
      quality:         quality,
      updatedAt:       now,
    );

    await isar.db.writeTxn(
      () => isar.db.sleepModels.put(_toModel(record)),
    );

    try {
      await gas.post('/health/sleep', data: {
        'userId':          record.userId,
        'date':            record.date.toIso8601String(),
        'durationHours':   record.durationHours,
        'durationMinutes': record.durationMinutes,
        'quality':         record.quality.key,
        'updatedAt':       record.updatedAt?.toIso8601String(),
      });
    } catch (e) {
      developer.log('GAS sleep sync deferred: $e', name: 'HealthProvider');
    }
  }

  dynamic _toModel(SleepRecord record) => record;
}

/// حفظ القياسات الجسدية
@riverpod
class MeasurementActions extends _$MeasurementActions {
  @override
  void build() {}

  Future<void> saveMeasurement({
    required double weight,
    double? chest,
    double? waist,
    double? hip,
    double? neck,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final isar   = await ref.read(isarServiceProvider.future);
    final gas    = await ref.read(gasClientProvider.future);
    final now    = DateTime.now();

    // حساب نسبة الدهون إذا توفرت البيانات
    double? bodyFat;
    if (waist != null && neck != null && user.height != null && user.gender != null) {
      bodyFat = BodyMeasurement.calcNavyBodyFat(
        gender:   user.gender!,
        waistCm:  waist,
        neckCm:   neck,
        heightCm: user.height!,
        hipCm:    hip,
      );
    }

    final measurement = BodyMeasurement(
      id:             const Uuid().v4(),
      userId:         user.id,
      date:           now,
      weight:         weight,
      height:         user.height,
      chest:          chest,
      waist:          waist,
      hip:            hip,
      neck:           neck,
      bodyFatPercent: bodyFat,
      updatedAt:      now,
    );

    await isar.db.writeTxn(
      () => isar.db.measurementModels.put(_toModel(measurement)),
    );

    try {
      await gas.post('/health/measurement', data: {
        'userId':          measurement.userId,
        'date':            measurement.date.toIso8601String(),
        'weight':          measurement.weight,
        'height':          measurement.height,
        'chest':           measurement.chest,
        'waist':           measurement.waist,
        'hip':             measurement.hip,
        'neck':            measurement.neck,
        'bodyFatPercent':  measurement.bodyFatPercent,
        'updatedAt':       measurement.updatedAt?.toIso8601String(),
      });
    } catch (e) {
      developer.log('GAS measurement sync deferred: $e', name: 'HealthProvider');
    }
  }

  dynamic _toModel(BodyMeasurement m) => m;
}
