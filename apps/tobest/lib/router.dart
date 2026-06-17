// apps/tobest/lib/router.dart
//
// نظام التنقل الكامل لـ TO Best
// go_router مع Guards للتحقق من الأدوار

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/config/app_config.dart';
import 'package:shared/domain/entities/user_entity.dart';
import 'package:tobest/features/auth/presentation/providers/auth_provider.dart';
import 'package:tobest/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:tobest/features/auth/presentation/screens/google_completion_screen.dart';
import 'package:tobest/features/auth/presentation/screens/login_screen.dart';
import 'package:tobest/features/auth/presentation/screens/otp_screen.dart';
import 'package:tobest/features/auth/presentation/screens/register_screen.dart';
import 'package:tobest/features/auth/presentation/screens/splash_screen.dart';
import 'package:tobest/features/auth/presentation/screens/subscription_expired_screen.dart';
import 'package:tobest/features/auth/presentation/screens/subscription_pending_screen.dart';
import 'package:tobest/features/auth/presentation/screens/subscription_rejected_screen.dart';
import 'package:tobest/features/chat/presentation/screens/chat_screen.dart';
import 'package:tobest/features/chat/presentation/screens/conversations_screen.dart';
import 'package:tobest/features/home/presentation/screens/home_screen.dart';
import 'package:tobest/features/home/presentation/screens/main_shell.dart';
import 'package:tobest/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:tobest/features/progress/presentation/screens/progress_screen.dart';
import 'package:tobest/features/settings/presentation/screens/settings_screen.dart';
import 'package:tobest/features/workout/presentation/screens/workout_screen.dart';
import 'package:tobest/features/ai/presentation/screens/ai_coach_screen.dart';
import 'package:tobest/features/subscription/presentation/screens/subscription_screen.dart';

part 'router.g.dart';

/// أسماء المسارات
abstract class AppRoutes {
  static const splash              = '/';
  static const login               = '/login';
  static const register            = '/register';
  static const forgotPassword      = '/forgot-password';
  static const otp                 = '/otp';
  static const googleCompletion    = '/google-completion';
  static const subscriptionPending = '/subscription-pending';
  static const subscriptionRejected = '/subscription-rejected';
  static const subscriptionExpired = '/subscription-expired';

  // ── Main Shell ────────────────────────────────────────────
  static const home         = '/home';
  static const workout      = '/workout';
  static const nutrition    = '/nutrition';
  static const progress     = '/progress';
  static const conversations = '/conversations';
  static const chat         = '/chat/:conversationId';
  static const aiCoach      = '/ai-coach';
  static const settings     = '/settings';
  static const subscription = '/subscription';
}

/// مزود الـ Router
@riverpod
GoRouter router(Ref ref) {
  // متابعة حالة المصادقة لإعادة التوجيه
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: AppConfig.isDebug,

    redirect: (context, state) {
      final location = state.matchedLocation;
      final user     = authState.valueOrNull;

      // ── Splash لا يحتاج Redirect ─────────────────────────
      if (location == AppRoutes.splash) return null;

      // ── صفحات عامة بدون مصادقة ──────────────────────────
      final publicRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.otp,
        AppRoutes.googleCompletion,
      ];
      final isPublic = publicRoutes.contains(location);

      // غير مسجَّل → Login
      if (user == null) {
        return isPublic ? null : AppRoutes.login;
      }

      // ── حماية الأدوار: USER أو COACH فقط في هذا التطبيق ─
      if (!user.canAccessToBest) {
        // دور غير مسموح → Logout + Login
        ref.read(authStateProvider.notifier).logout();
        return AppRoutes.login;
      }

      // ── فحص حالة الاشتراك ────────────────────────────────
      if (isPublic) return null;

      switch (user.subscriptionStatus) {
        case SubscriptionStatus.pending:
          if (location != AppRoutes.subscriptionPending) {
            return AppRoutes.subscriptionPending;
          }
        case SubscriptionStatus.rejected:
          if (location != AppRoutes.subscriptionRejected) {
            return AppRoutes.subscriptionRejected;
          }
        case SubscriptionStatus.expired:
          if (location != AppRoutes.subscriptionExpired) {
            return AppRoutes.subscriptionExpired;
          }
        case SubscriptionStatus.active:
        case SubscriptionStatus.guest:
          break;
      }

      return null;
    },

    routes: [
      // ── Splash ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Auth Screens ──────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) => OtpScreen(
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.googleCompletion,
        builder: (context, state) => const GoogleCompletionScreen(),
      ),

      // ── Subscription Status Screens ───────────────────────
      GoRoute(
        path: AppRoutes.subscriptionPending,
        builder: (context, state) => const SubscriptionPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscriptionRejected,
        builder: (context, state) => const SubscriptionRejectedScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscriptionExpired,
        builder: (context, state) => const SubscriptionExpiredScreen(),
      ),

      // ── Main App Shell (Bottom Nav) ───────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.workout,
            builder: (context, state) => const WorkoutScreen(),
          ),
          GoRoute(
            path: AppRoutes.nutrition,
            builder: (context, state) => const NutritionScreen(),
          ),
          GoRoute(
            path: AppRoutes.progress,
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: AppRoutes.conversations,
            builder: (context, state) => const ConversationsScreen(),
            routes: [
              GoRoute(
                path: 'chat/:conversationId',
                builder: (context, state) => ChatScreen(
                  conversationId: state.pathParameters['conversationId']!,
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Standalone Screens ────────────────────────────────
      GoRoute(
        path: AppRoutes.aiCoach,
        builder: (context, state) => const AiCoachScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (context, state) => const SubscriptionScreen(),
      ),
    ],

    // ── Slide Transition حسب اللغة ────────────────────────
    observers: [_SlideTransitionObserver()],
  );
}

/// Observer لإضافة Slide Animation حسب اتجاه اللغة
class _SlideTransitionObserver extends NavigatorObserver {}
