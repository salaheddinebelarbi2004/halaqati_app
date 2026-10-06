import 'package:flutter_test/flutter_test.dart';
import 'package:halaqati/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('invalid credentials map to a precise Arabic message', () {
    final error = AuthApiException(
      'Invalid login credentials',
      statusCode: 'invalid_credentials',
    );

    expect(describeAuthError(error), 'اسم المستخدم أو كلمة المرور غير صحيحين');
    expect(
      mapAppError(error).message,
      'اسم المستخدم أو كلمة المرور غير صحيحين',
    );
  });

  test('duplicate email maps to a precise Arabic message', () {
    final error = AuthApiException(
      'User already registered',
      statusCode: 'user_already_exists',
    );

    expect(describeAuthError(error), 'هذا البريد الإلكتروني مسجّل بالفعل');
  });
}
