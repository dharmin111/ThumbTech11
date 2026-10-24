// lib/presentation/authScreen/VerifyOtpScreen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:thumstechs/Userform/UserInfoScreen.dart';
import '../../Admin/AdminScreens/AdminDashboard.dart';
import '../../Admin/AdminScreens/AdminPendingScreen.dart';
import '../../Services/authServices.dart';
import '../../Services/oneSignalNotificationService.dart';
import '../../Services/otp_service.dart';
import '../DashBoard/CustomerDashboard.dart';
import '../DashBoard/TechnicianDashboard.dart';
import '../Marchant_screens/Merchant_Detail_Screen.dart';
import '../Marchant_screens/StepFiveScreen.dart';
import '../Marchant_screens/StepFourScreen.dart';
import '../Marchant_screens/StepSixScreen.dart';
import '../Marchant_screens/StepThreeScreen.dart';
import '../Marchant_screens/StepTwoScreen.dart';
import 'LoginScreen.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final bool isSignup;
  final bool isMerchant;
  final int? resendToken;

  const VerifyOtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.isSignup = false,
    this.isMerchant = false,
    this.resendToken,
  });

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final OtpService _otpService = OtpService();
  final AuthService _authService = AuthService();

  late String _currentVerificationId;
  int? _currentResendToken;

  bool isLoading = false;
  bool isResending = false;

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _currentResendToken = widget.resendToken;
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        _timer?.cancel();
      }
    });
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showSnack('Please enter a valid 6-digit OTP', Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      await _otpService.verifyOtp(
        smsCode: otp,
        verificationId: _currentVerificationId,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnack('Authentication failed. Please try again.', Colors.red);
        setState(() => isLoading = false);
        return;
      }

      if (widget.isSignup) {
        await _handleSignupFlow(user);
      } else {
        await _handleLoginFlow(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnack(e.message ?? 'OTP Verification failed', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error verifying OTP: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // SIGNUP FLOW
  // ============================================================

  Future<void> _handleSignupFlow(User user) async {
    final role = widget.isMerchant ? 'merchant' : 'customer';

    await _authService.saveUserRole(
      userId: user.uid,
      phoneNumber: widget.phoneNumber,
      role: role,
    );

    _showSnack('Account created successfully!', Colors.green);

    if (!mounted) return;

    if (widget.isMerchant) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantDetailScreen(
            userId: user.uid,
            userEmail: user.email ?? widget.phoneNumber,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const UserInfoScreen(),
        ),
      );
    }
  }

  // ============================================================
  // LOGIN FLOW
  // ============================================================

  Future<void> _handleLoginFlow(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (!mounted) return;
    if (!doc.exists || doc.data() == null) {
      // User logged in via phone, but no user document yet → create customer doc & go to UserInfoScreen
      await _authService.saveUserRole(
        userId: user.uid,
        phoneNumber: widget.phoneNumber,
        role: 'customer',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const UserInfoScreen(),
        ),
      );
      return;
    }

    final data = doc.data()!;
    final isActive = data['isActive'] ?? true;

    if (!isActive) {
      await FirebaseAuth.instance.signOut();
      _showSnack(
        'Your account has been deactivated. Please contact admin +917087234563',
        Colors.red,
      );
      return;
    }

    final role = data['role'] ?? 'customer';

    await _saveOneSignalId(user.uid, role);

    _showSnack("Login Successful", Colors.green);

    if (!mounted) return;

    if (role == "merchant") {
      await _handleMerchantNavigation(user);
    } else if (role == "customer") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CustomerDashboard(),
        ),
      );
    } else if (role == "technician") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TechnicianDashboard(),
        ),
      );
    } else if (role == "admin") {
      final isApproved = data['isApproved'] ?? false;
      if (isApproved) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboard(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminPendingScreen(),
          ),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CustomerDashboard(),
        ),
      );
    }
  }

  // ============================================================
  // MERCHANT NAVIGATION
  // ============================================================

  Future<void> _handleMerchantNavigation(User user) async {
    try {
      final merchantDoc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(user.uid)
          .get();

      if (!merchantDoc.exists) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantDetailScreen(
              userId: user.uid,
              userEmail: user.email ?? widget.phoneNumber,
            ),
          ),
        );
        return;
      }

      final merchantData = merchantDoc.data() as Map<String, dynamic>;
      final status = merchantData['status'] ?? 'pending';

      if (!mounted) return;

      switch (status) {
        case 'pending':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StepTwoScreen(
                userId: user.uid,
                userEmail: user.email ?? widget.phoneNumber,
              ),
            ),
          );
          break;
        case 'received':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StepThreeScreen(
                userId: user.uid,
                userEmail: user.email ?? widget.phoneNumber,
              ),
            ),
          );
          break;
        case 'uploaded':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StepFourScreen(
                userId: user.uid,
                userEmail: user.email ?? widget.phoneNumber,
              ),
            ),
          );
          break;
        case 'verified':
        case 'waiting':
        case 'pending_approval':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StepFiveScreen(
                userId: user.uid,
                userEmail: user.email ?? widget.phoneNumber,
              ),
            ),
          );
          break;
        case 'display':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StepSixScreen(
                userId: user.uid,
                userEmail: user.email ?? widget.phoneNumber,
              ),
            ),
          );
          break;
        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MerchantDetailScreen(
                userId: user.uid,
                userEmail: user.email ?? widget.phoneNumber,
              ),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantDetailScreen(
            userId: user.uid,
            userEmail: user.email ?? widget.phoneNumber,
          ),
        ),
      );
    }
  }

  // ============================================================
  // ONESIGNAL
  // ============================================================

  Future<void> _saveOneSignalId(String userId, String role) async {
    try {
      await OneSignalNotificationService.initialize();
      String? oneSignalId;

      for (int i = 0; i < 10; i++) {
        oneSignalId = OneSignal.User.pushSubscription.id;
        if (oneSignalId != null && oneSignalId.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (oneSignalId == null || oneSignalId.isEmpty) return;

      await FirebaseFirestore.instance.collection("users").doc(userId).set({
        'oneSignalId': oneSignalId,
        'role': role,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving OneSignal ID: $e');
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || isResending) return;

    setState(() => isResending = true);

    try {
      await _otpService.sendOtp(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _currentResendToken,
        onCodeSent: (String newVid, int? newResendToken) {
          if (!mounted) return;
          setState(() {
            _currentVerificationId = newVid;
            _currentResendToken = newResendToken;
            isResending = false;
          });
          _startResendTimer();
          _showSnack('OTP Resent successfully!', Colors.green);
        },
        onVerificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => isResending = false);
          _showSnack(e.message ?? 'Failed to resend OTP', Colors.red);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => isResending = false);
        _showSnack('Error resending OTP: $e', Colors.red);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF4A6B7C),
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ======================================================
            // BACKGROUND IMAGE
            // ======================================================
            Positioned.fill(
              child: Image.asset(
                'assets/images/signUpUI.PNG',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF4A6B7C),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 100, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Image not found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ======================================================
            // DARK GRADIENT
            // ======================================================
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.65),
                    ],
                    stops: const [0.0, 0.35, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ======================================================
            // RESPONSIVE CONTENT
            // ======================================================
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;

                  double topSpace = height * 0.38;
                  if (topSpace < 230) topSpace = 230;
                  if (topSpace > 350) topSpace = 350;

                  double horizontalPadding = screenWidth * 0.065;
                  if (horizontalPadding < 20) horizontalPadding = 20;
                  if (horizontalPadding > 30) horizontalPadding = 30;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      top: topSpace,
                      bottom: 30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // BACK BUTTON
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text(
                          "Enter Verification Code",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "6-digit code sent to ${widget.phoneNumber}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ==================================================
                        // OTP FIELD
                        // ==================================================
                        SizedBox(
                          height: 55,
                          child: TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 12,
                            ),
                            decoration: InputDecoration(
                              counterText: "",
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.15),
                              hintText: "──────",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 22,
                                letterSpacing: 8,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xff42D7D7),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // VERIFY BUTTON
                        // ==================================================
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              backgroundColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              elevation: 0,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff009999),
                                    Color(0xff008976),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        "VERIFY & CONTINUE",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // RESEND OTP TIMER / BUTTON
                        // ==================================================
                        Center(
                          child: _resendCountdown > 0
                              ? Text(
                                  "Resend OTP in ${_resendCountdown}s",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : TextButton(
                                  onPressed: isResending ? null : _resendOtp,
                                  child: isResending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xff42D7D7),
                                          ),
                                        )
                                      : const Text(
                                          "Resend OTP",
                                          style: TextStyle(
                                            color: Color(0xff42D7D7),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
