// lib/presentation/authScreen/PhoneSignupScreen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/otp_service.dart';
import '../../TechnicianCustomertermAndCondition/TermsAndConditionsScreen.dart';
import '../Marchant_screens/MerchantRegistrationWidget.dart';
import 'PhoneLoginScreen.dart';
import 'SignupScreen.dart';
import 'VerifyOtpScreen.dart';

class PhoneSignupScreen extends StatefulWidget {
  const PhoneSignupScreen({super.key});

  @override
  State<PhoneSignupScreen> createState() => _PhoneSignupScreenState();
}

class _PhoneSignupScreenState extends State<PhoneSignupScreen> {
  final TextEditingController phoneController = TextEditingController();
  final OtpService _otpService = OtpService();

  bool isLoading = false;
  bool _isTermsAccepted = false;
  bool _isMerchantSelected = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND OTP FOR SIGNUP
  // ============================================================

  Future<void> _sendOtp() async {
    final rawPhone = phoneController.text.trim();

    if (rawPhone.isEmpty) {
      _showSnack('Please enter your phone number', Colors.orange);
      return;
    }

    if (rawPhone.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
      _showSnack('Please enter a valid 10-digit phone number', Colors.orange);
      return;
    }

    if (!_isTermsAccepted) {
      _showSnack('Please accept Terms & Conditions', Colors.orange);
      return;
    }

    final formattedPhone = OtpService.formatPhoneNumber(rawPhone);

    setState(() => isLoading = true);

    try {
      await _otpService.sendOtp(
        phoneNumber: formattedPhone,
        onCodeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => isLoading = false);
          _showSnack('OTP sent successfully!', Colors.green);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyOtpScreen(
                verificationId: verificationId,
                phoneNumber: formattedPhone,
                isSignup: true,
                isMerchant: _isMerchantSelected,
                resendToken: resendToken,
              ),
            ),
          );
        },
        onVerificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => isLoading = false);
          _showSnack(e.message ?? 'Verification failed', Colors.red);
        },
        onVerificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('Auto verification completed in PhoneSignupScreen');
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showSnack('Error sending OTP: $e', Colors.red);
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

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
            // ========================================================
            // BACKGROUND IMAGE
            // ========================================================
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

            // ========================================================
            // DARK OVERLAY
            // ========================================================
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

            // ========================================================
            // RESPONSIVE CONTENT
            // ========================================================
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;

                  double topSpace = availableHeight * 0.40;
                  if (topSpace < 250) topSpace = 250;
                  if (topSpace > 370) topSpace = 370;

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
                        const Text(
                          "Create Account with Phone",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "We will send a verification code to your phone",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ==================================================
                        // PHONE NUMBER FIELD
                        // ==================================================
                        _buildPhoneField(),

                        const SizedBox(height: 14),

                        // ==================================================
                        // TERMS
                        // ==================================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _isTermsAccepted,
                                onChanged: (value) {
                                  setState(() => _isTermsAccepted = value ?? false);
                                },
                                activeColor: const Color(0xff009999),
                                checkColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white70,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TermsAndConditionsScreen(),
                                    ),
                                  );
                                },
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    children: const [
                                      TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms & Conditions',
                                        style: TextStyle(
                                          color: Color(0xff42D7D7),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // SIGNUP BUTTON
                        // ==================================================
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _sendOtp,
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
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (_isMerchantSelected)
                                            const Icon(
                                              Icons.storefront,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          if (_isMerchantSelected)
                                            const SizedBox(width: 8),
                                          const Text(
                                            "SIGNUP WITH PHONE",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // SWITCH TO EMAIL SIGNUP
                        // ==================================================
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.email, color: Color(0xff42D7D7), size: 20),
                          label: const Text(
                            "Signup with Email",
                            style: TextStyle(
                              color: Color(0xff42D7D7),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ==================================================
                        // LOGIN LINK
                        // ==================================================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "Already have an account?",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PhoneLoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Login with Phone",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff42D7D7),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ==================================================
                        // MERCHANT TOGGLE
                        // ==================================================
                        MerchantRegistrationWidget(
                          isMerchantSelected: _isMerchantSelected,
                          onToggle: (bool value) {
                            setState(() => _isMerchantSelected = value);
                          },
                        ),

                        const SizedBox(height: 30),
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

  // ============================================================
  // PHONE FIELD
  // ============================================================

  Widget _buildPhoneField() {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          hintText: "Phone Number (e.g. 9876543210)",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.phone, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                "+91 ",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                height: 20,
                width: 1,
                color: Colors.white38,
                margin: const EdgeInsets.only(right: 8),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
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
    );
  }
}
