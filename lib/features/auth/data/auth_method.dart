// lib/features/auth/data/auth_method.dart

/// Authentication methods recorded by `POST /api/v1/auth/last-method`
/// and persisted locally to pre-select the last-used method.
///
/// The wire values match the frozen backend contract exactly.
enum AuthMethod {
  google('google'),
  apple('apple'),
  emailPassword('email_password'),
  phonePassword('phone_password'),
  phoneOtp('phone_otp'),
  emailOtp('email_otp');

  const AuthMethod(this.wireValue);

  /// Value sent to the backend and persisted locally.
  final String wireValue;

  static AuthMethod? fromWire(String? value) {
    if (value == null) return null;
    for (final method in AuthMethod.values) {
      if (method.wireValue == value) return method;
    }
    return null;
  }
}
