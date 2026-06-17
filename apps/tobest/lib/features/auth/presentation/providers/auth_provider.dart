// apps/tobest/lib/features/auth/presentation/providers/auth_provider.dart

import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/domain/entities/user_entity.dart';
import 'package:shared/infrastructure/background_service.dart';
import 'package:shared/infrastructure/gas_client.dart';

part 'auth_provider.g.dart';

/// حالة المصادقة — المستخدم الحالي (null = غير مسجَّل)
@riverpod
class AuthState extends _$AuthState {
  static const _kUserIdKey    = 'current_user_id';
  static const _kUserTokenKey = 'current_user_token';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  FutureOr<UserEntity?> build() async => _loadCurrentUser();

  /// تحميل المستخدم من الـ Secure Storage
  Future<UserEntity?> _loadCurrentUser() async {
    try {
      final userId = await _storage.read(key: _kUserIdKey);
      if (userId == null) return null;

      // جلب من Isar أولاً (أسرع)
      final gasClient = await ref.read(gasClientProvider.future);
      final response  = await gasClient.get<Map<String, dynamic>>(
        '/auth/me',
        queryParameters: {'userId': userId},
      );

      return _parseUser(response.data ?? {});
    } catch (e) {
      developer.log('Failed to load user: $e', name: 'AuthProvider');
      return null;
    }
  }

  /// تسجيل الدخول بالإيميل
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final gasClient = await ref.read(gasClientProvider.future);
      final deviceInfo = await _getDeviceInfo();

      final response = await gasClient.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email':      email,
          'password':   password,
          'deviceId':   deviceInfo['deviceId'],
          'deviceName': deviceInfo['deviceName'],
          'platform':   deviceInfo['platform'],
        },
      );

      final data = response.data ?? {};
      _validateRole(data['role'] as String?);

      final user = _parseUser(data);
      await _saveSession(user.id, data['token'] as String? ?? '');
      await _startBackgroundTasks(user.id);

      return user;
    });
  }

  /// تسجيل الدخول بـ Google
  Future<void> loginWithGoogle(String idToken) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final gasClient = await ref.read(gasClientProvider.future);
      final deviceInfo = await _getDeviceInfo();

      final response = await gasClient.post<Map<String, dynamic>>(
        '/auth/google',
        data: {
          'idToken':    idToken,
          'deviceId':   deviceInfo['deviceId'],
          'deviceName': deviceInfo['deviceName'],
          'platform':   deviceInfo['platform'],
        },
      );

      final data = response.data ?? {};
      _validateRole(data['role'] as String?);

      final user = _parseUser(data);
      await _saveSession(user.id, data['token'] as String? ?? '');
      return user;
    });
  }

  /// تسجيل حساب جديد
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required double height,
    required double weight,
    required int age,
    required String gender,
    String? referralCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final gasClient = await ref.read(gasClientProvider.future);

      final response = await gasClient.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name':         name,
          'email':        email,
          'password':     password,
          'phone':        phone,
          'height':       height,
          'weight':       weight,
          'age':          age,
          'gender':       gender,
          'referralCode': referralCode,
        },
      );

      final data = response.data ?? {};
      final user = _parseUser(data);
      await _saveSession(user.id, data['token'] as String? ?? '');
      return user;
    });
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    final userId = state.valueOrNull?.id;
    state = const AsyncData(null);

    await _storage.delete(key: _kUserIdKey);
    await _storage.delete(key: _kUserTokenKey);

    if (userId != null) {
      await BackgroundService.cancelForUser(userId);
    }
  }

  /// التحقق من أن الدور مسموح به في هذا التطبيق
  void _validateRole(String? role) {
    if (role == null) throw Exception('Role not specified');
    if (!AppConfig.toBestRoles.contains(role)) {
      throw Exception('Access denied: role $role cannot access TO Best');
    }
  }

  Future<void> _saveSession(String userId, String token) async {
    await _storage.write(key: _kUserIdKey,    value: userId);
    await _storage.write(key: _kUserTokenKey, value: token);
  }

  Future<void> _startBackgroundTasks(String userId) async {
    await BackgroundService.scheduleChatFetch(userId);
    await BackgroundService.scheduleHealthSync(userId);
    await BackgroundService.scheduleWeeklyCleanup(userId);
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    // معرّف الجهاز الفريد
    return {
      'deviceId':   'device_${DateTime.now().millisecondsSinceEpoch}',
      'deviceName': 'Flutter Device',
      'platform':   'android', // يُكتشف تلقائياً
    };
  }

  UserEntity _parseUser(Map<String, dynamic> data) {
    return UserEntity(
      id:                   data['id'] as String? ?? '',
      email:                data['email'] as String? ?? '',
      role:                 data['role'] as String? ?? AppRole.user,
      name:                 data['name'] as String? ?? '',
      phone:                data['phone'] as String?,
      height:               (data['height'] as num?)?.toDouble(),
      weight:               (data['weight'] as num?)?.toDouble(),
      age:                  data['age'] as int?,
      gender:               data['gender'] as String?,
      subscriptionStatus:   _parseStatus(data['subscriptionStatus'] as String?),
      subscriptionPlan:     data['subscriptionPlan'] as String?,
      assignedCoachId:      data['assignedCoachId'] as String?,
      referralCode:         data['referralCode'] as String?,
      preferredLanguage:    data['preferredLanguage'] as String? ?? 'ar',
      selectedTheme:        data['selectedTheme'] as String? ?? 'auto',
    );
  }

  static SubscriptionStatus _parseStatus(String? s) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SubscriptionStatus.pending,
    );
  }
}

import 'package:shared/config/app_config.dart';
import 'package:shared/domain/entities/user_entity.dart';
