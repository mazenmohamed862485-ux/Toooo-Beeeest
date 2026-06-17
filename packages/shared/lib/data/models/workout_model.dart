// packages/shared/lib/data/models/workout_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/workout_entity.dart';

part 'workout_model.g.dart';

/// Isar Schema لسجل تمرين (SetRecord مُسطَّح)
@Collection()
class WorkoutLogModel {
  Id get isarId => Isar.autoIncrement;

  @Index()
  late String id;

  @Index()
  late String userId;

  @Index()
  late String exerciseId;

  late String exerciseName;

  @Index()
  late DateTime date;

  late String? sessionType;
  late String? evaluation;
  late String? notes;
  late DateTime? updatedAt;

  // Sets مُسطَّحة كـ Lists (Isar لا يدعم Embedded Objects مباشرة)
  late List<double> setWeights;
  late List<int>    setReps;
  late List<int?>   setRpe;
  late List<int?>   setRir;

  List<SetRecord> get sets {
    final length = setWeights.length;
    return List.generate(length, (i) => SetRecord(
      weight: setWeights[i],
      reps:   setReps[i],
      rpe:    setRpe.length > i ? setRpe[i] : null,
      rir:    setRir.length > i ? setRir[i] : null,
    ));
  }

  WorkoutLogEntry toEntity() => WorkoutLogEntry(
        id:           id,
        userId:       userId,
        exerciseId:   exerciseId,
        exerciseName: exerciseName,
        date:         date,
        sets:         sets,
        sessionType:  sessionType,
        evaluation:   evaluation,
        notes:        notes,
        updatedAt:    updatedAt,
      );

  static WorkoutLogModel fromEntity(WorkoutLogEntry e) => WorkoutLogModel()
    ..id           = e.id
    ..userId       = e.userId
    ..exerciseId   = e.exerciseId
    ..exerciseName = e.exerciseName
    ..date         = e.date
    ..sessionType  = e.sessionType
    ..evaluation   = e.evaluation
    ..notes        = e.notes
    ..updatedAt    = e.updatedAt
    ..setWeights   = e.sets.map((s) => s.weight).toList()
    ..setReps      = e.sets.map((s) => s.reps).toList()
    ..setRpe       = e.sets.map((s) => s.rpe).toList()
    ..setRir       = e.sets.map((s) => s.rir).toList();
}

/// Isar Schema لبيانات التمرين
@Collection()
class ExerciseModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String name;
  late String muscle;

  @Index()
  late String sessionType;

  late bool isPrimary;
  String? alt1;
  String? alt2;
  String? note;
  String? warmupSets;
  int? targetSets;
  String? repRange;
  String? restRange;
  late List<String> videoIds;

  ExerciseEntity toEntity() => ExerciseEntity(
        id:          id,
        name:        name,
        muscle:      muscle,
        sessionType: sessionType,
        isPrimary:   isPrimary,
        alt1:        alt1,
        alt2:        alt2,
        note:        note,
        warmupSets:  warmupSets,
        targetSets:  targetSets,
        repRange:    repRange,
        restRange:   restRange,
        videoIds:    videoIds,
      );
}
