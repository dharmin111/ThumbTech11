import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thumstechs/presentation/CostomerScreens/ServiceBookingScreen.dart';
import 'package:thumstechs/presentation/CostomerScreens/ServiceRequestDetailScreen.dart';
import '../../Services/FirebaseMessageService.dart';
import '../../Services/oneSignalNotificationService.dart';
import '../CostomerScreens/BookingScreen.dart';
import '../CostomerScreens/MyBookingsScreen.dart';
import '../CostomerScreens/ProfileScreen.dart';
import '../CostomerScreens/ServiceDetailScreen.dart';
import '../authScreen/ChatListScreen.dart';
import '../authScreen/LoginScreen.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const lightBlue = Color(0xFF7EC8FF);
const yellow = Color(0xFFFFD428);
const background = Color(0xFFFFFFFF);

class CustomerDashboard extends StatefulWidget {
  final bool isGuest;
  const CustomerDashboard({super.key, this.isGuest = false});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  String searchQuery = '';
  int _selectedIndex = 0;
  int _totalUnread = 0;

  // Task counts
  int _pendingCount = 0;
  int _acceptedCount = 0;
  int _completedCount = 0;

  // ✅ Strip visibility
  bool _showTaskStrip = true;
  bool _isUpdating = false;
  String? _currentTaskId;

  Timer? _unreadTimer;
  Timer? _taskTimer;

  @override
  void initState() {
    super.initState();
    loadUserData();
    _ensureOneSignalId();
    _startUnreadCountPolling();
    _startTaskPolling();
  }

  // ==================== TASK POLLING ====================

  void _startTaskPolling() {
    _taskTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchTaskCounts();
    });
    _fetchTaskCounts();
  }

  Future<void> _fetchTaskCounts() async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        _taskTimer?.cancel();
        return;
      }

      // Fetch pending requests
      final pendingQuery = await firestore
          .collection('service_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      // Fetch accepted requests
      final acceptedQuery = await firestore
          .collection('service_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['accepted', 'assigned', 'in_progress'])
          .get();

      // Fetch completed requests
      final completedQuery = await firestore
          .collection('service_requests')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      if (mounted) {
        setState(() {
          _pendingCount = pendingQuery.docs.length;
          _acceptedCount = acceptedQuery.docs.length;
          _completedCount = completedQuery.docs.length;

          // ✅ Set current task ID for auto-complete
          if (acceptedQuery.docs.isNotEmpty) {
            _currentTaskId = acceptedQuery.docs.first.id;
          } else {
            _currentTaskId = null;
          }
        });
      }
    } catch (e) {
      print('❌ Error fetching task counts: $e');
    }
  }

  // ==================== UNREAD COUNT POLLING ====================

  void _startUnreadCountPolling() {
    _unreadTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchUnreadCount();
    });
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) return;

      final customerQuery = await firestore
          .collection('conversations')
          .where('customerId', isEqualTo: currentUser.uid)
          .get();

      final technicianQuery = await firestore
          .collection('conversations')
          .where('technicianId', isEqualTo: currentUser.uid)
          .get();

      int count = 0;

      for (var doc in customerQuery.docs) {
        final data = doc.data();
        if (data['status'] == 'active') {
          final unread = data['customerUnreadCount'] ?? 0;
          count += unread is int ? unread : 0;
        }
      }

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
      }
    } catch (e) {
      print('❌ Error fetching unread count: $e');
    }
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _taskTimer?.cancel();
    super.dispose();
  }

  // ==================== ONESIGNAL ====================

  Future<void> _ensureOneSignalId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final existingId = doc.data()?['oneSignalId'];

      if (existingId == null || existingId.isEmpty) {
        print('📱 Auto-saving OneSignal ID for customer');
        await OneSignalNotificationService.saveCurrentUserOneSignalId();
      }
    } catch (e) {
      print('Error ensuring OneSignal ID: $e');
    }
  }

  // ==================== USER DATA ====================

  Future<void> loadUserData() async {
    try {
      if (widget.isGuest) {
        if (mounted) {
          setState(() {
            userData = {
              'name': 'Guest',
              'phone': '',
            };
            isLoading = false;
          });
        }
        return;
      }
      final user = auth.currentUser;

      if (user == null) {
        navigateToLogin();
        return;
      }

      final doc = await firestore.collection("users").doc(user.uid).get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String getUserName() {
    if (userData != null && userData!.containsKey('name')) {
      return userData!['name'];
    }
    return "User";
  }

  void navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ==================== NAVIGATION ====================

  void onServiceTap(String serviceName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(serviceName: serviceName),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notifications coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _navigateToBookingTab(int tabIndex) {
    setState(() {
      _selectedIndex = 1;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceBookingScreen(initialTab: tabIndex),
        ),
      );
    });
  }

  // ==================== TASK ACCEPTED BANNER ====================

  Widget _buildTaskAcceptedBanner() {
    // ✅ Sirf Home tab par dikhao
    if (_selectedIndex != 0) {
      return const SizedBox.shrink();
    }

    // ✅ Agar strip hidden hai ya koi task nahi hai to hide karo
    if (!_showTaskStrip || _acceptedCount == 0) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceBookingScreen(initialTab: 1),
          ),
        );
      },
      child: Container(
        height: 55,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade700,
              Colors.green.shade500,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Task Accepted!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Text(
                  //   '$_acceptedCount task${_acceptedCount > 1 ? 's' : ''} accepted',
                  //   style: TextStyle(
                  //     color: Colors.white.withOpacity(0.9),
                  //     fontSize: 12,
                  //   ),
                  // ),
                ],
              ),
            ),

            // ✅ Close Button (X) - Marks task as completed
            GestureDetector(
              onTap: _handleCloseTask,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: _isUpdating
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HANDLE CLOSE TASK ====================

  Future<void> _handleCloseTask() async {
    try {
      setState(() {
        _isUpdating = true;
      });

      final user = auth.currentUser;
      if (user == null) {
        setState(() {
          _isUpdating = false;
        });
        return;
      }

      // ✅ Get the first accepted task
      final acceptedQuery = await firestore
          .collection('service_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['accepted', 'assigned', 'in_progress'])
          .limit(1)
          .get();

      if (acceptedQuery.docs.isNotEmpty) {
        final taskId = acceptedQuery.docs.first.id;

        // ✅ Update task status to 'completed'
        await firestore.collection('service_requests').doc(taskId).update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Task $taskId marked as completed');

        // ✅ Refresh counts
        await _fetchTaskCounts();
      }

      // ✅ Hide the strip
      setState(() {
        _showTaskStrip = false;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Task marked as completed!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });

      print('❌ Error completing task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== HOME SCREEN ====================

  Widget _buildHomeScreen() {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        top: false, // ✅ Allows image to extend behind top status bar, eliminating white top area!
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              if (searchQuery.isEmpty) _buildUpperCustSection(),
              _buildCategorySection(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UPPER CUSTOMER BANNER SECTION ====================

  Widget _buildUpperCustSection() {
    final String userName = getUserName();
    final String userAddress = (userData?['address'] != null && userData!['address'].toString().trim().isNotEmpty)
        ? userData!['address']
        : 'Shiv Shakti Nagar, Akota, Vadodara';

    final double topStatusPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          // LAYER 1: Background Image (Full Width & extending to top edge behind status bar)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: Image.asset(
              'assets/images/uppercust.png',
              width: double.infinity,
              fit: BoxFit.fill,

              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 380,
                  color: darkBlue,
                );
              },
            ),
          ),

          // LAYER 2: TOP HEADER OVERLAY (Name, Location, Notification)
          Positioned(
            top: 12 + topStatusPadding,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: 30),
                      Text(
                        "  Hi, $userName",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              "        $userAddress",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notification Bell
                GestureDetector(
                  onTap: _showNotifications,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // LAYER 3: WASHING SPECIAL & WATER SPECIAL IMAGE WIDGETS AT BOTTOM
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            height: 85,
            child: Row(
              children: [
                // Washing Special Banner Image
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _onBannerTap(
                        serviceName: 'Washing Machine Repair',
                        imagePath: 'assets/AppLogoo/washingspecial.PNG',
                        isVideo: true,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/AppLogoo/washingspecial.PNG',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                  ),
                ),

                // Water Purifier Special Banner Image
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _onBannerTap(
                        serviceName: 'Water Purifier / RO Service',
                        imagePath: 'assets/AppLogoo/waterspecial.PNG',
                        isVideo: false,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 5),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/AppLogoo/waterspecial.PNG',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CATEGORY SECTION ====================

  Widget _buildCategorySection() {
    List<Map<String, String>> applianceServices = [
      {'name': 'AC Repair & Service', 'image': 'assets/Appliance/Ac.jpeg'},
      {'name': 'Washing Machine Repair', 'image': 'assets/Appliance/Ap1.png'},
      {'name': 'Water Purifier / RO Service', 'image': 'assets/Appliance/waterp.jpeg'},
      {'name': 'Microwave Repair', 'image': 'assets/Appliance/ap2.png'},
      {'name': 'Chimney Repair', 'image': 'assets/Appliance/chimney.jpeg'},
      {'name': 'Geyser Repair', 'image': 'assets/Appliance/ap3.png'},
    ];

    List<Map<String, String>> homeServices = [
      {
        'name': 'CCTV Installation & Services',
        'image': 'assets/Appliance/hm1.png',
      },
      {'name': 'TV Repair', 'image': 'assets/Appliance/ap8.png'},
      {'name': 'Plumbing Service', 'image': 'assets/Appliance/ap4.png'},
      {'name': 'Air Cooler Repair', 'image': 'assets/Appliance/ap6.png'},
      {'name': 'Refrigerator Repair', 'image': 'assets/Appliance/ap7.png'},
      {'name': 'Carpenter', 'image': 'assets/Appliance/ap5.png'},
      {'name': 'Water Tank Cleaning', 'image': 'assets/Appliance/hm2.png'},
      {'name': 'Electrical Work', 'image': 'assets/Appliance/elec1.png'},
    ];

    if (searchQuery.isNotEmpty) {
      applianceServices = applianceServices
          .where(
            (service) => service['name']!.toLowerCase().contains(
          searchQuery.toLowerCase(),
        ),
      )
          .toList();
      homeServices = homeServices
          .where(
            (service) => service['name']!.toLowerCase().contains(
          searchQuery.toLowerCase(),
        ),
      )
          .toList();
    }

    if (applianceServices.isEmpty && homeServices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No services found'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Appliance Repair & Service Title
        if (applianceServices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
              top: 14,
              bottom: 1,
            ),
            child: Text(
              "Appliance Repair & Service",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
          ),
        if (applianceServices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16

            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 12,
                childAspectRatio: 2,
              ),
              itemCount: applianceServices.length,
              itemBuilder: (context, index) {
                return _buildServiceTile(
                  serviceName: applianceServices[index]['name']!,
                  imagePath: applianceServices[index]['image']!,
                );
              },
            ),
          ),
        if (applianceServices.isNotEmpty && homeServices.isNotEmpty)
          const SizedBox(height: 15),

        // Home Repair & Installation
        if (homeServices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Home Repair & Installation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
          ),
        if (homeServices.isNotEmpty) const SizedBox(height: 16),
        if (homeServices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2,
              ),
              itemCount: homeServices.length,
              itemBuilder: (context, index) {
                return _buildServiceTile(
                  serviceName: homeServices[index]['name']!,
                  imagePath: homeServices[index]['image']!,
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ==================== SPECIAL OFFER BANNER ====================

  Widget _buildSpecialOfferBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: double.infinity,
      height: 100,
      child: Row(
        children: [
          // ✅ First Banner - Washing Machine Special
          Expanded(
            child: GestureDetector(
              onTap: () {
                _onBannerTap(
                  serviceName: 'Washing Machine Repair',
                  imagePath: 'assets/AppLogoo/washingspecial.PNG',
                  isVideo: true,
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/AppLogoo/washingspecial.PNG',
                    width: double.infinity,
                    height: 88,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 30,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Washing Banner',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ✅ Second Banner - Water Purifier Special
          Expanded(
            child: GestureDetector(
              onTap: () {
                _onBannerTap(
                  serviceName: 'Water Purifier / RO Service',
                  imagePath: 'assets/AppLogoo/waterspecial.PNG',
                  isVideo: false,
                );
              },
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/AppLogoo/waterspecial.PNG',
                    width: double.infinity,
                    height: 88,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 30,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Water Banner',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BANNER TAP HANDLER ====================

  void _onBannerTap({
    required String serviceName,
    required String imagePath,
    required bool isVideo,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String requestId = 'SP_${DateTime.now().millisecondsSinceEpoch}';

    final Map<String, dynamic> specialOfferData = {
      'serviceName': serviceName,
      'requestId': requestId,
      'userId': user.uid,
      'userName': getUserName(),
      'userPhone': userData?['phone'] ?? '',
      'userEmail': user.email ?? '',
      'location': '',
      'pincode': '',
      'budget': serviceName == 'Washing Machine Repair' ? 899 : 199,
      'serviceType': serviceName,
      'preferredDate': '',
      'preferredTime': '',
      'issue': '',
      'createdAt': DateTime.now(),
      'distance': '',
      'duration': '',
      'videoId': serviceName == 'Washing Machine Repair' ? 'QVV0-269J4c' : '',
      'status': 'pending',
      'isFromBanner': true,
      'bannerImage': imagePath,
      'isVideo': isVideo,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestDetailScreen(
          requestId: requestId,
          requestData: specialOfferData,
        ),
      ),
    );
  }

  // ==================== SERVICE TILE ====================

  Widget _buildServiceTile({
    required String serviceName,
    required String imagePath,
  }) {
    return GestureDetector(
      onTap: () {
        onServiceTap(serviceName);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            imagePath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.miscellaneous_services,
                      size: 40,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image not found',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      serviceName,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== PROMO IMAGE ====================

  Widget _buildPromoImage(String imagePath) {
    return GestureDetector(
      onTap: () {
        onServiceTap("Promotional Offer");
      },
      child: Container(
        width: 350,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            imagePath,
            width: 280,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 280,
                height: 180,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Image not found',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> screens = [
      _buildHomeScreen(),
      const ServiceBookingScreen(),
      const MyBookingsScreen(),
      const ChatListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(

      body: Column(
        children: [
          // Main content
          Expanded(
            child: screens[_selectedIndex],
          ),
          // Task Accepted Banner (Bottom - above navigation)
          _buildTaskAcceptedBanner(),
          // Bottom Navigation with Badges
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: primaryCyan,
            unselectedItemColor: darkBlue.withOpacity(0.5),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 8,
            items: [
              // Home - No badge
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),

              // Booking - with Pending + Accepted count badges
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.book_online_outlined),
                    // Pending Badge (Red)
                    if (_pendingCount > 0)
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
                            _pendingCount > 99 ? '99+' : _pendingCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    // Accepted Badge (Green)
                    if (_acceptedCount > 0)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _acceptedCount > 99 ? '99+' : _acceptedCount.toString(),
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
                    const Icon(Icons.book_online),
                    if (_pendingCount > 0)
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
                            _pendingCount > 99 ? '99+' : _pendingCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    if (_acceptedCount > 0)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            _acceptedCount > 99 ? '99+' : _acceptedCount.toString(),
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
                label: 'Booking',
              ),

              // My Bookings - No badge
              const BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_outlined),
                activeIcon: Icon(Icons.list_alt),
                label: 'My Bookings',
              ),

              // Chat - with Unread badge
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

              // Profile - No badge
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ],
      ),
    );
  }
}