// lib/Admin/AdminScreens/AdminDashboard.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../widget/hover_scale.dart';
import 'AdminBookingsScreen.dart';
import 'AdminRequestsScreen.dart';
import 'AdminStatsScreen.dart';
import 'AdminUsersScreen.dart';
import 'AdminUserDetailScreen.dart';
import 'AdminTodayActivityScreen.dart';
import 'AdminReportedUsersScreen.dart';
import 'AdminSupportMessagesScreen.dart';
import 'Admin_Blocked_Users_Screen.dart';
import 'AdminMerchantsScreen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // ✅ Stats Variables
  int _totalUsers = 0;
  int _totalRequests = 0;
  int _totalBookings = 0;
  int _totalRevenue = 0;

  // ✅ New Today Stats
  int _newUsersToday = 0;
  int _newTechniciansToday = 0;
  int _newCustomersToday = 0;
  int _newMerchantsToday = 0;
  int _newRequestsToday = 0;

  // ✅ Recent Users
  List<Map<String, dynamic>> _recentUsers = [];

  // ✅ Blocked & Reported & Support Stats
  int _totalBlockedUsers = 0;
  int _totalReportedUsers = 0;
  int _totalSupportMessages = 0;

  // ✅ Merchant Stats
  int _totalMerchants = 0;
  int _totalVerifiedMerchants = 0;
  int _totalPendingMerchants = 0;

  // ✅ Stream Subscriptions
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  StreamSubscription<QuerySnapshot>? _blockedUsersSubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;
  StreamSubscription<QuerySnapshot>? _supportMessagesSubscription;
  StreamSubscription<QuerySnapshot>? _merchantsSubscription;

  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _startRealTimeListeners();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _blockedUsersSubscription?.cancel();
    _reportsSubscription?.cancel();
    _supportMessagesSubscription?.cancel();
    _merchantsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ✅ Helper: Check if user has complete data
  bool _isCompleteUser(Map<String, dynamic> data) {
    final name = data['name']?.toString().trim() ?? '';
    final role = data['role']?.toString().trim() ?? '';
    final email = data['email']?.toString().trim() ?? '';
    return name.isNotEmpty && role.isNotEmpty && email.isNotEmpty;
  }

  // ✅ REAL-TIME LISTENERS
  void _startRealTimeListeners() {
    // Users
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) => _processUsersData(snapshot),
      onError: (error) => print('❌ Users stream error: $error'),
    );

    // Requests
    _requestsSubscription = FirebaseFirestore.instance
        .collection('service_requests')
        .snapshots()
        .listen(
          (snapshot) => _processRequestsData(snapshot),
      onError: (error) => print('❌ Requests stream error: $error'),
    );

    // Bookings
    _bookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .snapshots()
        .listen(
          (snapshot) {
        _totalBookings = snapshot.docs.length;
        if (mounted) setState(() {});
      },
      onError: (error) => print('❌ Bookings stream error: $error'),
    );

    // Blocked Users
    _blockedUsersSubscription = FirebaseFirestore.instance
        .collection('blocked_users')
        .snapshots()
        .listen(
          (snapshot) {
        _totalBlockedUsers = snapshot.docs.length;
        if (mounted) setState(() {});
      },
      onError: (error) => print('❌ Blocked users stream error: $error'),
    );

    // Reports
    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) {
        _totalReportedUsers = snapshot.docs.length;
        if (mounted) setState(() {});
      },
      onError: (error) => print('❌ Reports stream error: $error'),
    );

    // Support Messages
    _supportMessagesSubscription = FirebaseFirestore.instance
        .collection('support_messages')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) {
        _totalSupportMessages = snapshot.docs.length;
        if (mounted) setState(() {});
      },
      onError: (error) => print('❌ Support messages stream error: $error'),
    );

    // Merchants
    _merchantsSubscription = FirebaseFirestore.instance
        .collection('merchants')
        .snapshots()
        .listen(
          (snapshot) => _processMerchantsData(snapshot),
      onError: (error) => print('❌ Merchants stream error: $error'),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // ✅ Process Users Data - ONLY COMPLETE USERS
  void _processUsersData(QuerySnapshot snapshot) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    print('═══════════════════════════════════════════');
    print('📊 USERS PROCESSING');
    print('   Total docs: ${snapshot.docs.length}');

    // ✅ Filter: only complete users
    final completeUsers = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _isCompleteUser(data);
    }).toList();

    print('   ✅ Complete: ${completeUsers.length}');
    print('   ❌ Incomplete: ${snapshot.docs.length - completeUsers.length}');
    print('═══════════════════════════════════════════');

    // ✅ Total Users (only complete)
    _totalUsers = completeUsers.length;

    // ✅ New Users Today
    _newUsersToday = completeUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow);
    }).length;

    // ✅ New Technicians Today
    _newTechniciansToday = completeUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow) &&
          data['role'] == 'technician';
    }).length;

    // ✅ New Customers Today
    _newCustomersToday = completeUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow) &&
          data['role'] == 'customer';
    }).length;

    // ✅ New Merchants Today
    _newMerchantsToday = completeUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow) &&
          data['role'] == 'merchant';
    }).length;

    // ✅ Recent Users (complete only, exclude admins)
    final usersList = completeUsers
        .where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['role'] != 'admin';
    })
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // ✅ Sort by createdAt (newest first)
    usersList.sort((a, b) {
      final aDate =
          (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bDate =
          (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    _recentUsers = usersList.take(5).toList();

    if (mounted) setState(() {});
  }

  // ✅ Process Requests Data
  void _processRequestsData(QuerySnapshot snapshot) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    _totalRequests = snapshot.docs.length;

    _newRequestsToday = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow);
    }).length;

    int revenue = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'completed') {
        final budget = data['budget'];
        if (budget != null) {
          revenue += (budget is int) ? budget : (budget as num).toInt();
        }
      }
    }
    _totalRevenue = revenue;

    if (mounted) setState(() {});
  }

  // ✅ Process Merchants Data
  void _processMerchantsData(QuerySnapshot snapshot) {
    _totalMerchants = snapshot.docs.length;

    _totalVerifiedMerchants = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['isVerified'] == true;
    }).length;

    _totalPendingMerchants = _totalMerchants - _totalVerifiedMerchants;

    if (mounted) setState(() {});
  }

  // ✅ Manual Refresh
  Future<void> _refreshData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data refreshed automatically!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildDashboard(),
      const AdminUsersScreen(),
      const AdminRequestsScreen(),
      const AdminBookingsScreen(),
      const AdminStatsScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ==================== BOTTOM NAV BAR ====================
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          HapticFeedback.mediumImpact();
          setState(() => _selectedIndex = index);
        },
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        backgroundColor: Colors.transparent,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Statistics',
          ),
        ],
      ),
    );
  }

  // ==================== DASHBOARD ====================
  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          _HoverIconButton(
            icon: Icons.refresh,
            color: const Color(0xFF2563EB),
            onTap: _refreshData,
          ),
          _HoverIconButton(
            icon: Icons.logout,
            color: Colors.red,
            onTap: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildWelcomeHeader(),
              ),
              const SizedBox(height: 20),

              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildTodayStats(),
              ),
              const SizedBox(height: 20),

              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStatsGrid(),
              ),
              const SizedBox(height: 24),

              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildRecentUsers(),
              ),
              const SizedBox(height: 24),

              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildSecurityAndSupportCards(),
              ),
              const SizedBox(height: 24),

              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildRecentActivities(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WELCOME HEADER ====================
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withAlpha(77),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Admin!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Live data updating in real-time',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withAlpha(128)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.green, size: 8),
                SizedBox(width: 6),
                Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TODAY'S STATS ====================
  Widget _buildTodayStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                "Today's Activity",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTodayStatCard(
                title: 'Users',
                value: _newUsersToday.toString(),
                icon: Icons.person_add,
                color: Colors.blue,
                onTap: () => _navigateToToday('users', _newUsersToday),
              ),
              _buildTodayStatCard(
                title: 'Tasks',
                value: _newRequestsToday.toString(),
                icon: Icons.add_task,
                color: Colors.orange,
                onTap: () => _navigateToToday('tasks', _newRequestsToday),
              ),
              _buildTodayStatCard(
                title: 'Customers',
                value: _newCustomersToday.toString(),
                icon: Icons.person,
                color: Colors.green,
                onTap: () => _navigateToToday('customers', _newCustomersToday),
              ),
              _buildTodayStatCard(
                title: 'Techs',
                value: _newTechniciansToday.toString(),
                icon: Icons.build,
                color: Colors.purple,
                onTap: () =>
                    _navigateToToday('technicians', _newTechniciansToday),
              ),
              _buildTodayStatCard(
                title: 'Merchants',
                value: _newMerchantsToday.toString(),
                icon: Icons.store,
                color: Colors.teal,
                onTap: () => _navigateToToday('merchants', _newMerchantsToday),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToToday(String type, int count) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminTodayActivityScreen(
          type: type,
          count: count,
        ),
      ),
    );
  }

  // ==================== TODAY STAT CARD ====================
  Widget _buildTodayStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: HoverScale(
        hoverScale: 1.05,
        onTap: onTap,
        builder: (context, isHovering, isPressed) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isHovering ? color.withAlpha(38) : color.withAlpha(12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovering ? color : color.withAlpha(25),
                width: isHovering ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== STATS GRID ====================
  Widget _buildStatsGrid() {
    final stats = [
      {
        'title': 'Total Users',
        'value': _totalUsers.toString(),
        'icon': Icons.people,
        'gradient': const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        'subtitle': 'Registered users',
        'index': 1,
      },
      {
        'title': 'Total Requests',
        'value': _totalRequests.toString(),
        'icon': Icons.request_page,
        'gradient': const [Color(0xFFF59E0B), Color(0xFFD97706)],
        'subtitle': 'Service requests',
        'index': 2,
      },
      {
        'title': 'Total Bookings',
        'value': _totalBookings.toString(),
        'icon': Icons.book_online,
        'gradient': const [Color(0xFF10B981), Color(0xFF059669)],
        'subtitle': 'Confirmed bookings',
        'index': 3,
      },
      {
        'title': 'Total Revenue',
        'value': '₹${_totalRevenue.toString()}',
        'icon': Icons.attach_money,
        'gradient': const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        'subtitle': 'Total earnings',
        'index': 4,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(
          title: stat['title'] as String,
          value: stat['value'] as String,
          icon: stat['icon'] as IconData,
          colors: stat['gradient'] as List<Color>,
          subtitle: stat['subtitle'] as String,
          navigateIndex: stat['index'] as int,
        );
      },
    );
  }

  // ==================== STAT CARD ====================
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
    required String subtitle,
    required int navigateIndex,
  }) {
    return HoverScale(
      onTap: () {
        if (navigateIndex <= 3) {
          setState(() => _selectedIndex = navigateIndex);
        }
      },
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors[0].withAlpha(isHovering ? 115 : 77),
                blurRadius: isHovering ? 22 : 12,
                offset: Offset(0, isHovering ? 10 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(128),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withAlpha(204),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(153),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== RECENT USERS (ONLY COMPLETE) ====================
  Widget _buildRecentUsers() {
    if (_recentUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.person_add, color: Color(0xFF2563EB), size: 20),
                SizedBox(width: 8),
                Text(
                  'Recent Users',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Icon(Icons.people_outline, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No complete users yet',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Recent Users',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'Live updates',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentUsers.map((user) {
            final name = user['name']?.toString().trim() ?? 'Unknown';
            final email = user['email']?.toString().trim() ?? '';
            final role = user['role']?.toString().trim() ?? 'customer';
            final uid = user['uid'] ?? user['id'] ?? '';
            final createdAt = (user['createdAt'] as Timestamp?)?.toDate();
            final timeAgo = _getTimeAgo(createdAt);
            final isActive = user['isActive'] ?? true;

            // ✅ Role-based color, icon, label
            Color roleColor;
            IconData roleIcon;
            String roleLabel;

            switch (role) {
              case 'technician':
                roleColor = Colors.blue;
                roleIcon = Icons.build;
                roleLabel = 'Tech';
                break;
              case 'merchant':
                roleColor = Colors.teal;
                roleIcon = Icons.store;
                roleLabel = 'Merchant';
                break;
              default:
                roleColor = Colors.green;
                roleIcon = Icons.person;
                roleLabel = 'Customer';
            }

            return HoverScale(
              onTap: () {
                if (uid.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminUserDetailScreen(
                      userId: uid,
                      userData: user,
                    ),
                  ),
                );
              },
              builder: (context, isHovering, isPressed) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                    isHovering ? Colors.grey.shade50 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: roleColor.withAlpha(25),
                      child: Icon(roleIcon, color: roleColor, size: 16),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: roleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // ==================== SECURITY & SUPPORT CARDS ====================
  Widget _buildSecurityAndSupportCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildModerationCard(
          title: 'Merchants',
          count: _totalMerchants,
          icon: Icons.store,
          color: Colors.teal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminMerchantsScreen(),
              ),
            );
          },
        ),
        _buildModerationCard(
          title: 'Blocked',
          count: _totalBlockedUsers,
          icon: Icons.block,
          color: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminBlockedUsersScreen(),
              ),
            );
          },
        ),
        _buildModerationCard(
          title: 'Reports',
          count: _totalReportedUsers,
          icon: Icons.flag,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminReportedUsersScreen(),
              ),
            );
          },
        ),
        _buildModerationCard(
          title: 'Support',
          count: _totalSupportMessages,
          icon: Icons.support_agent,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminSupportMessagesScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==================== MODERATION CARD ====================
  Widget _buildModerationCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return HoverScale(
      onTap: onTap,
      hoverScale: 1.05,
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering ? color : Colors.grey.shade200,
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? color.withAlpha(51)
                    : Colors.grey.withAlpha(12),
                blurRadius: isHovering ? 15 : 10,
                offset: Offset(0, isHovering ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isHovering ? color : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== RECENT ACTIVITIES ====================
  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timeline, color: Color(0xFF2563EB), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Recent Activities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 2),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                ),
                child: const Text('View All →'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('No recent activities')),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) =>
                const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildActivityItem(data);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVITY ITEM ====================
  Widget _buildActivityItem(Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final statusColors = {
      'completed': Colors.green,
      'accepted': Colors.blue,
      'cancelled': Colors.red,
    };
    final statusIcons = {
      'completed': Icons.check_circle,
      'accepted': Icons.check_circle_outline,
      'cancelled': Icons.cancel,
    };
    final Color statusColor = statusColors[status] ?? Colors.orange;
    final IconData statusIcon = statusIcons[status] ?? Icons.pending;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          data['serviceName'] ?? 'Service Request',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${data['userName'] ?? 'User'} • ${_formatTime((data['createdAt'] as Timestamp?)?.toDate())}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== UTILITY FUNCTIONS ====================
  String _formatTime(DateTime? time) {
    if (time == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(time);
  }

  String _getTimeAgo(DateTime? time) {
    if (time == null) return 'Just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(time);
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/admin-login');
  }
}

// ==================== HOVER-ANIMATED APPBAR ICON BUTTON ====================
class _HoverIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: HoverScale(
        onTap: onTap,
        hoverScale: 1.12,
        builder: (context, isHovering, isPressed) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering ? color.withAlpha(25) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          );
        },
      ),
    );
  }
}