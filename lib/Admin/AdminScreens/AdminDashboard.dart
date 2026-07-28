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
  int _newRequestsToday = 0;

  // ✅ Recent Users
  List<Map<String, dynamic>> _recentUsers = [];

  // ✅ Stream Subscriptions for Real-time Data
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

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

    // ✅ Start real-time listeners
    _startRealTimeListeners();
  }

  @override
  void dispose() {
    // ✅ Cancel all subscriptions
    _usersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ✅ REAL-TIME LISTENERS
  void _startRealTimeListeners() {
    // ✅ Users Real-time Listener
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) {
            _processUsersData(snapshot);
          },
          onError: (error) {
            print('❌ Users stream error: $error');
          },
        );

    // ✅ Requests Real-time Listener
    _requestsSubscription = FirebaseFirestore.instance
        .collection('service_requests')
        .snapshots()
        .listen(
          (snapshot) {
            _processRequestsData(snapshot);
          },
          onError: (error) {
            print('❌ Requests stream error: $error');
          },
        );

    // ✅ Bookings Real-time Listener
    _bookingsSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .snapshots()
        .listen(
          (snapshot) {
            _processBookingsData(snapshot);
          },
          onError: (error) {
            print('❌ Bookings stream error: $error');
          },
        );

    // ✅ Set loading false after initial data
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  // ✅ Process Users Data
  void _processUsersData(QuerySnapshot snapshot) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Total Users
    _totalUsers = snapshot.docs.length;

    // New Users Today
    _newUsersToday = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow);
    }).length;

    // New Technicians Today
    _newTechniciansToday = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow) &&
          data['role'] == 'technician';
    }).length;

    // New Customers Today
    _newCustomersToday = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow) &&
          data['role'] == 'customer';
    }).length;

    // Recent Users (Last 5 non-admin users)
    final usersList = snapshot.docs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['role'] != 'admin';
        })
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    usersList.sort((a, b) {
      final aDate = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bDate = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bDate.compareTo(aDate);
    });

    _recentUsers = usersList.take(5).toList();

    // ✅ Update UI
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ Process Requests Data
  void _processRequestsData(QuerySnapshot snapshot) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Total Requests
    _totalRequests = snapshot.docs.length;

    // New Requests Today
    _newRequestsToday = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null &&
          createdAt.isAfter(today) &&
          createdAt.isBefore(tomorrow);
    }).length;

    // Calculate Revenue
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

    // ✅ Update UI
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ Process Bookings Data
  void _processBookingsData(QuerySnapshot snapshot) {
    _totalBookings = snapshot.docs.length;

    // ✅ Update UI
    if (mounted) {
      setState(() {});
    }
  }

  // ✅ Manual Refresh (Optional)
  Future<void> _refreshData() async {
    // Streams already update automatically, just show snackbar
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
            color: Colors.black.withValues(alpha: 0.05),
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
          setState(() {
            _selectedIndex = index;
          });
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
              // Welcome Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildWelcomeHeader(),
              ),
              const SizedBox(height: 20),

              // ✅ Today's Stats
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildTodayStats(),
              ),
              const SizedBox(height: 20),

              // Main Stats Grid
              FadeTransition(opacity: _fadeAnimation, child: _buildStatsGrid()),
              const SizedBox(height: 24),

              // ✅ Recent Users
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildRecentUsers(),
              ),
              const SizedBox(height: 24),

              // Recent Activities
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
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ Live Indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(seconds: 1),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
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
            color: Colors.grey.withValues(alpha: 0.1),
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
                title: 'New Users',
                value: _newUsersToday.toString(),
                icon: Icons.person_add,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminTodayActivityScreen(
                        type: 'users',
                        count: _newUsersToday,
                      ),
                    ),
                  );
                },
              ),
              _buildTodayStatCard(
                title: 'New Tasks',
                value: _newRequestsToday.toString(),
                icon: Icons.add_task,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminTodayActivityScreen(
                        type: 'tasks',
                        count: _newRequestsToday,
                      ),
                    ),
                  );
                },
              ),
              _buildTodayStatCard(
                title: 'New Customers',
                value: _newCustomersToday.toString(),
                icon: Icons.person,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminTodayActivityScreen(
                        type: 'customers',
                        count: _newCustomersToday,
                      ),
                    ),
                  );
                },
              ),
              _buildTodayStatCard(
                title: 'New Techs',
                value: _newTechniciansToday.toString(),
                icon: Icons.build,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminTodayActivityScreen(
                        type: 'technicians',
                        count: _newTechniciansToday,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
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
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHovering
                  ? color.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovering ? color : color.withValues(alpha: 0.1),
                width: isHovering ? 1.5 : 1,
              ),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              children: [
                AnimatedRotation(
                  turns: isHovering ? 0.05 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: isHovering ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  child: Text(value),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
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
        'subtitle': 'Active users',
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
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isHovering
                  ? colors.map((c) => c.withValues(alpha: 1)).toList()
                  : colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: isHovering ? 0.45 : 0.3),
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: isHovering ? 0.3 : 0.2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedRotation(
                      turns: isHovering ? -0.03 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
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
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.6),
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

  // ==================== RECENT USERS ====================
  Widget _buildRecentUsers() {
    if (_recentUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
            final name = user['name'] ?? 'Unknown';
            final email = user['email'] ?? '';
            final role = user['role'] ?? 'customer';
            final createdAt = (user['createdAt'] as Timestamp?)?.toDate();
            final timeAgo = _getTimeAgo(createdAt);
            final isActive = user['isActive'] ?? true;

            Color roleColor = role == 'technician' ? Colors.blue : Colors.green;
            IconData roleIcon = role == 'technician'
                ? Icons.build
                : Icons.person;

            return HoverScale(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminUserDetailScreen(
                      userId: user['uid'] ?? user['id'] ?? '',
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
                    color: isHovering
                        ? Colors.grey.shade50
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  transform: Matrix4.translationValues(
                    isHovering ? 4 : 0,
                    0,
                    0,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: roleColor.withValues(alpha: 0.1),
                      child: Icon(roleIcon, color: roleColor, size: 16),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
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
                            color: Colors.green.withValues(alpha: 0.1),
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

  // ==================== RECENT ACTIVITIES ====================
  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                onPressed: () {
                  setState(() => _selectedIndex = 2);
                },
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
                separatorBuilder: (context, index) => const Divider(height: 1),
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

    return HoverScale(
      hoverScale: 1.0,
      onTap: () {
        // Navigate to task detail
      },
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isHovering ? Colors.grey.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          transform: Matrix4.translationValues(isHovering ? 4 : 0, 0, 0),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
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
                color: statusColor.withValues(alpha: 0.1),
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
      },
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
              color: isHovering
                  ? color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          );
        },
      ),
    );
  }
}
