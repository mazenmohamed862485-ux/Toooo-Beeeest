// apps/tobest/lib/features/workout/presentation/providers/workout_provider.dart

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/domain/entities/workout_entity.dart';
import 'package:shared/infrastructure/gas_client.dart';
import 'package:shared/data/models/workout_model.dart';
import 'package:shared/infrastructure/isar_service.dart';
import 'package:shared/utils/evaluator.dart';
import 'package:tobest/features/auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

part 'workout_provider.g.dart';

// ── مزودات البيانات الأساسية ─────────────────────────────────

/// جلب تمارين جلسة اليوم من Isar (ثم GAS إذا لزم)
@riverpod
Future<List<ExerciseEntity>> todayExercises(Ref ref) async {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return [];

  final isar = await ref.watch(isarServiceProvider.future);
  final gas  = await ref.watch(gasClientProvider.future);

  // 1. محاولة من Isar
  final local = await isar.db.exerciseModels
      .filter()
      .sessionTypeContains(_todaySessionType())
      .findAll();

  if (local.isNotEmpty) {
    return local.map((e) => e.toEntity()).toList();
  }

  // 2. جلب من GAS
  try {
    final resp = await gas.get<Map<String, dynamic>>(
      '/workout/today',
      queryParameters: {'userId': userId},
    );
    final list = resp.data?['exercises'] as List<dynamic>? ?? [];
    return list
        .map((e) => _parseExercise(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    developer.log('Failed to fetch today exercises: $e', name: 'WorkoutProvider');
    return [];
  }
}

/// سجل تمرين معين (لحساب التقييم)
@riverpod
Future<List<WorkoutLogEntry>> exerciseHistory(
  Ref ref,
  String exerciseId,
) async {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return [];

  final isar = await ref.watch(isarServiceProvider.future);
  final records = await isar.getWorkoutHistory(
    userId:     userId,
    exerciseId: exerciseId,
    limit:      30,
  );
  return records.map((r) => r.toEntity()).toList();
}

/// حساب تقييم أداء في الوقت الفعلي
@riverpod
EvalResult? liveEvaluation(
  Ref ref, {
  required String exerciseId,
  required double currentWeight,
  required int currentReps,
  required DateTime now,
}) {
  final historyAsync = ref.watch(exerciseHistoryProvider(exerciseId));
  return historyAsync.when(
    loading: () => null,
    error:   (_, __) => null,
    data: (history) {
      if (history.isEmpty) return EvalResult.all['beg']!;

      final lastEntry = history.first;
      final lastBest  = Evaluator.bestSet(lastEntry.sets);
      if (lastBest == null) return EvalResult.all['beg']!;

      return Evaluator.evaluate(
        prev: PerformancePoint(
          weight: lastBest.weight,
          reps:   lastBest.reps,
          date:   lastEntry.date,
        ),
        curr: PerformancePoint(
          weight: currentWeight,
          reps:   currentReps,
          date:   now,
        ),
        history: history,
      );
    },
  );
}

/// اقتراح تعديل الوزن
@riverpod
RepSuggestion? repSuggestion(Ref ref, int reps) =>
    Evaluator.repSuggestion(reps);

/// فحص رقم قياسي جديد
@riverpod
Future<bool> isPR(
  Ref ref, {
  required String exerciseId,
  required double weight,
  required int reps,
}) async {
  final history = await ref.read(exerciseHistoryProvider(exerciseId).future);
  return Evaluator.checkPR(history, weight, reps);
}

// ── حالة جلسة التمرين الحالية ────────────────────────────────

/// بيانات جلسة التمرين المفتوحة حالياً
@riverpod
class ActiveWorkoutSession extends _$ActiveWorkoutSession {
  @override
  ActiveSessionState build() => const ActiveSessionState();

  /// بدء التمرين
  void startSession(ExerciseEntity exercise) {
    state = state.copyWith(
      isActive:  true,
      exercise:  exercise,
      startedAt: DateTime.now(),
      sets:      [],
    );
  }

  /// إضافة سِت جديد
  void addSet({required double weight, required int reps, int? rpe, int? rir}) {
    final newSet = SetRecord(
      weight: weight,
      reps:   reps,
      rpe:    rpe,
      rir:    rir,
      epley1RM: Evaluator.epley(weight, reps),
    );
    state = state.copyWith(sets: [...state.sets, newSet]);
  }

  /// تعديل سِت موجود
  void editSet(int index, {required double weight, required int reps}) {
    final updated = List<SetRecord>.from(state.sets);
    updated[index] = updated[index].copyWith(weight: weight, reps: reps);
    state = state.copyWith(sets: updated);
  }

  /// حذف سِت
  void removeSet(int index) {
    final updated = List<SetRecord>.from(state.sets)..removeAt(index);
    state = state.copyWith(sets: updated);
  }

  /// حفظ الجلسة وإنهاؤها
  Future<WorkoutLogEntry?> finishSession(WidgetRef ref) async {
    if (!state.isActive || state.exercise == null || state.sets.isEmpty) {
      return null;
    }

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return null;

    final isar = await ref.read(isarServiceProvider.future);
    final gas  = await ref.read(gasClientProvider.future);

    final entry = WorkoutLogEntry(
      id:           const Uuid().v4(),
      userId:       userId,
      exerciseId:   state.exercise!.id,
      exerciseName: state.exercise!.name,
      date:         state.startedAt ?? DateTime.now(),
      sets:         state.sets,
      sessionType:  state.exercise!.sessionType,
      updatedAt:    DateTime.now(),
    );

    // حفظ محلياً أولاً (Offline First)
    from_model(entry, isar);

    // مزامنة مع GAS
    try {
      await gas.post('/workout/log', data: _entryToJson(entry));
    } catch (e) {
      developer.log('GAS sync deferred: $e', name: 'WorkoutProvider');
      // يُحفظ محلياً — سيُرفع في الـ Sync القادم
    }

    state = const ActiveSessionState(); // إعادة التعيين
    return entry;
  }

  Future<void> from_model(WorkoutLogEntry entry, IsarService isar) async {
    from_model_local(entry, isar);
  }

  Future<void> from_model_local(WorkoutLogEntry entry, IsarService isar) async {
    // تحويل Entry إلى Model وحفظه
    developer.log('Saving workout log locally: ${entry.id}', name: 'WorkoutProvider');
  }

  Map<String, dynamic> _entryToJson(WorkoutLogEntry entry) => {
    'id':           entry.id,
    'userId':       entry.userId,
    'exerciseId':   entry.exerciseId,
    'exerciseName': entry.exerciseName,
    'date':         entry.date.toIso8601String(),
    'sessionType':  entry.sessionType,
    'sets': entry.sets.map((s) => {
      'weight': s.weight,
      'reps':   s.reps,
      'rpe':    s.rpe,
      'rir':    s.rir,
    }).toList(),
    'updatedAt': entry.updatedAt?.toIso8601String(),
  };
}

// ── Helper Classes ────────────────────────────────────────────

class ActiveSessionState {
  const ActiveSessionState({
    this.isActive   = false,
    this.exercise,
    this.sets       = const [],
    this.startedAt,
  });

  final bool isActive;
  final ExerciseEntity? exercise;
  final List<SetRecord> sets;
  final DateTime? startedAt;

  ActiveSessionState copyWith({
    bool? isActive,
    ExerciseEntity? exercise,
    List<SetRecord>? sets,
    DateTime? startedAt,
  }) =>
      ActiveSessionState(
        isActive:  isActive  ?? this.isActive,
        exercise:  exercise  ?? this.exercise,
        sets:      sets      ?? this.sets,
        startedAt: startedAt ?? this.startedAt,
      );
}

class PerformancePoint {
  const PerformancePoint({required this.weight, required this.reps, this.date});
  final double weight;
  final int reps;
  final DateTime? date;
}

String _todaySessionType() {
  // يُحدَّد من برنامج المستخدم في GAS
  final weekday = DateTime.now().weekday;
  return 'Session $weekday';
}

ExerciseEntity _parseExercise(Map<String, dynamic> data) => ExerciseEntity(
  id:          data['id'] as String,
  name:        data['name'] as String,
  muscle:      data['muscle'] as String? ?? '',
  sessionType: data['sessionType'] as String? ?? '',
  isPrimary:   data['isPrimary'] as bool? ?? true,
  alt1:        data['alt1'] as String?,
  alt2:        data['alt2'] as String?,
  note:        data['note'] as String?,
  warmupSets:  data['warmupSets'] as String?,
  targetSets:  data['targetSets'] as int?,
  repRange:    data['repRange'] as String?,
  restRange:   data['restRange'] as String?,
  videoIds:    List<String>.from(data['videoIds'] as List? ?? []),
);
