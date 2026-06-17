// packages/shared/lib/infrastructure/gas_client.dart

import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared/config/app_config.dart';
import 'package:shared/config/secrets.dart';

part 'gas_client.g.dart';

/// عميل HTTP لـ Google Apps Script API
///
/// يتعامل مع:
/// - إضافة مفاتيح التوثيق لكل طلب
/// - إعادة المحاولة عند الفشل (3 مرات)
/// - تسجيل الأخطاء في Debug Mode
/// - قراءة GAS URL من Secure Storage (يعدّله MANAGER)
class GasClient {
  GasClient._(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  /// مزود GAS Client — يُقرأ من Secure Storage أولاً، ثم من Secrets
  static Future<GasClient> create(FlutterSecureStorage storage) async {
    // قراءة الإعدادات من التخزين الآمن (يحددها MANAGER)
    final storedUrl = await storage.read(key: _kGasUrlKey);
    final storedKey = await storage.read(key: _kGasSecretKey);

    final baseUrl  = storedUrl  ?? AppSecrets.gasBaseUrl;
    final secretKey = storedKey ?? AppSecrets.gasSecretKey;

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          // مفتاح التوثيق يُرسَل في كل طلب
          'X-Secret-Key': secretKey,
        },
      ),
    );

    // إضافة Retry Interceptor
    dio.interceptors.add(_RetryInterceptor(dio: dio, maxRetries: AppConfig.maxRetries));

    // تسجيل في Debug Mode فقط
    if (AppConfig.isDebug) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => developer.log(obj.toString(), name: 'GAS'),
      ));
    }

    return GasClient._(dio, storage);
  }

  static const _kGasUrlKey    = 'gas_base_url';
  static const _kGasSecretKey = 'gas_secret_key';

  // ── طرق HTTP الأساسية ────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.delete<T>(path, data: data, options: options);

  /// تحديث إعدادات الاتصال (MANAGER فقط)
  Future<void> updateConnectionSettings({
    required String gasUrl,
    required String secretKey,
    required String geminiKey,
  }) async {
    await _storage.write(key: _kGasUrlKey,    value: gasUrl);
    await _storage.write(key: _kGasSecretKey, value: secretKey);
    await _storage.write(key: _kGeminiKeyKey, value: geminiKey);

    // إعادة تهيئة Dio بالإعدادات الجديدة
    _dio.options.baseUrl = gasUrl;
    _dio.options.headers['X-Secret-Key'] = secretKey;

    developer.log('Connection settings updated', name: 'GasClient');
  }

  /// جلب Gemini Key من Secure Storage
  Future<String> getGeminiKey() async {
    final stored = await _storage.read(key: _kGeminiKeyKey);
    return stored ?? AppSecrets.geminiApiKey;
  }

  static const _kGeminiKeyKey = 'gemini_api_key';
}

/// Interceptor لإعادة المحاولة عند الفشل
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({required this.dio, required this.maxRetries});

  final Dio dio;
  final int maxRetries;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra  = err.requestOptions.extra;
    final retries = (extra['retries'] as int?) ?? 0;

    // لا تعيد على أخطاء المصادقة أو الصلاحيات
    final status = err.response?.statusCode;
    if (status == 401 || status == 403 || status == 404) {
      return handler.next(err);
    }

    if (retries < maxRetries) {
      developer.log('Retrying request (${retries + 1}/$maxRetries)', name: 'GasClient');

      // انتظار تصاعدي: 1s, 2s, 4s
      await Future.delayed(Duration(seconds: 1 << retries));

      try {
        final options = Options(
          method: err.requestOptions.method,
          headers: err.requestOptions.headers,
          extra: {...err.requestOptions.extra, 'retries': retries + 1},
        );

        final response = await dio.request<dynamic>(
          err.requestOptions.path,
          data: err.requestOptions.data,
          queryParameters: err.requestOptions.queryParameters,
          options: options,
        );
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}

/// مزود GasClient للـ Riverpod
@riverpod
Future<GasClient> gasClient(Ref ref) async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  return GasClient.create(storage);
}
