// packages/shared/lib/data/models/video_model.dart

import 'package:isar/isar.dart';
import 'package:shared/domain/entities/video_entity.dart';

part 'video_model.g.dart';

/// Isar Schema لـ metadata الفيديو
@Collection()
class VideoMetadataModel {
  Id get isarId => Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String exerciseId;

  late String title;
  late int durationSeconds;
  late int order;
  String? thumbnailUrl;
  late bool isCached;

  VideoMetadata toEntity() => VideoMetadata(
        id:              id,
        exerciseId:      exerciseId,
        title:           title,
        durationSeconds: durationSeconds,
        order:           order,
        thumbnailUrl:    thumbnailUrl,
        isCached:        isCached,
      );

  static VideoMetadataModel fromEntity(VideoMetadata e) =>
      VideoMetadataModel()
        ..id              = e.id
        ..exerciseId      = e.exerciseId
        ..title           = e.title
        ..durationSeconds = e.durationSeconds
        ..order           = e.order
        ..thumbnailUrl    = e.thumbnailUrl
        ..isCached        = e.isCached;
}
