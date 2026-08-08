import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:thumstechs/Services/oneSignalNotificationService.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:thumstechs/presentation/TechnicianScreen/TechnicianMyServicesScreen.dart';

// ✅ Admin Screens (Web Only)
import 'Admin/AdminScreens/AdminDashboard.dart';
import 'Admin/AdminScreens/AdminLoginScreen.dart';
import 'Admin/AdminScreens/AdminPendingScreen.dart';
import 'Admin/AdminScreens/AdminSignupScreen.dart';

// ✅ Services
// import 'Services/oneSignalNotificationService.dart';
import 'firebase_options.dart';

// ✅ User Screens (Mobile Only)
import 'presentation/authScreen/splashScreen.dart';
import 'presentation/CostomerScreens/ServiceDetailScreen.dart';
import 'presentation/authScreen/ChatScreen.dart';
import 'presentation/CostomerScreens/BookingScreen.dart';
import 'presentation/DashBoard/CustomerDashboard.dart';
import 'presentation/DashBoard/TechnicianDashboard.dart';
import 'presentation/authScreen/LoginScreen.dart';
import 'presentation/authScreen/SignupScreen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ================= FIREBASE =================
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("✅ Firebase Initialized");

  // ================= ONESIGNAL INIT (Mobile Only) =================
  if (!kIsWeb) {
    try {
      OneSignal.initialize("36709973-f516-4746-a694-c58ad52a532d");
      await OneSignalNotificationService.initialize();
      // await OneSignal.Notifications.requestPermission(true);
      print("✅ OneSignal Initialized");

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        OneSignal.login(user.uid);
        await OneSignalNotificationService.saveCurrentUserOneSignalId();
      }

      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData ?? {};
        print('📱 Notification clicked: $data');
        _handleNotificationTap(Map<String, dynamic>.from(data));
      });
    } catch (e) {
      print('❌ OneSignal Error (skipping for web): $e');
    }
  } else {
    print('⚠️ OneSignal: Web platform detected, skipping initialization');
  }

  runApp(const MyApp());
}

// ================= HANDLE NOTIFICATION TAP =================
void _handleNotificationTap(Map<String, dynamic> data) {
  String type = data['type'] ?? '';

  if (type == 'new_request') {
    navigatorKey.currentState?.pushNamed(
      '/service-details',
      arguments: {'serviceName': data['serviceName'] ?? 'Service Request'},
    );
  } else if (type == 'new_message') {
    final conversationId = data['conversationId'] ?? '';
    final requestId = data['requestId'] ?? '';
    String otherUserId = data['senderId'] ?? '';
    final otherUserName = data['senderName'] ?? 'User';
    final otherUserRole = data['senderRole'] ?? 'customer';

    if (otherUserId.isEmpty && conversationId.isNotEmpty) {
      final parts = conversationId.split('_');
      if (parts.length >= 3) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          if (parts[1] == currentUser.uid) {
            otherUserId = parts[2];
          } else {
            otherUserId = parts[1];
          }
        }
      }
    }

    if (otherUserId.isEmpty) {
      print('❌ ERROR: Cannot navigate - otherUserId is empty');
      return;
    }

    navigatorKey.currentState?.pushNamed(
      '/chat',
      arguments: {
        'conversationId': conversationId,
        'requestId': requestId,
        'otherUserId': otherUserId,
        'otherUserName': otherUserName,
        'otherUserRole': otherUserRole,
      },
    );
  } else if (type == 'request_accepted' || type == 'task') {
    navigatorKey.currentState?.pushNamed('/technician-dashboard');
  } else {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((doc) {
            if (doc.exists) {
              final role = doc.data()?['role'] ?? 'customer';
              if (role == 'technician') {
                navigatorKey.currentState?.pushNamed('/technician-dashboard');
              } else if (role == 'admin') {
                navigatorKey.currentState?.pushNamed('/admin-dashboard');
              } else {
                navigatorKey.currentState?.pushNamed('/customer-dashboard');
              }
            }
          })
          .catchError((e) {
            print('❌ Error fetching user role: $e');
            navigatorKey.currentState?.pushNamed('/login');
          });
    } else {
      navigatorKey.currentState?.pushNamed('/login');
    }
  }
}

// ================= MAIN APP =================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Thumb Tech',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF42D7D7),
          primary: const Color(0xFF42D7D7),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      ),
      // ✅ Web: Admin Login, Mobile: Splash Screen
      initialRoute: kIsWeb ? '/admin-login' : '/',
      routes: {
        // ✅ Mobile Routes Only
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/customer-dashboard': (context) => const CustomerDashboard(),
        '/technician-dashboard': (context) => const TechnicianDashboard(),
        '/technician-my-services': (context) => const TechnicianMyServicesScreen(),

        // ✅ Admin Routes (Web + Mobile if needed)
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-signup': (context) => const AdminSignupScreen(),
        '/admin-pending': (context) => const AdminPendingScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),

        // ✅ Common Routes (Both Web & Mobile)
        '/service-details': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ServiceDetailScreen(serviceName: args['serviceName'] ?? '');
        },
        '/chat': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return ChatScreen(
            conversationId: args['conversationId'] ?? '',
            requestId: args['requestId'] ?? '',
            otherUserId: args['otherUserId'] ?? '',
            otherUserName: args['otherUserName'] ?? 'User',
            otherUserRole: args['otherUserRole'] ?? 'customer',
          );
        },
        '/my-bookings': (context) => const BookingScreen(),
      },
      // ✅ Error handling for unknown routes
      onGenerateRoute: (settings) {
        // Web: Admin Login, Mobile: Splash Screen
        if (kIsWeb) {
          return MaterialPageRoute(
            builder: (context) => const AdminLoginScreen(),
          );
        }
        return MaterialPageRoute(builder: (context) => const SplashScreen());
      },
    );
  }
}
