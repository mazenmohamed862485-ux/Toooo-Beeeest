// packages/shared/lib/data/models/food_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/nutrition_entity.dart';

part 'food_model.g.dart';

/// Isar Schema لعنصر غذائي
///
/// تُزرع هذه البيانات من foodDB.js + foodDB_extended.js
/// عند أول تشغيل للتطبيق
@Collection()
class FoodItemModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String name;

  late double calories;
  late double protein;
  late double carbs;
  late double fat;
  late double fiber;
  late double amount;
  late String unit;
  late List<String> aliases;
  double? cost;

  FoodItem toEntity() => FoodItem(
        id:       id,
        name:     name,
        calories: calories,
        protein:  protein,
        carbs:    carbs,
        fat:      fat,
        fiber:    fiber,
        amount:   amount,
        unit:     unit,
        aliases:  aliases,
        cost:     cost,
      );

  static FoodItemModel fromMap(Map<String, dynamic> map) => FoodItemModel()
    ..id       = map['id']   as String? ?? map['name'] as String
    ..name     = map['name'] as String
    ..calories = (map['cal']  as num?)?.toDouble() ?? 0
    ..protein  = (map['pro']  as num?)?.toDouble() ?? 0
    ..carbs    = (map['carb'] as num?)?.toDouble() ?? 0
    ..fat      = (map['fat']  as num?)?.toDouble() ?? 0
    ..fiber    = (map['fib']  as num?)?.toDouble() ?? 0
    ..amount   = (map['amt']  as num?)?.toDouble() ?? 100
    ..unit     = map['unit'] as String? ?? 'g'
    ..aliases  = List<String>.from(map['aliases'] as List<dynamic>? ?? [])
    ..cost     = (map['cost'] as num?)?.toDouble();
}
