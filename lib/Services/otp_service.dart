// lib/Services/otp_service.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════
  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;
  bool _isCodeSent = false;
  bool _isVerified = false;

  // Getters
  bool get isCodeSent => _isCodeSent;
  bool get isVerified => _isVerified;
  String? get phoneNumber => _phoneNumber;

  // ═══════════════════════════════════════════════════════
  // CALLBACKS
  // ═══════════════════════════════════════════════════════
  Function(String verificationId, int? resendToken)? onCodeSent;
  Function(FirebaseAuthException e)? onVerificationFailed;
  Function(PhoneAuthCredential credential)? onVerificationCompleted;
  Function(String verificationId)? onCodeAutoRetrievalTimeout;

  // ═══════════════════════════════════════════════════════
  // ✅ SEND OTP
  // ═══════════════════════════════════════════════════════
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    Function(PhoneAuthCredential credential)? onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    // Reset state
    _verificationId = null;
    _isCodeSent = false;
    _isVerified = false;
    _phoneNumber = phoneNumber;

    // Store callbacks
    this.onCodeSent = onCodeSent;
    this.onVerificationFailed = onVerificationFailed;
    this.onVerificationCompleted = onVerificationCompleted;
    this.onCodeAutoRetrievalTimeout = onCodeAutoRetrievalTimeout;

    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('📱 SENDING OTP TO: $phoneNumber');
      debugPrint('═══════════════════════════════════════════');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        forceResendingToken: forceResendingToken,

        // ✅ OTP sent successfully
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('✅ Auto-verification completed');
          _isVerified = true;
          onVerificationCompleted?.call(credential);
        },

        // ✅ OTP code sent to phone
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Verification failed: ${e.code} - ${e.message}');
          _isCodeSent = false;
          onVerificationFailed(e);
        },

        // ✅ SMS code sent
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ OTP code sent!');
          debugPrint('📌 Verification ID: $verificationId');
          debugPrint('📌 Resend Token: $resendToken');

          _verificationId = verificationId;
          _resendToken = resendToken;
          _isCodeSent = true;

          onCodeSent(verificationId, resendToken);
        },

        // ⏱ Timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏱ Auto-retrieval timeout');
          _verificationId = verificationId;
          onCodeAutoRetrievalTimeout?.call(verificationId);
        },
      );
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VERIFY OTP
  // ═══════════════════════════════════════════════════════
  Future<PhoneAuthCredential> verifyOtp({
    required String smsCode,
    String? verificationId,
  }) async {
    final vid = verificationId ?? _verificationId;

    if (vid == null || vid.isEmpty) {
      throw Exception('Verification ID not found. Please request OTP again.');
    }

    if (smsCode.isEmpty || smsCode.length != 6) {
      throw Exception('Please enter a valid 6-digit OTP.');
    }

    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔐 VERIFYING OTP: $smsCode');
      debugPrint('═══════════════════════════════════════════');

      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: smsCode,
      );

      // Sign in with credential
      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _isVerified = true;
        debugPrint('✅ OTP verified! User: ${userCredential.user!.uid}');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ OTP verification failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RESEND OTP
  // ═══════════════════════════════════════════════════════
  Future<void> resendOtp({
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
  }) async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      throw Exception('Phone number not found. Please start again.');
    }

    await sendOtp(
      phoneNumber: _phoneNumber!,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      forceResendingToken: _resendToken,
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ RESET STATE
  // ═══════════════════════════════════════════════════════
  void reset() {
    _verificationId = null;
    _resendToken = null;
    _phoneNumber = null;
    _isCodeSent = false;
    _isVerified = false;
    onCodeSent = null;
    onVerificationFailed = null;
    onVerificationCompleted = null;
    onCodeAutoRetrievalTimeout = null;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ HELPER: Format phone number with country code
  // ═══════════════════════════════════════════════════════
  static String formatPhoneNumber(String raw) {
    // Remove all non-digits
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // If already has country code (starts with 91 and 12 digits)
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }

    // If 10 digits (Indian number without country code)
    if (digits.length == 10) {
      return '+91$digits';
    }

    // Fallback: prepend +91
    return '+91$digits';
  }
}