// packages/shared/lib/infrastructure/video_service_drive.dart
//
// تطبيق VideoService عبر Google Drive
//
// ⚠️ ملاحظة معمارية مهمة:
// Google Drive لا يدعم HTTP Range Requests بشكل كامل.
// هذا يعني أن Seeking (التنقل) داخل الفيديو قد يكون محدوداً أو بطيئاً.
// الـ video_player سيحتاج لإعادة تحميل الفيديو من البداية عند كل Seek.
// عند التبديل لـ Cloudflare Stream أو Bunny.net، يُحل هذا القيد تلقائياً.

import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/config/app_config.dart';
import 'package:shared/domain/entities/video_entity.dart';
import 'package:shared/infrastructure/gas_client.dart';
import 'package:shared/infrastructure/video_service.dart';

part 'video_service_drive.g.dart';

/// تطبيق VideoService باستخدام Google Drive عبر GAS كـ Proxy
///
/// التدفق: Flutter → GAS → Google Drive
/// التطبيق لا يتعامل مع Drive مباشرة أبداً — GAS هو الوسيط الوحيد
class VideoServiceDrive implements VideoService {
  VideoServiceDrive({
    required GasClient gasClient,
    required String cacheDir,
  })  : _gas   = gasClient,
        _cache  = <String, String>{},
        _cacheDir = cacheDir;

  final GasClient _gas;
  final Map<String, String> _cache;   // videoId → localPath
  final String _cacheDir;

  @override
  Future<List<VideoMetadata>> getVideosForExercise(String exerciseId) async {
    try {
      final response = await _gas.get<Map<String, dynamic>>(
        '/video/exercise/$exerciseId',
      );
      final data = response.data?['videos'] as List<dynamic>? ?? [];
      return data.map((v) => _parseMetadata(v as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      developer.log('Failed to get videos for $exerciseId: $e', name: 'VideoServiceDrive');
      return [];
    }
  }

  @override
  Future<String> getStreamUrl(String videoId) async {
    // التحقق من Cache أولاً
    if (_cache.containsKey(videoId)) {
      final localPath = _cache[videoId]!;
      if (File(localPath).existsSync()) return localPath;
      _cache.remove(videoId);
    }

    // طلب Streaming URL من GAS
    final response = await _gas.get<Map<String, dynamic>>(
      '/video/stream/$videoId',
    );
    final url = response.data?['streamUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Empty stream URL for video $videoId');
    }

    // ⚠️ لا نُعيد الـ URL للـ UI — نمرره مباشرة لـ video_player
    return url;
  }

  @override
  Future<void> prefetchVideo(String videoId) async {
    if (await isVideoCached(videoId)) return;

    // فحص حجم الـ Cache قبل التحميل
    final cacheSize = await getVideoCacheSizeBytes();
    if (cacheSize >= AppConfig.videoCacheMaxBytes) {
      await _evictLRU();
    }

    try {
      final streamUrl = await getStreamUrl(videoId);
      final localPath = '$_cacheDir/$videoId.mp4';

      await Dio().download(
        streamUrl,
        localPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            developer.log(
              'Prefetch $videoId: ${(received / total * 100).toInt()}%',
              name: 'VideoServiceDrive',
            );
          }
        },
      );

      _cache[videoId] = localPath;
      developer.log('Video $videoId cached at $localPath', name: 'VideoServiceDrive');
    } catch (e) {
      developer.log('Prefetch failed for $videoId: $e', name: 'VideoServiceDrive');
    }
  }

  @override
  Future<bool> isVideoCached(String videoId) async {
    if (_cache.containsKey(videoId)) {
      return File(_cache[videoId]!).existsSync();
    }
    final localPath = '$_cacheDir/$videoId.mp4';
    if (File(localPath).existsSync()) {
      _cache[videoId] = localPath;
      return true;
    }
    return false;
  }

  @override
  Future<void> clearVideoCache() async {
    final dir = Directory(_cacheDir);
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.mp4')) {
          entity.deleteSync();
        }
      }
    }
    _cache.clear();
    developer.log('Video cache cleared', name: 'VideoServiceDrive');
  }

  @override
  Future<int> getVideoCacheSizeBytes() async {
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) return 0;
    int total = 0;
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.mp4')) {
        total += entity.lengthSync();
      }
    }
    return total;
  }

  /// LRU Eviction — حذف أقدم ملفات الفيديو
  Future<void> _evictLRU() async {
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp4'))
        .toList()
      ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

    // احذف أقدم 20% من الـ Cache
    final toDelete = (files.length * 0.2).ceil();
    for (int i = 0; i < toDelete && i < files.length; i++) {
      final videoId = files[i].path.split('/').last.replaceAll('.mp4', '');
      files[i].deleteSync();
      _cache.remove(videoId);
      developer.log('LRU evicted: $videoId', name: 'VideoServiceDrive');
    }
  }

  VideoMetadata _parseMetadata(Map<String, dynamic> data) {
    return VideoMetadata(
      id:              data['id'] as String? ?? '',
      exerciseId:      data['exerciseId'] as String? ?? '',
      title:           data['title'] as String? ?? '',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      order:           (data['order'] as num?)?.toInt() ?? 0,
      thumbnailUrl:    data['thumbnailUrl'] as String?,
    );
  }
}

/// مزود VideoService للـ Riverpod
@riverpod
Future<VideoService> videoService(Ref ref) async {
  final gasClient = await ref.watch(gasClientProvider.future);
  final cacheDir = await _getVideoCacheDir();

  return VideoServiceDrive(
    gasClient: gasClient,
    cacheDir:  cacheDir,
  );
}

Future<String> _getVideoCacheDir() async {
  final dir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory('${dir.path}/video_cache');
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
  return cacheDir.path;
}
