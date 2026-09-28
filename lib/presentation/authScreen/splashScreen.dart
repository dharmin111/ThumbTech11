// presentation/authScreen/splashScreen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepSevenScreen.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepSixScreen.dart';
import '../../Admin/AdminScreens/AdminDashboard.dart';
import '../../Admin/AdminScreens/AdminLoginScreen.dart';
import '../../Admin/AdminScreens/AdminPendingScreen.dart';
import '../Marchant_screens/Merchant_Detail_Screen.dart';
import '../Marchant_screens/StepTwoScreen.dart';
import '../Marchant_screens/StepThreeScreen.dart';
import '../Marchant_screens/StepFourScreen.dart';
import '../Marchant_screens/StepFiveScreen.dart';
import '../authScreen/LoginScreen.dart';
import '../DashBoard/CustomerDashboard.dart';
import '../DashBoard/TechnicianDashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // ✅ Web par direct Admin Login (Splash skip)
    if (kIsWeb) {
      _redirectToAdmin();
      return;
    }

    // ✅ Mobile: OneSignal Permission
    try {
      OneSignal.Notifications.requestPermission(true);
      print('✅ OneSignal permission requested');
    } catch (e) {
      print('❌ OneSignal permission error: $e');
    }

    // ✅ Mobile: Check user status
    _navigateToScreen();
  }

  // ✅ Web Redirect to Admin
  Future<void> _redirectToAdmin() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final role = data['role'] ?? 'customer';
          final isApproved = data['isApproved'] ?? false;
          final isActive = data['isActive'] ?? true;

          if (!isActive) {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
            );
            return;
          }

          if (role == 'admin' && isApproved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
            return;
          }

          if (role == 'admin' && !isApproved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminPendingScreen(),
              ),
            );
            return;
          }
        }
      } catch (e) {
        print('❌ Error checking admin status: $e');
      }
    }

    // ✅ Default: Admin Login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );
  }

  // ✅ Mobile Navigation - COMPLETE FIXED
  Future<void> _navigateToScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    // ✅ If no user, go to Login
    if (user == null) {
      print('❌ No user logged in, going to LoginScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    // ✅ Debug: Print user info
    print('═══════════════════════════════════════════');
    print('🔑 SplashScreen - User found');
    print('📌 User UID: ${user.uid}');
    print('📌 User Email: ${user.email}');
    print('📌 User Display Name: ${user.displayName}');
    print('═══════════════════════════════════════════');

    try {
      // ✅ Get user data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // ✅ If user document doesn't exist, sign out
      if (!doc.exists) {
        print('❌ User document does not exist in Firestore!');
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // ✅ Check if user is active
      final isActive = data['isActive'] ?? true;
      if (!isActive) {
        print('❌ User is deactivated!');
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      // ✅ Get user role
      final role = data['role'] ?? 'customer';
      print('👤 User Role: $role');

      // ✅ Navigate based on role
      switch (role) {
        case 'technician':
          print('✅ Navigating to TechnicianDashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TechnicianDashboard(),
            ),
          );
          break;

        case 'merchant':
        // ✅ MERCHANT LOGIC WITH STATUS
          print('✅ Navigating to Merchant Flow');
          print('🔑 userId: ${user.uid}');
          print('📧 userEmail: ${user.email}');

          // ✅ Get merchant status from Firestore
          final merchantDoc = await FirebaseFirestore.instance
              .collection('merchants')
              .doc(user.uid)
              .get();

          // ✅ Check if merchant document exists
          if (!merchantDoc.exists) {
            // ❌ No merchant data → Go to MerchantDetailScreen
            print('❌ No merchant data found, going to MerchantDetailScreen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MerchantDetailScreen(
                  userId: user.uid,
                  userEmail: user.email ?? '',
                ),
              ),
            );
            return;
          }

          // ✅ Get merchant status
          final merchantData = merchantDoc.data() as Map<String, dynamic>;
          final status = merchantData['status'] ?? 'pending';
          print('📌 Merchant Status: $status');

          // ✅ Navigate based on status
          switch (status) {
            case 'pending':
              print('➡️ Status: pending → StepTwoScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepTwoScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
              break;

            case 'received':
              print('➡️ Status: received → StepThreeScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepThreeScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
              break;
            case 'display':
              print('➡️ Status: display → StepThreeScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepSixScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
              break;

            case 'uploaded':
              print('➡️ Status: uploaded → StepFourScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepFourScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
              break;

            case 'waiting':
              print('➡️ Status: $status → StepFiveScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepFiveScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
            case 'pending_approval':
              print('➡️ Status: $status → StepFiveScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepFiveScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
              break;

            case 'active':
            case 'verified':
              print('➡️ Status: $status → Merchant Dashboard');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>StepSevenScreen(userId: user.uid, userEmail: user.email ?? '')
                ),
              );
              break;

            default:
            // ✅ Default: Go to StepTwoScreen
              print('➡️ Default: going to StepTwoScreen');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StepTwoScreen(
                    userId: user.uid,
                    userEmail: user.email ?? '',
                  ),
                ),
              );
          }
          break;

        case 'admin':
          final isApproved = data['isApproved'] ?? false;
          print('✅ Navigating to Admin - isApproved: $isApproved');
          if (isApproved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminPendingScreen(),
              ),
            );
          }
          break;

        default:
          print('✅ Navigating to CustomerDashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDashboard()),
          );
      }
    } catch (e) {
      print('❌ Error checking user role: $e');
      // ✅ On error, go to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/AppLogoo/splash.PNG',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 🔥 Fallback if image not found
            return Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF42D7D7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.build_circle,
                size: 80,
                color: Color(0xFF42D7D7),
              ),
            );
          },
        ),
      ),
    );
  }
}