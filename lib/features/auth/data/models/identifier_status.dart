// lib/features/auth/data/models/identifier_status.dart

/// The channel an identifier resolves to.
enum IdentifierChannel { email, phone }

/// The next step the login state-machine should take for an identifier.
enum IdentifierNextStep { password, otp }

/// Response of `POST /api/v1/auth/identifier-status`.
///
/// Backend contract (frozen):
///   req  {identifier: string}
///   res  {exists, verified, has_password, channel: "email"|"phone",
///         next_step: "password"|"otp"}
/// where next_step == "password" iff exists && verified && has_password,
/// else "otp".
class IdentifierStatus {
  final bool exists;
  final bool verified;
  final bool hasPassword;
  final IdentifierChannel channel;
  final IdentifierNextStep nextStep;

  const IdentifierStatus({
    required this.exists,
    required this.verified,
    required this.hasPassword,
    required this.channel,
    required this.nextStep,
  });

  bool get isPasswordStep => nextStep == IdentifierNextStep.password;
  bool get isOtpStep => nextStep == IdentifierNextStep.otp;
  bool get isEmail => channel == IdentifierChannel.email;
  bool get isPhone => channel == IdentifierChannel.phone;

  /// New user: no account exists yet → signup (OTP + set password).
  bool get isNewUser => !exists;

  factory IdentifierStatus.fromJson(Map<String, dynamic> json) {
    final channelRaw = (json['channel'] as String?)?.toLowerCase().trim();
    final nextStepRaw = (json['next_step'] as String?)?.toLowerCase().trim();
    return IdentifierStatus(
      exists: json['exists'] == true,
      verified: json['verified'] == true,
      hasPassword: json['has_password'] == true,
      channel: channelRaw == 'email' ? IdentifierChannel.email : IdentifierChannel.phone,
      nextStep: nextStepRaw == 'password' ? IdentifierNextStep.password : IdentifierNextStep.otp,
    );
  }

  @override
  String toString() =>
      'IdentifierStatus(exists: $exists, verified: $verified, '
      'hasPassword: $hasPassword, channel: ${channel.name}, '
      'nextStep: ${nextStep.name})';
}
