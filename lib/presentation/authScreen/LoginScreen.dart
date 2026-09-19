// lib/presentation/authScreen/LoginScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:thumstechs/TechnicianCustomertermAndCondition/TermsAndConditionsScreen.dart';
import 'package:thumstechs/presentation/DashBoard/CustomerDashboard.dart';
import 'package:thumstechs/presentation/DashBoard/TechnicianDashboard.dart';
import 'package:thumstechs/presentation/Marchant_screens/Merchant_Detail_Screen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepTwoScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepThreeScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepFourScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepFiveScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepSixScreen.dart';
import 'package:thumstechs/presentation/TechnicianScreen/TechnicianHomeScreen.dart';
import 'package:thumstechs/presentation/authScreen/signupScreen.dart';
import '../../Admin/AdminScreens/AdminLoginScreen.dart';
import '../../Admin/AdminScreens/AdminPendingScreen.dart';
import '../../Admin/AdminScreens/AdminDashboard.dart';
import '../../Services/authServices.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../Services/oneSignalNotificationService.dart';
import 'forgetPassword.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService auth = AuthService();

  bool isLoading = false;
  bool _isTermsAccepted = false;
  bool _obscurePassword = false;
  bool _guestNavigating = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (!_isTermsAccepted) {
      _showSnack(
        'Please accept the Terms & Conditions to continue',
        Colors.orange,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await auth.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = result.user;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!doc.exists || doc.data() == null) {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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

      // ✅ MERCHANT
      if (role == "merchant") {
        await _handleMerchantNavigation(user);
      }
      // ✅ CUSTOMER
      else if (role == "customer") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboard()),
        );
      }
      // ✅ TECHNICIAN
      else if (role == "technician") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TechnicianDashboard()),
        );
      }
      // ✅ ADMIN
      else if (role == "admin") {
        final isApproved = data['isApproved'] ?? false;
        if (isApproved) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPendingScreen()),
          );
        }
      }
      // ✅ DEFAULT
      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      _showSnack(e.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ✅ MERCHANT NAVIGATION LOGIC (UNCHANGED)
  Future<void> _handleMerchantNavigation(User user) async {
    try {
      print('═══════════════════════════════════════════');
      print('🏪 MERCHANT LOGIN - Checking status');
      print('🔑 userId: ${user.uid}');
      print('📧 userEmail: ${user.email}');
      print('═══════════════════════════════════════════');

      final merchantDoc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(user.uid)
          .get();

      if (!merchantDoc.exists) {
        print('❌ No merchant data found → MerchantDetailScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantDetailScreen(
              userId: user.uid,
              userEmail: user.email ?? '',
            ),
          ),
        );
        return;
      }

      final merchantData = merchantDoc.data() as Map<String, dynamic>;
      final status = merchantData['status'] ?? 'pending';
      print('📌 Merchant Status: $status');

      if (!mounted) return;

      switch (status) {
        case 'pending':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StepTwoScreen(
                userId: user.uid,
                userEmail: user.email ?? '',
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
                userEmail: user.email ?? '',
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
                userEmail: user.email ?? '',
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
                userEmail: user.email ?? '',
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
                userEmail: user.email ?? '',
              ),
            ),
          );
          break;

        case 'active':
        case 'approved':
          print('➡️ Status: $status → Merchant Dashboard');
          // TODO: Merchant Dashboard
          break;

        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MerchantDetailScreen(
                userId: user.uid,
                userEmail: user.email ?? '',
              ),
            ),
          );
      }
    } catch (e) {
      print('❌ Error in merchant navigation: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantDetailScreen(
            userId: user.uid,
            userEmail: user.email ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _saveOneSignalId(String userId, String role) async {
    try {
      await OneSignalNotificationService.initialize();

      String? oneSignalId;
      for (int i = 0; i < 10; i++) {
        oneSignalId = OneSignal.User.pushSubscription.id;
        if (oneSignalId != null && oneSignalId.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (oneSignalId == null || oneSignalId.isEmpty) {
        print("❌ OneSignal ID not available yet");
        return;
      }

      await FirebaseFirestore.instance.collection("users").doc(userId).set({
        'oneSignalId': oneSignalId,
        'role': role,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ OneSignal ID saved: $oneSignalId');
    } catch (e) {
      print('❌ Error saving OneSignal ID: $e');
    }
  }

  // ✅ GUEST LOGIN
  Future<void> _continueAsGuest() async {
    if (_guestNavigating) return;
    setState(() => _guestNavigating = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CustomerDashboard(isGuest: true),
        ),
      );
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _guestNavigating = false);
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

  // ═══════════════════════════════════════════════════════
  // BUILD — Image poori screen par, Stack mein content
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Image ka base color — taake black area na dikhe
      backgroundColor: const Color(0xFF4A6B7C),

      // ✅ resizeToAvoidBottomInset — keyboard khulne par layout adjust ho
      resizeToAvoidBottomInset: false,

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // ═══════════════════════════════════════════════
            // ✅ LAYER 1: IMAGE — POORI SCREEN PAR (Stretch)
            // ═══════════════════════════════════════════════
            Positioned.fill(
              child: Image.asset(
                'assets/images/signUpUI.PNG',
                // ✅ fill = poori screen par stretch (koi black area nahi)
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF4A6B7C),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image,
                              size: 100, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Image not found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ═══════════════════════════════════════════════
            // ✅ LAYER 2: DARK OVERLAY (sirf neeche, fields ke liye)
            // ═══════════════════════════════════════════════
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,                      // top clear
                      Colors.black.withOpacity(0.15),          // thoda
                      Colors.black.withOpacity(0.45),          // middle
                      Colors.black.withOpacity(0.65),          // bottom dark
                    ],
                    stops: const [0.0, 0.35, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════
            // ✅ LAYER 3: SCROLLABLE CONTENT
            // ═══════════════════════════════════════════════
            SafeArea(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                        padding: EdgeInsets.only(
                        left: 25,
                        right: 25,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 300), // ✅ top space (image ke text ke liye)
                      const SizedBox(height: 8),

                      const SizedBox(height: 40),

                      // ═══ EMAIL ═══
                      _buildTextField(
                        controller: emailController,
                        hint: "Email",
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 18),

                      // ═══ PASSWORD ═══
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
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ═══ FORGOT PASSWORD ═══
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Color(0xff42D7D7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ═══ LOGIN BUTTON ═══
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : loginUser,
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
                                  : const Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ═══ GUEST LOGIN ═══
                      TextButton(
                        onPressed: _guestNavigating ? null : _continueAsGuest,
                        child: Text(
                          _guestNavigating
                              ? 'Opening...'
                              : 'Visit as a Guest',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ═══ TERMS ═══
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isTermsAccepted,
                              onChanged: (value) {
                                setState(
                                        () => _isTermsAccepted = value ?? false);
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

                      const SizedBox(height: 12),

                      // ═══ SIGNUP LINK ═══
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Signup",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff42D7D7),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HELPER: Glassy TextField
  // ═══════════════════════════════════════════════════════
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: suffixIcon,
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