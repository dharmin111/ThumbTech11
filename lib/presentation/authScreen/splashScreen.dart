// presentation/authScreen/splashScreen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../Admin/AdminScreens/AdminDashboard.dart';
import '../../Admin/AdminScreens/AdminLoginScreen.dart';
import '../../Admin/AdminScreens/AdminPendingScreen.dart';
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
    //
    // // ✅ Mobile: OneSignal Permission
    // try {
    //   OneSignal.Notifications.requestPermission(true);
    //   print('✅ OneSignal permission requested');
    // } catch (e) {
    //   print('❌ OneSignal permission error: $e');
    // }
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
        // final doc = await FirebaseFirestore.instance
        //     .collection('users')
        //     .doc(user.uid)
        //     .get();
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final role = data['role'] ?? 'customer';
          final isApproved = data['isApproved'] ?? false;

          // ✅ CHECK: Is user active?
          final isActive = data['isActive'] ?? true;

          if (!isActive) {
            // User is deactivated - sign out
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
            );
            return;
          }

          // ✅ Admin approved → Dashboard
          if (role == 'admin' && isApproved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboard()),
            );
            return;
          }

          // ✅ Admin pending
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

  // ✅ Mobile Navigation
  Future<void> _navigateToScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // ✅ CHECK: Is user active?
      final isActive = data['isActive'] ?? true;

      if (!isActive) {
        // ✅ User is deactivated - Sign out and go to login
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      final role = data['role'] ?? 'customer';

      switch (role) {
        case 'technician':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const TechnicianDashboard(),
            ),
          );
          break;
        case 'admin':
          final isApproved = data['isApproved'] ?? false;
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDashboard()),
          );
      }
    } catch (e) {
      print('❌ Error checking user role: $e');
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
