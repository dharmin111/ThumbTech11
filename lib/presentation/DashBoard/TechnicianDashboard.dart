import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/FirebaseMessageService.dart';
import '../../Services/oneSignalNotificationService.dart';
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
    _startPolling(); // ✅ Start polling every 2 seconds
  }

  void _startPolling() {
    // ✅ Initial fetch immediately
    _fetchUnreadCount();

    // ✅ Then fetch every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // ✅ Query conversations where user is technician
      final technicianQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('technicianId', isEqualTo: currentUser.uid)
          .get();

      int count = 0;

      // ✅ Count technician unread
      for (var doc in technicianQuery.docs) {
        final data = doc.data();
        // ✅ Only count active conversations
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
    // ✅ Cancel timer to avoid memory leaks
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    // 🔥 If already initialized, don't do again
    if (_isInitialized) {
      print('✅ OneSignal already initialized');
      return;
    }

    try {
      // Initialize OneSignal
      await OneSignalNotificationService.initialize();
      _isInitialized = true;

      // Save OneSignal ID
      await _saveOneSignalId();
    } catch (e) {
      print('❌ Notification init error: $e');
    }
  }

  Future<void> _saveOneSignalId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if OneSignal ID already exists
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
    // Screens list with Chat tab
    final List<Widget> screens = [
      const TechnicianHomeScreen(),
      const TechnicianMyServicesScreen(),
      const ChatListScreen(), // ✅ Chat tab - 3rd position
      const TechnicianProfileScreen(), // ✅ Profile - 4th position
    ];

    // Bottom Nav Items with Chat Badge
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.build_outlined),
        activeIcon: Icon(Icons.build),
        label: 'My Services',
      ),
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
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        elevation: 8,
        items: navItems,
      ),
    );
  }
}
