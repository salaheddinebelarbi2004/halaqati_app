import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';

/// Thin wrapper over `supabase.auth`.
///
/// Session persistence, refresh and the token lifecycle are handled by
/// `supabase_flutter` — no token is ever stored by hand.
class AuthService {
  AuthService([GoTrueClient? auth])
    : _auth = auth ?? Supabase.instance.client.auth;

  final GoTrueClient _auth;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      guard(() async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  Future<AuthResponse> signUpResponse({
    required String email,
    required String password,
  }) => guard(() async {
    return _auth.signUp(email: email.trim(), password: password);
  });

  /// Returns `true` when the account was created, `false` when the address is
  /// already registered.
  Future<bool> signUp({required String email, required String password}) =>
      signUpResponse(email: email, password: password).then((response) {
        return response.user != null;
      });

  Future<void> resetPassword(String email) => guard(() async {
    await _auth.resetPasswordForEmail(email.trim());
  });

  Future<void> signOut() => guard(() async {
    await _auth.signOut();
  });
}
