// lib/presentation/authScreen/LoginScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:thumstechs/TechnicianCustomertermAndCondition/TermsAndConditionsScreen.dart';
import 'package:thumstechs/Userform/UserInfoScreen.dart';
import 'package:thumstechs/presentation/DashBoard/CustomerDashboard.dart';
import 'package:thumstechs/presentation/DashBoard/TechnicianDashboard.dart';
import 'package:thumstechs/presentation/Marchant_screens/Merchant_Detail_Screen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepTwoScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepThreeScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepFourScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepFiveScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepSixScreen.dart';
import 'package:thumstechs/presentation/authScreen/signupScreen.dart';
import '../../Admin/AdminScreens/AdminPendingScreen.dart';
import '../../Admin/AdminScreens/AdminDashboard.dart';
import '../../Services/authServices.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../Services/oneSignalNotificationService.dart';
import 'forgetPassword.dart';
import 'PhoneLoginScreen.dart';

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

  // ============================================================
  // LOGIN
  // ============================================================

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

      if (user != null && mounted) {
        _showSnack("Login Successful", Colors.green);
        await _handlePostAuthNavigation(user);
      }
    } catch (e) {
      _showSnack(e.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> _loginWithGoogle() async {
    if (!_isTermsAccepted) {
      _showSnack('Please accept the Terms & Conditions to continue', Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await auth.signInWithGoogle();
      final user = userCredential.user;

      if (user != null && mounted) {
        _showSnack("Google Sign-In Successful", Colors.green);
        await _handlePostAuthNavigation(user);
      }
    } catch (e) {
      debugPrint('Error Google Login: $e');
      _showSnack("Google Sign-In failed: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // APPLE LOGIN
  // ============================================================

  Future<void> _loginWithApple() async {
    if (!_isTermsAccepted) {
      _showSnack('Please accept the Terms & Conditions to continue', Colors.orange);
      return;
    }

    setState(() => isLoading = true);

    try {
      final userCredential = await auth.signInWithApple();
      final user = userCredential.user;

      if (user != null && mounted) {
        _showSnack("Apple Sign-In Successful", Colors.green);
        await _handlePostAuthNavigation(user);
      }
    } catch (e) {
      debugPrint('Error Apple Login: $e');
      _showSnack("Apple Sign-In failed: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // POST AUTHENTICATION ROUTING (CHOOSE SCREEN BASED ON ROLE & PROFILE DATA)
  // ============================================================

  Future<void> _handlePostAuthNavigation(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      // CASE 1: No user document in Firestore -> Send to UserInfoScreen to choose role & fill profile
      if (!doc.exists || doc.data() == null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
        return;
      }

      final data = doc.data()!;
      final isActive = data['isActive'] ?? true;

      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        _showSnack('Your account has been deactivated. Please contact admin +917087234563', Colors.red);
        return;
      }

      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      await _saveOneSignalId(user.uid, role);

      // CASE 2: No role set -> Go to UserInfoScreen
      if (role.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
        return;
      }

      // CASE 3: MERCHANT
      if (role == "merchant") {
        await _handleMerchantNavigation(user);
        return;
      }

      // CASE 4: CUSTOMER
      if (role == "customer") {
        final hasName = (data['name'] != null && data['name'].toString().trim().isNotEmpty);
        final hasPhone = ((data['phoneNumber'] != null && data['phoneNumber'].toString().trim().isNotEmpty) ||
                          (data['phone'] != null && data['phone'].toString().trim().isNotEmpty));

        if (!mounted) return;

        if (hasName && hasPhone) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerDashboard()),
          );
        } else {
          // Customer profile incomplete -> Go to UserInfoScreen to complete profile
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserInfoScreen()),
          );
        }
        return;
      }

      // CASE 5: TECHNICIAN
      if (role == "technician") {
        final hasName = (data['name'] != null && data['name'].toString().trim().isNotEmpty);
        final hasPhone = ((data['phoneNumber'] != null && data['phoneNumber'].toString().trim().isNotEmpty) ||
                          (data['phone'] != null && data['phone'].toString().trim().isNotEmpty));
        final hasAddress = (data['address'] != null && data['address'].toString().trim().isNotEmpty);
        final hasProfilePic = (data['profileImageUrl'] != null && data['profileImageUrl'].toString().trim().isNotEmpty);
        final hasIdCard = ((data['idCardImage'] != null && data['idCardImage'].toString().trim().isNotEmpty) ||
                           (data['idCardImageUrl'] != null && data['idCardImageUrl'].toString().trim().isNotEmpty));
        final hasStorePhotos = ((data['workImages'] != null && (data['workImages'] as List).isNotEmpty) ||
                                (data['previousWorkImageUrls'] != null && (data['previousWorkImageUrls'] as List).isNotEmpty) ||
                                (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty));

        final bool isComplete = hasName && hasPhone && hasAddress && hasProfilePic && hasIdCard && hasStorePhotos;

        if (!mounted) return;

        if (isComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TechnicianDashboard()),
          );
        } else {
          // Technician profile incomplete -> Go to UserInfoScreen / Technician Details to complete profile
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserInfoScreen()),
          );
        }
        return;
      }

      // CASE 6: ADMIN
      if (role == "admin") {
        final isApproved = data['isApproved'] ?? false;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isApproved ? const AdminDashboard() : const AdminPendingScreen(),
          ),
        );
        return;
      }

      // DEFAULT FALLBACK -> UserInfoScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserInfoScreen()),
      );
    } catch (e) {
      debugPrint('Error in post auth navigation: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserInfoScreen()),
      );
    }
  }

  // ============================================================
  // MERCHANT NAVIGATION
  // ============================================================

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
        print(
          '❌ No merchant data found → MerchantDetailScreen',
        );

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

      final merchantData =
      merchantDoc.data() as Map<String, dynamic>;

      final status =
          merchantData['status'] ?? 'pending';

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
          print(
            '➡️ Status: $status → Merchant Dashboard',
          );

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
      print(
        '❌ Error in merchant navigation: $e',
      );

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

  // ============================================================
  // ONESIGNAL
  // ============================================================

  Future<void> _saveOneSignalId(
      String userId,
      String role,
      ) async {
    try {
      await OneSignalNotificationService.initialize();

      String? oneSignalId;

      for (int i = 0; i < 10; i++) {
        oneSignalId =
            OneSignal.User.pushSubscription.id;

        if (oneSignalId != null &&
            oneSignalId.isNotEmpty) {
          break;
        }

        await Future.delayed(
          const Duration(milliseconds: 500),
        );
      }

      if (oneSignalId == null ||
          oneSignalId.isEmpty) {
        print(
          "❌ OneSignal ID not available yet",
        );

        return;
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .set(
        {
          'oneSignalId': oneSignalId,
          'role': role,
          'lastTokenUpdate':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      print(
        '✅ OneSignal ID saved: $oneSignalId',
      );
    } catch (e) {
      print(
        '❌ Error saving OneSignal ID: $e',
      );
    }
  }

  // ============================================================
  // GUEST LOGIN
  // ============================================================

  Future<void> _continueAsGuest() async {
    if (_guestNavigating) return;

    setState(() => _guestNavigating = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CustomerDashboard(
            isGuest: true,
          ),
        ),
      );
    } catch (e) {
      _showSnack(
        'Error: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(
              () => _guestNavigating = false,
        );
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

      // Keyboard opens → screen remains stable
      resizeToAvoidBottomInset: false,

      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
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
                errorBuilder:
                    (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF4A6B7C),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
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

            // ======================================================
            // RESPONSIVE CONTENT
            // ======================================================

            SafeArea(
              child: LayoutBuilder(
                builder: (
                    context,
                    constraints,
                    ) {
                  final height =
                      constraints.maxHeight;

                  /*
                   * Responsive top space.
                   *
                   * Small phone:
                   * around 250-270
                   *
                   * Normal phone:
                   * around 290-320
                   *
                   * Large phone:
                   * around 330+
                   */

                  double topSpace =
                      height * 0.40;

                  // Prevent it becoming too small
                  if (topSpace < 250) {
                    topSpace = 250;
                  }

                  // Prevent it becoming excessively large
                  if (topSpace > 360) {
                    topSpace = 360;
                  }

                  /*
                   * Responsive horizontal padding.
                   */

                  double horizontalPadding =
                      screenWidth * 0.065;

                  if (horizontalPadding < 20) {
                    horizontalPadding = 20;
                  }

                  if (horizontalPadding > 30) {
                    horizontalPadding = 30;
                  }

                  return SingleChildScrollView(
                    physics:
                    const BouncingScrollPhysics(),

                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,

                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      top: topSpace,
                      bottom:
                      // mediaQuery.viewInsets.bottom +
                          30,
                    ),

                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                        height -
                            topSpace -
                            30,
                      ),

                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,

                        children: [

                          // ==================================================
                          // EMAIL
                          // ==================================================

                          _buildTextField(
                            controller:
                            emailController,
                            hint: "Email",
                            icon: Icons.email,
                            keyboardType:
                            TextInputType.emailAddress,
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          // ==================================================
                          // PASSWORD
                          // ==================================================

                          _buildTextField(
                            controller:
                            passwordController,
                            hint: "Password",
                            icon: Icons.lock,
                            obscureText:
                            _obscurePassword,

                            suffixIcon:
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword =
                                  !_obscurePassword;
                                });
                              },

                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                    .visibility_off
                                    : Icons.visibility,
                                color:
                                Colors.white70,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          // ==================================================
                          // FORGOT PASSWORD
                          // ==================================================

                          Align(
                            alignment:
                            Alignment.centerRight,

                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const ForgotPasswordScreen(),
                                  ),
                                );
                              },

                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color:
                                  Color(0xff42D7D7),
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          // ==================================================
                          // LOGIN BUTTON
                          // ==================================================

                          SizedBox(
                            height: 50,
                            width: double.infinity,

                            child: ElevatedButton(
                              onPressed:
                              isLoading
                                  ? null
                                  : loginUser,

                              style:
                              ElevatedButton.styleFrom(
                                shape:
                                RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                    18,
                                  ),
                                ),

                                backgroundColor:
                                Colors.transparent,

                                padding:
                                EdgeInsets.zero,

                                elevation: 0,
                              ),

                              child: Ink(
                                decoration:
                                BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(
                                    18,
                                  ),

                                  gradient:
                                  const LinearGradient(
                                    colors: [
                                      Color(0xff009999),
                                      Color(0xff008976),
                                    ],
                                  ),
                                ),

                                child: Center(
                                  child: isLoading
                                      ? const CircularProgressIndicator(
                                    color:
                                    Colors.white,
                                  )
                                      : const Text(
                                    "Login",
                                    style:
                                    TextStyle(
                                      fontSize: 22,
                                      color:
                                      Colors.white,
                                      fontWeight:
                                      FontWeight.bold,
                                      letterSpacing:
                                      1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ==================================================
                          // SOCIAL LOGIN: GOOGLE & APPLE
                          // ==================================================
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Colors.white38)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  "OR CONTINUE WITH",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: Colors.white38)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // ==========================================
                              // ✅ GOOGLE BUTTON
                              // ==========================================
                              Expanded(
                                child: InkWell(
                                  onTap: isLoading ? null : _loginWithGoogle,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/GA/Google.png',
                                        width: 105,
                                        height: 34,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // ==========================================
                              // ✅ APPLE BUTTON
                              // ==========================================
                              Expanded(
                                child: InkWell(
                                  onTap: isLoading ? null : _loginWithApple,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 52,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/GA/Apple.png',
                                        width: 105,
                                        height: 34,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.apple, size: 24, color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          // ==================================================
                          // GUEST LOGIN
                          // ==================================================

                          TextButton(
                            onPressed:
                            _guestNavigating
                                ? null
                                : _continueAsGuest,

                            child: Text(
                              _guestNavigating
                                  ? 'Opening...'
                                  : 'Visit as a Guest',

                              style:
                              const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          // ==================================================
                          // TERMS
                          // ==================================================

                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.center,

                            children: [

                              SizedBox(
                                width: 24,
                                height: 24,

                                child: Checkbox(
                                  value:
                                  _isTermsAccepted,

                                  onChanged: (value) {
                                    setState(
                                          () =>
                                      _isTermsAccepted =
                                          value ??
                                              false,
                                    );
                                  },

                                  activeColor:
                                  const Color(
                                    0xff009999,
                                  ),

                                  checkColor:
                                  Colors.white,

                                  side:
                                  const BorderSide(
                                    color:
                                    Colors.white70,
                                    width: 1.5,
                                  ),

                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(
                                      5,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child:
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const TermsAndConditionsScreen(),
                                      ),
                                    );
                                  },

                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors
                                            .white
                                            .withOpacity(
                                          0.9,
                                        ),
                                      ),

                                      children:
                                      const [
                                        TextSpan(
                                          text:
                                          'I agree to the ',
                                        ),

                                        TextSpan(
                                          text:
                                          'Terms & Conditions',
                                          style:
                                          TextStyle(
                                            color:
                                            Color(
                                              0xff42D7D7,
                                            ),
                                            fontWeight:
                                            FontWeight
                                                .bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          // ==================================================
                          // SIGNUP
                          // ==================================================

                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,

                            children: [

                              Flexible(
                                child: Text(
                                  "Don't have an account?",
                                  style: TextStyle(
                                    color: Colors.white
                                        .withOpacity(
                                      0.9,
                                    ),
                                    fontSize: 14,
                                  ),
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                ),
                              ),

                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const SignupScreen(),
                                    ),
                                  );
                                },

                                child: const Text(
                                  "Signup",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                    FontWeight.bold,
                                    color:
                                    Color(0xff42D7D7),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      ),
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
        ),

        decoration: InputDecoration(
          filled: true,

          fillColor:
          Colors.white.withOpacity(0.15),

          hintText: hint,

          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
          ),

          prefixIcon: Icon(
            icon,
            color: Colors.white70,
          ),

          suffixIcon: suffixIcon,

          border: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(18),

            borderSide: BorderSide(
              color:
              Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(18),

            borderSide: BorderSide(
              color:
              Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(18),

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