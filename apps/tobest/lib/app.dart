// apps/tobest/lib/app.dart
//
// جذر التطبيق — Router + Theme + Localization

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/config/app_config.dart';
import 'package:shared/design/themes.dart';
import 'package:tobest/router.dart';

/// جذر تطبيق TO Best
class ToBestApp extends ConsumerWidget {
  const ToBestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مراقبة إعدادات المستخدم (ثيم + لغة)
    final themeKey = ref.watch(userThemeProvider);
    final locale   = ref.watch(userLocaleProvider);
    final router   = ref.watch(routerProvider);

    return MaterialApp.router(
      title:          AppConfig.toBestName,
      debugShowCheckedModeBanner: false,

      // ── Themes ────────────────────────────────────────────
      theme:      _buildTheme(themeKey, Brightness.light),
      darkTheme:  _buildTheme(themeKey, Brightness.dark),
      themeMode:  getThemeMode(themeKey),

      // ── Router ────────────────────────────────────────────
      routerConfig: router,

      // ── Localization ──────────────────────────────────────
      locale: locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ── RTL/LTR بناءً على اللغة ───────────────────────────
      builder: (context, child) {
        return Directionality(
          textDirection: locale?.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },
    );
  }

  ThemeData _buildTheme(String themeKey, Brightness brightness) {
    return switch (themeKey) {
      'blue'  => buildBlueTheme(),
      'pink'  => buildPinkTheme(),
      'light' => buildLightTheme(),
      'dark'  => buildDarkTheme(),
      _       => brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme(),
    };
  }
}

/// مزود الثيم الحالي للمستخدم
final userThemeProvider = StateProvider<String>((ref) => 'auto');

/// مزود اللغة الحالية
final userLocaleProvider = StateProvider<Locale?>((ref) => const Locale('ar'));
