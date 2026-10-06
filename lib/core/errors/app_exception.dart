import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthRetryableFetchException;

/// What went wrong, in the two shapes the UI cares about.
enum AppErrorKind {
  /// No usable connection: interface down, or the request never landed.
  offline,

  /// Anything else: bad credentials, constraint violation, server error.
  generic,
}

/// A user-presentable failure.
///
/// The app is cloud-only, so "we could not reach the server" and "the server
/// said no" are the only two categories worth showing. [message] is always
/// Arabic because the whole interface is.
class AppException implements Exception {
  const AppException(this.kind, this.message, {this.cause});

  final AppErrorKind kind;
  final String message;
  final Object? cause;

  bool get isOffline => kind == AppErrorKind.offline;

  /// Shown whenever the app cannot reach Supabase. Deliberately identical in
  /// every situation so the teacher learns one string, not five.
  static const String offlineMessage = 'لا يوجد اتصال بالإنترنت';

  static const AppException offline = AppException(
    AppErrorKind.offline,
    offlineMessage,
  );

  static const AppException generic = AppException(
    AppErrorKind.generic,
    'حدث خطأ غير متوقع',
  );

  @override
  String toString() => 'AppException($kind): $message';
}

/// Turns whatever the network stack threw into an [AppException].
///
/// The connectivity plugin only reports the network *interface*: it happily
/// says "online" on a captive portal or a dead uplink. So every real request
/// failure is funnelled through here as well.
String describeAuthError(AuthApiException error) {
  final code = error.statusCode?.toLowerCase();
  final message = error.message.toLowerCase();

  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return 'يرجى تأكيد البريد الإلكتروني قبل تسجيل الدخول';
  }
  if (code == 'invalid_credentials' ||
      message.contains('invalid login credentials')) {
    return 'اسم المستخدم أو كلمة المرور غير صحيحين';
  }
  if (code == 'weak_password' ||
      message.contains('password should be at least')) {
    return 'كلمة المرور يجب أن تكون ٦ أحرف على الأقل';
  }
  if (code == 'email_exists' ||
      code == 'user_already_exists' ||
      message.contains('already registered') ||
      message.contains('already exists')) {
    return 'هذا البريد الإلكتروني مسجّل بالفعل';
  }
  if (code == 'invalid_email' || message.contains('invalid email')) {
    return 'البريد الإلكتروني غير صحيح';
  }
  if (code == 'signup_disabled' || message.contains('signups not allowed')) {
    return 'التسجيل الجديد غير متاح حالياً';
  }
  if (code == 'too_many_requests' || message.contains('too many requests')) {
    return 'تم إرسال طلبات كثيرة، حاول مرة أخرى لاحقاً';
  }

  return error.message.isEmpty ? 'حدث خطأ في المصادقة' : error.message;
}

AppException mapAppError(Object error, [StackTrace? stack]) {
  if (error is AppException) return error;

  if (error is AuthApiException) {
    final message = describeAuthError(error);
    return AppException(AppErrorKind.generic, message, cause: error);
  }

  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException ||
      error is ClientException ||
      error is AuthRetryableFetchException) {
    return AppException(
      AppErrorKind.offline,
      AppException.offlineMessage,
      cause: error,
    );
  }

  return AppException(
    AppErrorKind.generic,
    AppException.generic.message,
    cause: error,
  );
}

/// Runs [action], converting any error into an [AppException].
///
/// ```dart
/// final students = await guard(() => _db.getStudents());
/// ```
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error, stack) {
    Error.throwWithStackTrace(mapAppError(error, stack), stack);
  }
}

/// Same as [guard] for a [Stream], whose failures arrive through the channel
/// rather than a `throw`. `yield*` is what lets them be caught and re-emitted
/// as an [AppException]; `handleError` would swallow them into the zone.
extension GuardedStream<T> on Stream<T> {
  Stream<T> guarded() async* {
    try {
      yield* this;
    } catch (error, stack) {
      Error.throwWithStackTrace(mapAppError(error, stack), stack);
    }
  }
}
