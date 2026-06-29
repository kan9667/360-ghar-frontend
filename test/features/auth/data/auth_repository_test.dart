// test/features/auth/data/auth_repository_test.dart
//
// Unit tests for the auth module's utility surfaces: static nonce helpers,
// identifier masking/normalization, identifier-status parsing, and auth-method
// wire mapping. Supabase-dependent methods (signIn, signUp, OTP, etc.) are thin
// wrappers around the Supabase SDK and require integration-level testing.

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';

void main() {
  group('AuthRepository.generateRawNonce', () {
    test('returns a string of the default length (32)', () {
      final nonce = AuthRepository.generateRawNonce();
      expect(nonce.length, 32);
    });

    test('returns a string of the requested length', () {
      final nonce = AuthRepository.generateRawNonce(64);
      expect(nonce.length, 64);
    });

    test('contains only valid charset characters', () {
      final nonce = AuthRepository.generateRawNonce(200);
      final validPattern = RegExp(r'^[A-Za-z0-9\-._]+$');
      expect(validPattern.hasMatch(nonce), isTrue);
    });
  });

  group('AuthRepository.sha256OfString', () {
    test('returns a deterministic hex digest', () {
      final hash1 = AuthRepository.sha256OfString('test-nonce');
      final hash2 = AuthRepository.sha256OfString('test-nonce');
      expect(hash1, equals(hash2));
    });

    test('produces the known SHA-256 for "hello"', () {
      // SHA-256 of "hello" is a well-known constant.
      final hash = AuthRepository.sha256OfString('hello');
      expect(hash, '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824');
    });

    test('different inputs produce different hashes', () {
      final hash1 = AuthRepository.sha256OfString('abc');
      final hash2 = AuthRepository.sha256OfString('xyz');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('IdentifierUtils.mask', () {
    test('masks email: shows first char and domain', () {
      expect(IdentifierUtils.mask('john@gmail.com'), 'j***@gmail.com');
    });

    test('masks email: single-char local part', () {
      expect(IdentifierUtils.mask('a@domain.org'), 'a***@domain.org');
    });

    test('masks phone: hides all but last 4 digits', () {
      expect(IdentifierUtils.mask('+919876543210'), '+91 ******3210');
    });

    test('masks phone: 10-digit raw number', () {
      expect(IdentifierUtils.mask('9876543210'), '+91 ******3210');
    });

    test('returns empty string for empty input', () {
      expect(IdentifierUtils.mask(''), '');
    });

    test('returns raw value for short phone (4 or fewer digits)', () {
      expect(IdentifierUtils.mask('1234'), '1234');
    });
  });

  group('IdentifierUtils.normalize', () {
    test('lowercases and trims email', () {
      expect(IdentifierUtils.normalize('  John@Gmail.COM  '), 'john@gmail.com');
    });

    test('normalizes 10-digit phone to E.164 (+91)', () {
      final normalized = IdentifierUtils.normalize('9876543210');
      expect(normalized, '+919876543210');
    });

    test('keeps already-normalized +91 phone unchanged', () {
      expect(IdentifierUtils.normalize('+919876543210'), '+919876543210');
    });
  });

  group('IdentifierStatus.fromJson', () {
    test('parses existing verified user with password', () {
      final status = IdentifierStatus.fromJson({
        'exists': true,
        'verified': true,
        'has_password': true,
        'channel': 'email',
        'next_step': 'password',
      });

      expect(status.exists, isTrue);
      expect(status.verified, isTrue);
      expect(status.hasPassword, isTrue);
      expect(status.channel, IdentifierChannel.email);
      expect(status.nextStep, IdentifierNextStep.password);
      expect(status.isPasswordStep, isTrue);
    });

    test('parses new user (signup path)', () {
      final status = IdentifierStatus.fromJson({
        'exists': false,
        'verified': false,
        'has_password': false,
        'channel': 'phone',
        'next_step': 'otp',
      });

      expect(status.isNewUser, isTrue);
      expect(status.channel, IdentifierChannel.phone);
      expect(status.isOtpStep, isTrue);
    });
  });

  group('AuthMethod.fromWire', () {
    test('maps known wire values to enum members', () {
      expect(AuthMethod.fromWire('google'), AuthMethod.google);
      expect(AuthMethod.fromWire('apple'), AuthMethod.apple);
      expect(AuthMethod.fromWire('email_password'), AuthMethod.emailPassword);
      expect(AuthMethod.fromWire('phone_password'), AuthMethod.phonePassword);
      expect(AuthMethod.fromWire('phone_otp'), AuthMethod.phoneOtp);
      expect(AuthMethod.fromWire('email_otp'), AuthMethod.emailOtp);
    });

    test('returns null for unknown wire value', () {
      expect(AuthMethod.fromWire('magic_link'), isNull);
    });

    test('returns null for null input', () {
      expect(AuthMethod.fromWire(null), isNull);
    });
  });
}
