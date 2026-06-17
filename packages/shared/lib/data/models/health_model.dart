// packages/shared/lib/data/models/health_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/health_entity.dart';

part 'health_model.g.dart';

@Collection()
class StepsModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String userId;

  @Index()
  late DateTime date;

  late int steps;
  late double userWeight;
  late double userHeightCm;
  late DateTime? updatedAt;

  StepsRecord toEntity() => StepsRecord(
        id:           id,
        userId:       userId,
        date:         date,
        steps:        steps,
        userWeight:   userWeight,
        userHeightCm: userHeightCm,
        updatedAt:    updatedAt,
      );

  static StepsModel fromEntity(StepsRecord e) => StepsModel()
    ..id           = e.id
    ..userId       = e.userId
    ..date         = e.date
    ..steps        = e.steps
    ..userWeight   = e.userWeight
    ..userHeightCm = e.userHeightCm
    ..updatedAt    = e.updatedAt;
}

@Collection()
class SleepModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String userId;

  @Index()
  late DateTime date;

  late int durationHours;
  late int durationMinutes;
  late String quality;
  late DateTime? updatedAt;

  SleepRecord toEntity() => SleepRecord(
        id:              id,
        userId:          userId,
        date:            date,
        durationHours:   durationHours,
        durationMinutes: durationMinutes,
        quality:         SleepQuality.values.firstWhere(
          (q) => q.key == quality,
          orElse: () => SleepQuality.fair,
        ),
        updatedAt: updatedAt,
      );

  static SleepModel fromEntity(SleepRecord e) => SleepModel()
    ..id              = e.id
    ..userId          = e.userId
    ..date            = e.date
    ..durationHours   = e.durationHours
    ..durationMinutes = e.durationMinutes
    ..quality         = e.quality.key
    ..updatedAt       = e.updatedAt;
}

@Collection()
class MeasurementModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String userId;

  @Index()
  late DateTime date;

  double? weight;
  double? height;
  double? chest;
  double? waist;
  double? hip;
  double? neck;
  double? bodyFatPercent;
  DateTime? updatedAt;

  BodyMeasurement toEntity() => BodyMeasurement(
        id:             id,
        userId:         userId,
        date:           date,
        weight:         weight,
        height:         height,
        chest:          chest,
        waist:          waist,
        hip:            hip,
        neck:           neck,
        bodyFatPercent: bodyFatPercent,
        updatedAt:      updatedAt,
      );

  static MeasurementModel fromEntity(BodyMeasurement e) => MeasurementModel()
    ..id             = e.id
    ..userId         = e.userId
    ..date           = e.date
    ..weight         = e.weight
    ..height         = e.height
    ..chest          = e.chest
    ..waist          = e.waist
    ..hip            = e.hip
    ..neck           = e.neck
    ..bodyFatPercent = e.bodyFatPercent
    ..updatedAt      = e.updatedAt;
}
