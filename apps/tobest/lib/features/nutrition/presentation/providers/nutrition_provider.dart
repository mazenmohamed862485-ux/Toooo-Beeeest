// apps/tobest/lib/features/nutrition/presentation/providers/nutrition_provider.dart

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/domain/entities/nutrition_entity.dart';
import 'package:shared/infrastructure/gas_client.dart';
import 'package:shared/data/models/meal_model.dart';
import 'package:shared/infrastructure/isar_service.dart';
import 'package:tobest/features/auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

part 'nutrition_provider.g.dart';

/// ملخص ماكرو اليوم للـ HomeScreen
class MacroSummary {
  const MacroSummary({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.totalFiber,
  });
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double totalFiber;
}

/// وجبات اليوم
@riverpod
Future<List<MealEntry>> todayMeals(Ref ref) async {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return [];

  final isar  = await ref.watch(isarServiceProvider.future);
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final end   = start.add(const Duration(days: 1));

  final records = await isar.db.mealEntryModels
      .filter()
      .userIdEqualTo(userId)
      .dateBetween(start, end)
      .findAll();

  return records.map((r) => r.toEntity()).toList();
}

/// ملخص الماكرو لليوم
@riverpod
Future<MacroSummary?> todayMacroSummary(Ref ref) async {
  final meals = await ref.watch(todayMealsProvider.future);
  if (meals.isEmpty) return null;

  return MacroSummary(
    totalCalories: meals.fold(0, (s, m) => s + m.totalCalories),
    totalProtein:  meals.fold(0, (s, m) => s + m.totalProtein),
    totalCarbs:    meals.fold(0, (s, m) => s + m.totalCarbs),
    totalFat:      meals.fold(0, (s, m) => s + m.totalFat),
    totalFiber:    meals.fold(0, (s, m) => s + m.totalFiber),
  );
}

/// الهدف الغذائي اليومي
@riverpod
Future<MacroResult?> dailyMacroGoal(Ref ref) async {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return null;

  try {
    final gas = await ref.read(gasClientProvider.future);
    final resp = await gas.get<Map<String, dynamic>>(
      '/nutrition/goal/$userId',
    );
    final data = resp.data;
    if (data == null) return null;

    return MacroResult(
      calories: data['calories'] as int? ?? 2000,
      protein:  data['protein']  as int? ?? 150,
      carbs:    data['carbs']    as int? ?? 200,
      fat:      data['fat']      as int? ?? 65,
      fiber:    data['fiber']    as int? ?? 25,
    );
  } catch (_) {
    return null;
  }
}

/// إجراءات التغذية (حفظ، حذف، إضافة)
@riverpod
class NutritionActions extends _$NutritionActions {
  @override
  void build() {}

  /// حذف وجبة
  Future<void> deleteMeal(String mealId) async {
    try {
      final isar = await ref.read(isarServiceProvider.future);
      await isar.db.writeTxn(
        () => isar.db.mealEntryModels.filter().idEqualTo(mealId).deleteAll(),
      );
      ref.invalidate(todayMealsProvider);
    } catch (e) {
      developer.log('Delete meal failed: $e', name: 'NutritionActions');
    }
  }

  /// حفظ وجبة من نتيجة التحليل
  Future<void> saveParsedMeal(MealParseResult result) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;

    try {
      final isar  = await ref.read(isarServiceProvider.future);
      final gas   = await ref.read(gasClientProvider.future);
      final now   = DateTime.now();
      final entry = _buildMealEntry(userId, 'custom', result, now);

      await isar.db.writeTxn(
        () => isar.db.mealEntryModels.put(_toModel(entry)),
      );

      // مزامنة مع GAS
      try {
        await gas.post('/nutrition/meal', data: _entryToJson(entry));
      } catch (e) {
        developer.log('GAS sync deferred: $e', name: 'NutritionActions');
      }

      ref.invalidate(todayMealsProvider);
    } catch (e) {
      developer.log('Save meal failed: $e', name: 'NutritionActions');
    }
  }

  /// إضافة غذاء مقترح
  Future<void> addSuggestedFood(FoodItem food) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;

    final result = MealParseResult(
      totalCalories: food.calories,
      totalProtein:  food.protein,
      totalCarbs:    food.carbs,
      totalFat:      food.fat,
      totalFiber:    food.fiber,
      items: [
        MealFoodItem(
          foodId:   food.id,
          foodName: food.name,
          amount:   food.amount,
          calories: food.calories,
          protein:  food.protein,
          carbs:    food.carbs,
          fat:      food.fat,
          fiber:    food.fiber,
        )
      ],
      unmatched: const [],
    );

    await saveParsedMeal(result);
  }

  MealEntry _buildMealEntry(
    String userId,
    String mealType,
    MealParseResult result,
    DateTime date,
  ) =>
      MealEntry(
        id:            const Uuid().v4(),
        userId:        userId,
        date:          date,
        mealType:      mealType,
        items:         result.items,
        totalCalories: result.totalCalories,
        totalProtein:  result.totalProtein,
        totalCarbs:    result.totalCarbs,
        totalFat:      result.totalFat,
        totalFiber:    result.totalFiber,
        updatedAt:     date,
      );

  dynamic _toModel(MealEntry entry) {
    // التحويل إلى MealEntryModel (تُنفَّذ عند توفر الـ Generator)
    return entry;
  }

  Map<String, dynamic> _entryToJson(MealEntry entry) => {
    'id':           entry.id,
    'userId':       entry.userId,
    'date':         entry.date.toIso8601String(),
    'mealType':     entry.mealType,
    'totalCalories': entry.totalCalories,
    'totalProtein':  entry.totalProtein,
    'totalCarbs':    entry.totalCarbs,
    'totalFat':      entry.totalFat,
    'totalFiber':    entry.totalFiber,
    'updatedAt':     entry.updatedAt?.toIso8601String(),
    'items': entry.items.map((i) => {
      'foodId':   i.foodId,
      'foodName': i.foodName,
      'amount':   i.amount,
      'calories': i.calories,
      'protein':  i.protein,
      'carbs':    i.carbs,
      'fat':      i.fat,
    }).toList(),
  };
}
