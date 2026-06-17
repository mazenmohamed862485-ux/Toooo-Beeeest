// packages/shared/lib/data/models/meal_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/nutrition_entity.dart';

part 'meal_model.g.dart';

@Collection()
class MealEntryModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String userId;

  @Index()
  late DateTime date;

  late String mealType;
  late double totalCalories;
  late double totalProtein;
  late double totalCarbs;
  late double totalFat;
  late double totalFiber;
  late DateTime? updatedAt;

  // Items مُسطَّحة
  late List<String> itemFoodIds;
  late List<String> itemFoodNames;
  late List<double> itemAmounts;
  late List<double> itemCalories;
  late List<double> itemProtein;
  late List<double> itemCarbs;
  late List<double> itemFat;

  MealEntry toEntity() {
    final items = List.generate(
      itemFoodIds.length,
      (i) => MealFoodItem(
        foodId:   itemFoodIds[i],
        foodName: itemFoodNames[i],
        amount:   itemAmounts[i],
        calories: itemCalories[i],
        protein:  itemProtein[i],
        carbs:    itemCarbs[i],
        fat:      itemFat[i],
      ),
    );

    return MealEntry(
      id:             id,
      userId:         userId,
      date:           date,
      mealType:       mealType,
      items:          items,
      totalCalories:  totalCalories,
      totalProtein:   totalProtein,
      totalCarbs:     totalCarbs,
      totalFat:       totalFat,
      totalFiber:     totalFiber,
      updatedAt:      updatedAt,
    );
  }
}
