// lib/presentation/authScreen/SignupScreen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thumstechs/Userform/UserInfoScreen.dart';
import '../../Services/authServices.dart';
import '../../TechnicianCustomertermAndCondition/TermsAndConditionsScreen.dart';
import '../Marchant_screens/MerchantRegistrationWidget.dart';
import '../Marchant_screens/Merchant_Detail_Screen.dart';
import 'LoginScreen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService auth = AuthService();

  bool isLoading = false;
  bool _isTermsAccepted = false;
  bool _obscurePassword = false;
  bool _isMerchantSelected = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // SIGNUP LOGIC — UNCHANGED
  // ============================================================

  Future<void> signupUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack(
        "Please fill all fields",
        Colors.orange,
      );
      return;
    }

    if (password.length < 6) {
      _showSnack(
        "Password must be at least 6 characters",
        Colors.orange,
      );
      return;
    }

    if (!_isTermsAccepted) {
      _showSnack(
        "Please accept Terms & Conditions",
        Colors.orange,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await auth.signUp(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final user = userCredential.user!;

        await auth.saveUserRole(
          userId: user.uid,
          email: user.email ?? '',
          role: _isMerchantSelected ? 'merchant' : 'customer',
        );

        _showSnack(
          "Account created successfully!",
          Colors.green,
        );

        if (mounted) {
          if (_isMerchantSelected) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MerchantDetailScreen(
                  userId: user.uid,
                  userEmail: user.email ?? '',
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const UserInfoScreen(),
              ),
            );
          }
        }
      } else {
        _showSnack(
          "Failed to create account. Please try again.",
          Colors.red,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;

        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email.';
          break;

        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;

        default:
          errorMessage = 'Failed to create account: ${e.message}';
      }

      _showSnack(
        errorMessage,
        Colors.red,
      );
    } catch (e) {
      _showSnack(
        "Error: $e",
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnack(
      String msg,
      Color color,
      ) {
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
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF4A6B7C),

      // Keyboard ke waqt layout adjust hoga
      resizeToAvoidBottomInset: false,

      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },

        child: Stack(
          fit: StackFit.expand,
          children: [
            // ========================================================
            // LAYER 1 — BACKGROUND IMAGE
            // ========================================================

            Positioned.fill(
              child: Image.asset(
                'assets/images/signUpUI.PNG',

                // Background image complete screen cover karegi.
                // Aspect ratio distort nahi hoga.
                fit: BoxFit.cover,

                errorBuilder: (
                    context,
                    error,
                    stackTrace,
                    ) {
                  return Container(
                    color: const Color(0xFF4A6B7C),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 100,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Image not found',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ========================================================
            // LAYER 2 — DARK OVERLAY
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
                    stops: const [
                      0.0,
                      0.35,
                      0.55,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),

            // ========================================================
            // LAYER 3 — RESPONSIVE CONTENT
            // ========================================================

            SafeArea(
              child: LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final availableHeight = constraints.maxHeight;

                  // ====================================================
                  // RESPONSIVE TOP SPACE
                  // ====================================================

                  /*
                   * Old:
                   *
                   * SizedBox(height: 310)
                   * SizedBox(height: 90)
                   *
                   * Total = 400px fixed.
                   *
                   * Ab screen height ke according calculate hoga.
                   */

                  double topSpace = availableHeight * 0.43;

                  // Small screens par minimum
                  if (topSpace < 270) {
                    topSpace = 270;
                  }

                  // Large screens par maximum
                  if (topSpace > 390) {
                    topSpace = 390;
                  }

                  // ====================================================
                  // RESPONSIVE HORIZONTAL PADDING
                  // ====================================================

                  double horizontalPadding = screenWidth * 0.065;

                  if (horizontalPadding < 20) {
                    horizontalPadding = 20;
                  }

                  if (horizontalPadding > 30) {
                    horizontalPadding = 30;
                  }

                  // ====================================================
                  // CONTENT
                  // ====================================================

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),

                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,

                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      top: topSpace,
                      bottom:
                     // mediaQuery.viewInsets.bottom +
                          30,
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ==================================================
                        // EMAIL
                        // ==================================================

                        _buildTextField(
                          controller: emailController,
                          hint: "Email",
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // PASSWORD
                        // ==================================================

                        _buildTextField(
                          controller: passwordController,
                          hint: "Password",
                          icon: Icons.lock,
                          obscureText: _obscurePassword,

                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },

                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 6),

                        // ==================================================
                        // PASSWORD HINT
                        // ==================================================

                        Padding(
                          padding: const EdgeInsets.only(left: 8),

                          child: Text(
                            "Password must be at least 6 characters",

                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),

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
                                  setState(() {
                                    _isTermsAccepted = value ?? false;
                                  });
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
                                      builder: (context) =>
                                      const TermsAndConditionsScreen(),
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
                                      TextSpan(
                                        text: 'I agree to the ',
                                      ),

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

                        const SizedBox(height: 20),

                        // ==================================================
                        // SIGNUP BUTTON
                        // ==================================================

                        SizedBox(
                          height: 55,
                          width: double.infinity,

                          child: ElevatedButton(
                            onPressed: isLoading ? null : signupUser,

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
                                    ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                    : Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,

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
                                      "SIGNUP",
                                      style: TextStyle(
                                        fontSize: 20,
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

                        const SizedBox(height: 8),

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
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },

                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff42D7D7),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // ==================================================
                        // MERCHANT TOGGLE
                        // ==================================================

                        MerchantRegistrationWidget(
                          isMerchantSelected: _isMerchantSelected,

                          onToggle: (bool value) {
                            setState(() {
                              _isMerchantSelected = value;
                            });

                            debugPrint(
                              '🔄 Merchant selected: $_isMerchantSelected',
                            );
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
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 50,

      child: TextField(
        controller: controller,

        keyboardType: keyboardType,

        obscureText: obscureText,

        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),

        decoration: InputDecoration(
          filled: true,

          fillColor: Colors.white.withOpacity(0.15),

          hintText: hint,

          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),

          prefixIcon: Icon(
            icon,
            color: Colors.white70,
            size: 20,
          ),

          suffixIcon: suffixIcon,

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