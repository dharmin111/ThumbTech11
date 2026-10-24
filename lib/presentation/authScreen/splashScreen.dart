// presentation/authScreen/splashScreen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../Userform/UserInfoScreen.dart';
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
      debugPrint('✅ OneSignal permission requested');
    } catch (e) {
      debugPrint('❌ OneSignal permission error: $e');
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
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
              );
            }
            return;
          }

          if (role == 'admin' && isApproved) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            }
            return;
          }

          if (role == 'admin' && !isApproved) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPendingScreen(),
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('❌ Error checking admin status: $e');
      }
    }

    // ✅ Default: Admin Login
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
      );
    }
  }

  // ✅ Mobile Navigation - COMPLETE FIXED WITH ROLE & PROFILE VALIDATION
  Future<void> _navigateToScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    // ✅ If no user, go to LoginScreen
    if (user == null) {
      debugPrint('❌ No user logged in, going to LoginScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔑 SplashScreen - User found');
    debugPrint('📌 User UID: ${user.uid}');
    debugPrint('📌 User Email: ${user.email}');
    debugPrint('═══════════════════════════════════════════');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // ✅ If user document does not exist, go to UserInfoScreen to select role & complete profile
      if (!doc.exists || doc.data() == null) {
        debugPrint('⚠️ User document does not exist in Firestore → UserInfoScreen');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserInfoScreen()),
        );
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // ✅ Check if user is active
      final isActive = data['isActive'] ?? true;
      if (!isActive) {
        debugPrint('❌ User is deactivated!');
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      // ✅ Get user role
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      debugPrint('👤 User Role: $role');

      if (role.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserInfoScreen()),
        );
        return;
      }

      // ✅ CUSTOMER
      if (role == 'customer') {
        final hasName = (data['name'] != null && data['name'].toString().trim().isNotEmpty);
        final hasPhone = ((data['phoneNumber'] != null && data['phoneNumber'].toString().trim().isNotEmpty) ||
                          (data['phone'] != null && data['phone'].toString().trim().isNotEmpty));

        if (!mounted) return;

        if (hasName && hasPhone) {
          debugPrint('✅ Customer profile complete → CustomerDashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDashboard()),
          );
        } else {
          debugPrint('⚠️ Customer profile incomplete → UserInfoScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserInfoScreen()),
          );
        }
        return;
      }

      // ✅ TECHNICIAN
      if (role == 'technician') {
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
          debugPrint('✅ Technician profile complete → TechnicianDashboard');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TechnicianDashboard()),
          );
        } else {
          debugPrint('⚠️ Technician profile incomplete → UserInfoScreen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserInfoScreen()),
          );
        }
        return;
      }

      // ✅ MERCHANT
      if (role == 'merchant') {
        debugPrint('✅ Navigating to Merchant Flow');

        final merchantDoc = await FirebaseFirestore.instance
            .collection('merchants')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (!merchantDoc.exists) {
          debugPrint('❌ No merchant data found → MerchantDetailScreen');
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

        final merchantData = merchantDoc.data() as Map<String, dynamic>;
        final status = merchantData['status'] ?? 'pending';

        switch (status) {
          case 'pending':
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
          case 'pending_approval':
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
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StepSevenScreen(
                  userId: user.uid,
                  userEmail: user.email ?? '',
                ),
              ),
            );
            break;

          default:
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
        return;
      }

      // ✅ ADMIN
      if (role == 'admin') {
        final isApproved = data['isApproved'] ?? false;
        if (!mounted) return;
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
        return;
      }

      // DEFAULT FALLBACK -> UserInfoScreen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserInfoScreen()),
      );
    } catch (e) {
      debugPrint('❌ Error checking user role: $e');
      if (!mounted) return;
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
