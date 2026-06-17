// apps/tobest/lib/main.dart
//
// نقطة دخول تطبيق TO Best
// يتحقق من دور المستخدم — USER / COACH فقط

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/infrastructure/background_service.dart';
import 'package:tobest/app.dart';

/// نقطة البداية — تهيئة الخدمات الأساسية قبل runApp
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعدادات الشاشة
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // تهيئة Background Service
  await BackgroundService.initialize();

  // تشغيل التطبيق مع Riverpod
  runApp(
    const ProviderScope(
      child: ToBestApp(),
    ),
  );
}
