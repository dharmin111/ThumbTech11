// lib/presentation/DashBoard/TechnicianDashboard.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/FirebaseMessageService.dart';
import '../../Services/oneSignalNotificationService.dart';
import '../../Store/StoreScreen.dart';
import '../TechnicianScreen/TechnicianHomeScreen.dart';
import '../TechnicianScreen/TechnicianMyServicesScreen.dart';
import '../TechnicianScreen/TechnicianProfileScreen.dart';
import '../authScreen/ChatListScreen.dart';

class TechnicianDashboard extends StatefulWidget {
  const TechnicianDashboard({super.key});

  @override
  State<TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<TechnicianDashboard> {
  int _selectedIndex = 0;

  // 🔥 Static - Initialize only once
  static bool _isInitialized = false;

  // ✅ Chat unread count
  int _totalUnread = 0;

  // ✅ Timer for polling
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startPolling();
  }

  void _startPolling() {
    _fetchUnreadCount();

    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final technicianQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('technicianId', isEqualTo: currentUser.uid)
          .get();

      int count = 0;

      for (var doc in technicianQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'active') {
          final unread = data['technicianUnreadCount'] ?? 0;
          count += unread is int ? unread : 0;
        }
      }

      if (mounted) {
        setState(() {
          _totalUnread = count;
        });
        print('📊 Technician unread count: $_totalUnread');
      }
    } catch (e) {
      print('❌ Error fetching unread count: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    if (_isInitialized) {
      print('✅ OneSignal already initialized');
      return;
    }

    try {
      await OneSignalNotificationService.initialize();
      _isInitialized = true;
      await _saveOneSignalId();
    } catch (e) {
      print('❌ Notification init error: $e');
    }
  }

  Future<void> _saveOneSignalId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final existingId = userDoc.data()?['oneSignalId'];

      if (existingId == null || existingId.toString().isEmpty) {
        print('📱 Saving OneSignal ID for technician...');

        await OneSignalNotificationService.saveOneSignalId(
          userId: user.uid,
          userRole: 'technician',
        );

        print('✅ OneSignal ID saved successfully');
      } else {
        print('✅ OneSignal ID already exists: $existingId');
      }
    } catch (e) {
      print('❌ Error saving OneSignal ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Screens list with Store tab (5 tabs)
    final List<Widget> screens = [
      const TechnicianHomeScreen(),        // 0 - Home
      const TechnicianMyServicesScreen(),  // 1 - My Services
      const ChatListScreen(),              // 2 - Chat
      const StoreScreen(),                 // 3 - Store ✅ NEW
      const TechnicianProfileScreen(),     // 4 - Profile
    ];

    // ✅ Bottom Nav Items with Chat Badge (5 tabs)
    final List<BottomNavigationBarItem> navItems = [
      // 1. Home
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),

      // 2. My Services
      const BottomNavigationBarItem(
        icon: Icon(Icons.build_outlined),
        activeIcon: Icon(Icons.build),
        label: 'My Services',
      ),

      // 3. Chat (with badge)
      BottomNavigationBarItem(
        icon: Stack(
          children: [
            const Icon(Icons.chat_bubble_outline),
            if (_totalUnread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _totalUnread > 99 ? '99+' : _totalUnread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        activeIcon: Stack(
          children: [
            const Icon(Icons.chat),
            if (_totalUnread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _totalUnread > 99 ? '99+' : _totalUnread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: 'Chat',
      ),

      // ✅ 4. Store (NEW - between Chat and Profile)
      const BottomNavigationBarItem(
        icon: Icon(Icons.store_outlined),
        activeIcon: Icon(Icons.store),
        label: 'Store',
      ),

      // 5. Profile
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Technician Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
        actions: const [],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        elevation: 8,
        items: navItems,
      ),
    );
  }
}