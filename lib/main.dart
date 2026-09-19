import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ✅ Services
import 'Services/oneSignalNotificationService.dart';
import 'Services/ReportService.dart';
import 'firebase_options.dart';

// ✅ Admin Screens (Web & Mobile)
import 'Admin/AdminScreens/AdminDashboard.dart';
import 'Admin/AdminScreens/AdminLoginScreen.dart';
import 'Admin/AdminScreens/AdminPendingScreen.dart';
import 'Admin/AdminScreens/AdminSignupScreen.dart';

// ✅ User Screens (Mobile)
import 'presentation/authScreen/splashScreen.dart';
import 'presentation/CostomerScreens/ServiceDetailScreen.dart';
import 'presentation/authScreen/ChatScreen.dart';
import 'presentation/CostomerScreens/BookingScreen.dart';
import 'presentation/CostomerScreens/ServiceBookingScreen.dart';
import 'presentation/DashBoard/CustomerDashboard.dart';
import 'presentation/DashBoard/TechnicianDashboard.dart';
import 'presentation/authScreen/LoginScreen.dart';
import 'presentation/authScreen/SignupScreen.dart';
import 'presentation/TechnicianScreen/TechnicianMyServicesScreen.dart';

// ✅ Profile & Settings
import 'presentation/CostomerScreens/ProfileScreen.dart';
import 'presentation/TechnicianScreen/TechnicianProfileScreen.dart';

// ✅ Privacy & Terms
import 'presentation/privacy/PrivacyPolicyScreen.dart';

// ✅ Report & Block Widgets
import 'presentation/widgets/ReportDialog.dart';
import 'presentation/widgets/BlockDialog.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ================= LOAD .env =================
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env file loaded successfully');
  } catch (e) {
    print('⚠️ .env file not found, using default values');
  }

  // ================= FIREBASE =================
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("✅ Firebase Initialized");

  // ✅ Debug: Check if API key is loaded
  print('Android API Key: ${dotenv.env['Android_Google_Map_Api']}');
  print('iOS API Key: ${dotenv.env['IOS_Google_Map_Api']}');

  // ================= ONESIGNAL INIT (Mobile Only) =================
  if (!kIsWeb) {
    try {
      // ✅ Initialize OneSignal using .env
      await OneSignalNotificationService.initialize();
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
  print('🔍 Notification type: $type');
  print('📦 Data: $data');

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
  } else if (type == 'request_posted') {
    navigatorKey.currentState?.pushNamed('/customer-dashboard');
  } else if (type == 'request_rejected') {
    navigatorKey.currentState?.pushNamed('/customer-dashboard');
  } else if (type == 'report') {
    navigatorKey.currentState?.pushNamed('/admin-dashboard');
  } else if (type == 'service_update') {
    navigatorKey.currentState?.pushNamed('/customer-dashboard');
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
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      // ✅ Web: Admin Login, Mobile: Splash Screen
      initialRoute: kIsWeb ? '/admin-login' : '/',
      routes: {
        // ✅ Mobile Routes
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/customer-dashboard': (context) => const CustomerDashboard(),
        '/technician-dashboard': (context) => const TechnicianDashboard(),
        '/technician-my-services': (context) => const TechnicianMyServicesScreen(),
        '/my-bookings': (context) => const BookingScreen(),
        '/service-bookings': (context) => const ServiceBookingScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/technician-profile': (context) => const TechnicianProfileScreen(),
       // '/privacy-policy': (context) =>  PrivacyPolicyScreen(),
        //'/terms': (context) => const TermsScreen(),

        // ✅ Admin Routes (Web + Mobile)
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-signup': (context) => const AdminSignupScreen(),
        '/admin-pending': (context) => const AdminPendingScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),

        // ✅ Common Routes (Both Web & Mobile)
        '/service-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>? ?? {};
          return ServiceDetailScreen(
            serviceName: args['serviceName'] ?? '',
            editRequestId: args['editRequestId'],
          );
        },
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>? ?? {};
          return ChatScreen(
            conversationId: args['conversationId'] ?? '',
            requestId: args['requestId'] ?? '',
            otherUserId: args['otherUserId'] ?? '',
            otherUserName: args['otherUserName'] ?? 'User',
            otherUserRole: args['otherUserRole'] ?? 'customer',
          );
        },
        '/report-dialog': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>? ?? {};
          return ReportDialog(
            targetId: args['targetId'] ?? '',
            targetType: args['targetType'] ?? '',
            targetName: args['targetName'] ?? '',
            additionalInfo: args['additionalInfo'],
          );
        },
        '/block-dialog': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>? ?? {};
          return BlockDialog(
            userId: args['userId'] ?? '',
            userName: args['userName'] ?? '',
            onBlocked: args['onBlocked'],
          );
        },
      },
      // ✅ Error handling for unknown routes
      onGenerateRoute: (settings) {
        // Default fallback: Web → Admin Login, Mobile → Splash Screen
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