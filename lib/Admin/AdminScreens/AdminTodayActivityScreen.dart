// Admin/AdminScreens/AdminTodayActivityScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widget/hover_scale.dart';
import 'AdminUserDetailScreen.dart';
import 'AdminTaskDetailScreen.dart'; // ✅ Import Task Detail Screen

class AdminTodayActivityScreen extends StatefulWidget {
  final String type; // 'users', 'tasks', 'customers', 'technicians'
  final int count;

  const AdminTodayActivityScreen({
    super.key,
    required this.type,
    required this.count,
  });

  @override
  State<AdminTodayActivityScreen> createState() =>
      _AdminTodayActivityScreenState();
}

class _AdminTodayActivityScreenState extends State<AdminTodayActivityScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      if (widget.type == 'tasks') {
        // ✅ Load Today's Tasks (Service Requests)
        final snapshot = await FirebaseFirestore.instance
            .collection('service_requests')
            .get();

        _items =
            snapshot.docs
                .where((doc) {
                  final data = doc.data();
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  return createdAt != null &&
                      createdAt.isAfter(today) &&
                      createdAt.isBefore(tomorrow);
                })
                .map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id; // ✅ Add document ID
                  return data;
                })
                .toList()
              ..sort((a, b) {
                final aDate =
                    (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                final bDate =
                    (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                return bDate.compareTo(aDate);
              });
      } else {
        // ✅ Load Today's Users (Customers, Technicians, All Users)
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();

        var users = snapshot.docs
            .where((doc) {
              final data = doc.data();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              return createdAt != null &&
                  createdAt.isAfter(today) &&
                  createdAt.isBefore(tomorrow);
            })
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id; // ✅ Add document ID
              return data;
            })
            .toList();

        // Filter by type
        if (widget.type == 'customers') {
          users = users.where((user) => user['role'] == 'customer').toList();
        } else if (widget.type == 'technicians') {
          users = users.where((user) => user['role'] == 'technician').toList();
        }

        users.sort((a, b) {
          final aDate =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        _items = users;
      }

      setState(() {});
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          _HoverIconButton(
            icon: Icons.refresh,
            color: const Color(0xFF2563EB),
            onTap: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : _buildBody(),
    );
  }

  String _getTitle() {
    switch (widget.type) {
      case 'users':
        return 'Today\'s New Users';
      case 'tasks':
        return 'Today\'s New Tasks';
      case 'customers':
        return 'Today\'s New Customers';
      case 'technicians':
        return 'Today\'s New Technicians';
      default:
        return 'Today\'s Activity';
    }
  }

  String _getSubtitle() {
    return '${_items.length} new ${widget.type == 'tasks' ? 'tasks' : 'users'} today';
  }

  Widget _buildBody() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No new ${widget.type == 'tasks' ? 'tasks' : 'users'} today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All caught up! 🎉',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // ✅ Header Stats
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_items.length}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getSubtitle(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _buildItemCard(item, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    final bool isTask = widget.type == 'tasks';
    final createdAt = (item['createdAt'] as Timestamp?)?.toDate();
    final timeString = _formatTime(createdAt);

    if (isTask) {
      // ✅ TASK CARD - Opens Task Detail Screen on Tap
      final status = item['status'] ?? 'pending';
      final statusColors = {
        'completed': Colors.green,
        'accepted': Colors.blue,
        'cancelled': Colors.red,
        'in_progress': Colors.orange,
      };
      final statusIcons = {
        'completed': Icons.check_circle,
        'accepted': Icons.check_circle_outline,
        'cancelled': Icons.cancel,
        'in_progress': Icons.hourglass_empty,
      };
      final Color statusColor = statusColors[status] ?? Colors.orange;
      final IconData statusIcon = statusIcons[status] ?? Icons.pending;

      return HoverScale(
        onTap: () {
          // ✅ NAVIGATE TO TASK DETAIL SCREEN
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminTaskDetailScreen(
                taskId: item['id'] ?? '',
                taskData: item,
              ),
            ),
          );
        },
        builder: (context, isHovering, isPressed) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHovering
                    ? statusColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHovering
                      ? statusColor.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.05),
                  blurRadius: isHovering ? 16 : 8,
                  offset: Offset(0, isHovering ? 6 : 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['serviceName'] ?? 'Service Request',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customer: ${item['userName'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Budget: ₹${item['budget'] ?? 0}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } else {
      // ✅ USER CARD (Customer, Technician, All Users)
      final role = item['role'] ?? 'customer';
      final isActive = item['isActive'] ?? true;
      final name = item['name'] ?? 'Unknown User';
      final email = item['email'] ?? 'No Email';

      Color roleColor = role == 'technician'
          ? Colors.blue
          : role == 'admin'
          ? Colors.purple
          : Colors.green;
      IconData roleIcon = role == 'technician'
          ? Icons.build
          : role == 'admin'
          ? Icons.admin_panel_settings
          : Icons.person;

      return HoverScale(
        onTap: () {
          // ✅ Navigate to User Detail Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminUserDetailScreen(
                userId: item['id'] ?? '',
                userData: item,
              ),
            ),
          );
        },
        builder: (context, isHovering, isPressed) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHovering
                    ? roleColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHovering
                      ? roleColor.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.05),
                  blurRadius: isHovering ? 16 : 8,
                  offset: Offset(0, isHovering ? 6 : 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.1),
                  child: Icon(roleIcon, color: roleColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                color: roleColor,
                                fontWeight: FontWeight.bold,
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
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('h:mm a').format(time);
  }
}

// ==================== HOVER-ANIMATED ICON BUTTON ====================
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
