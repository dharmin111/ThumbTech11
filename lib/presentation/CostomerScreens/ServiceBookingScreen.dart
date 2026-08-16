// lib/presentation/CostomerScreens/ServiceBookingScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../Services/ReportService.dart';
import '../../model/ServiceRequestModel.dart';
import '../DashBoard/CustomerDashboard.dart';
import '../authScreen/ChatScreen.dart';
import 'ServiceDetailScreen.dart';
import '../widgets/ReportDialog.dart';
import '../widgets/BlockDialog.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const background = Color(0xFFFFFFFF);

class ServiceBookingScreen extends StatefulWidget {
  const ServiceBookingScreen({super.key});

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestoreStorageCustomerOrder _firebaseService =
  FirebaseFirestoreStorageCustomerOrder();
  late TabController _tabController;
  String? _userId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _userId = _firebaseService.getCurrentUserId();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final userData = await _firebaseService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _userName = userData?['name'] ?? 'Customer';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CustomerDashboard()),
    );
  }

  // ==================== 🔥 EDIT REQUEST ====================

  void _editRequest(ServiceRequestModel booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailScreen(
          serviceName: booking.serviceName,
          editRequestId: booking.id,
        ),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  // ==================== 🔥 DELETE REQUEST ====================

  Future<void> _deleteRequest(String requestId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
        ),
      ),
    );

    try {
      await _firebaseService.permanentlyDeleteRequest(requestId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== 🔥 SHOW DELETE CONFIRMATION ====================

  void _showDeleteConfirmation(String requestId, String serviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'Delete Request',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this request?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Service: $serviceName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All data related to this request will be permanently deleted.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRequest(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 🔥 CANCEL REQUEST ====================

  Future<void> _cancelBooking(String requestId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
        ),
      ),
    );

    try {
      await _firebaseService.cancelRequest(requestId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error cancelling request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== 🔥 CHAT ====================

  void _openChat(ServiceRequestModel booking) {
    if (booking.technicianId != null && booking.technicianId!.isNotEmpty) {
      final conversationId = _generateConversationId(
        _userId!,
        booking.technicianId!,
        booking.id!,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            requestId: booking.id!,
            otherUserId: booking.technicianId!,
            otherUserName: booking.technicianName ?? 'Technician',
            otherUserRole: 'technician',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Technician information not available'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Generate a unique conversation ID
  String _generateConversationId(String userId1, String userId2, String requestId) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}_$requestId';
  }

  // ==================== 🔥 PHONE CALL ====================

  void _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch $phoneNumber';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not call $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== 🔥 REPOST REQUEST ====================

  Future<void> _rePostRequest(String requestId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
        ),
      ),
    );

    try {
      await _firebaseService.rePostRequest(requestId: requestId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Request re-posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error re-posting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRePostDialog(String requestId, ServiceRequestModel booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.refresh, color: primaryCyan, size: 28),
            SizedBox(width: 12),
            Text(
              'Repost Request',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you want to repost this request to find a new technician?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build, size: 16, color: darkBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.serviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: darkBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '₹${booking.budget.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (booking.cancellationReason != null &&
                      booking.cancellationReason!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Previous Reason: ${booking.cancellationReason}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'New technicians will be notified about your request.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rePostRequest(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryCyan,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Repost Now',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 🔥 REPORT + BLOCK ====================

  void _showBookingActions(ServiceRequestModel booking) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Report Booking
            ListTile(
              leading: Icon(Icons.flag, color: Colors.red.shade700),
              title: const Text(
                'Report this booking',
                style: TextStyle(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(
                  targetId: booking.id!,
                  targetType: 'booking',
                  targetName: booking.serviceName,
                  additionalInfo: 'Booking ID: ${booking.id}',
                );
              },
            ),

            // Block Technician (only if accepted)
            if (booking.status.toLowerCase() == 'accepted' &&
                booking.technicianId != null &&
                booking.technicianId!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.block, color: Colors.red.shade700),
                title: Text(
                  'Block ${booking.technicianName ?? 'Technician'}',
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(
                    booking.technicianId!,
                    booking.technicianName ?? 'Technician',
                  );
                },
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showReportDialog({
    required String targetId,
    required String targetType,
    required String targetName,
    String? additionalInfo,
  }) {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        targetId: targetId,
        targetType: targetType,
        targetName: targetName,
        additionalInfo: additionalInfo,
      ),
    );
  }

  void _blockUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => BlockDialog(
        userId: userId,
        userName: userName,
        onBlocked: () {
          setState(() {});
        },
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return _buildLoginRequiredScreen();
    }

    return WillPopScope(
      onWillPop: () async {
        _goToDashboard();
        return false;
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: darkBlue),
            onPressed: _goToDashboard,
          ),
          title: const Text(
            'My Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            labelColor: primaryCyan,
            unselectedLabelColor: darkBlue.withOpacity(0.5),
            indicatorColor: primaryCyan,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Accepted'),
              Tab(text: 'Rejected'),
              Tab(text: 'Expired'),
            ],
          ),
        ),
        body: StreamBuilder<List<ServiceRequestModel>>(
          stream: _firebaseService.getUserServiceRequests(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
                ),
              );
            }

            final allBookings = snapshot.data ?? [];

            final pendingBookings = allBookings
                .where((booking) => booking.status.toLowerCase() == 'pending')
                .toList();
            final acceptedBookings = allBookings
                .where((booking) => booking.status.toLowerCase() == 'accepted')
                .toList();
            final rejectedBookings = allBookings
                .where(
                  (booking) =>
              booking.status.toLowerCase() == 'rejected' ||
                  booking.status.toLowerCase() == 'cancelled',
            )
                .toList();
            final expiredBookings = allBookings
                .where((booking) => booking.status.toLowerCase() == 'expired')
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(pendingBookings, 'pending'),
                _buildBookingList(acceptedBookings, 'accepted'),
                _buildBookingList(rejectedBookings, 'rejected'),
                _buildBookingList(expiredBookings, 'expired'),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== UI HELPERS ====================

  Widget _buildLoginRequiredScreen() {
    return WillPopScope(
      onWillPop: () async {
        _goToDashboard();
        return false;
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: darkBlue),
            onPressed: _goToDashboard,
          ),
          title: const Text(
            'My Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.login_outlined,
                size: 80,
                color: darkBlue.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Please login to view your bookings',
                style: TextStyle(
                  fontSize: 16,
                  color: darkBlue.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading bookings',
            style: TextStyle(
              fontSize: 16,
              color: darkBlue.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(fontSize: 12, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<ServiceRequestModel> bookings, String status) {
    if (bookings.isEmpty) {
      return _buildEmptyState(status);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking, status);
      },
    );
  }

  Widget _buildEmptyState(String status) {
    String iconData;
    String title;
    String subtitle;

    switch (status) {
      case 'pending':
        iconData = '⏳';
        title = 'No Pending Bookings';
        subtitle = 'Your pending service requests will appear here';
        break;
      case 'accepted':
        iconData = '✅';
        title = 'No Accepted Bookings';
        subtitle = 'Your accepted service requests will appear here';
        break;
      case 'rejected':
        iconData = '❌';
        title = 'No Rejected Bookings';
        subtitle = 'Your rejected service requests will appear here';
        break;
      case 'expired':
        iconData = '⏰';
        title = 'No Expired Bookings';
        subtitle = 'Your expired service requests will appear here';
        break;
      default:
        iconData = '📦';
        title = 'No Bookings';
        subtitle = 'Your bookings will appear here';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(iconData, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: darkBlue.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Date not available';

    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date';
      }

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid date';
    }
  }

  // ==================== BOOKING CARD ====================

  Widget _buildBookingCard(ServiceRequestModel booking, String status) {
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusText = _getStatusText(status);

    String statusMessage;
    if (status == 'pending') {
      statusMessage = '⏳ Waiting for technician to accept your request';
    } else if (status == 'accepted') {
      statusMessage =
      '✅ Technician has accepted your request. You can now chat with them.';
    } else if (status == 'expired') {
      statusMessage =
      '⏰ This request has expired. No technician accepted it in time. You can repost it.';
    } else {
      statusMessage =
      '❌ Your request has been rejected. You can repost it to find a new technician.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getServiceIcon(booking.serviceType),
                    size: 24,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${booking.id?.substring(0, booking.id!.length > 8 ? 8 : booking.id!.length)}...',
                        style: TextStyle(
                          fontSize: 11,
                          color: darkBlue.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // 🔥 Three-dot menu for Report
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: statusColor),
                  onSelected: (value) {
                    if (value == 'report') {
                      _showReportDialog(
                        targetId: booking.id!,
                        targetType: 'booking',
                        targetName: booking.serviceName,
                        additionalInfo: 'Booking ID: ${booking.id}',
                      );
                    } else if (value == 'block' &&
                        booking.status.toLowerCase() == 'accepted' &&
                        booking.technicianId != null) {
                      _blockUser(
                        booking.technicianId!,
                        booking.technicianName ?? 'Technician',
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          const Text('Report'),
                        ],
                      ),
                    ),
                    if (status == 'accepted' &&
                        booking.technicianId != null &&
                        booking.technicianId!.isNotEmpty)
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text('Block ${booking.technicianName ?? 'Technician'}'),
                          ],
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Message
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == 'pending'
                            ? Icons.hourglass_empty
                            : status == 'accepted'
                            ? Icons.check_circle
                            : status == 'expired'
                            ? Icons.timer_off
                            : Icons.cancel,
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Technician Info (only for accepted)
                if (status == 'accepted' &&
                    booking.technicianName != null &&
                    booking.technicianName!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: primaryCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryCyan.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryCyan,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Technician Assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: darkBlue.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                booking.technicianName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                              if (booking.technicianPhone != null &&
                                  booking.technicianPhone!.isNotEmpty)
                                Text(
                                  booking.technicianPhone!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primaryCyan,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (booking.technicianPhone != null &&
                            booking.technicianPhone!.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                _makePhoneCall(booking.technicianPhone!),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryCyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.phone,
                                size: 20,
                                color: primaryCyan,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Expired Info
                if (status == 'expired')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_off,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expired on: ${_formatDate(booking.updatedAt)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Rejection Info
                if (status == 'rejected' && booking.cancellationReason != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reason: ${booking.cancellationReason ?? "Not specified"}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Details
                _buildDetailRow(
                  Icons.calendar_today,
                  'Requested on',
                  _formatDate(booking.createdAt),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.build,
                  'Service Type',
                  booking.serviceType,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.location_on,
                  'Location',
                  booking.location,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.local_post_office,
                  'Pincode',
                  booking.pincode,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.currency_rupee,
                  'Budget',
                  '₹${booking.budget.toStringAsFixed(0)}',
                ),

                if (booking.estimatedPrice != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.price_change,
                    'Estimated Price',
                    '₹${booking.estimatedPrice!.toStringAsFixed(0)}',
                  ),
                ],

                if (booking.issue.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.description,
                    'Issue',
                    booking.issue,
                    maxLines: 2,
                  ),
                ],

                if (booking.additionalNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.note_add,
                    'Note',
                    booking.additionalNote,
                    maxLines: 2,
                  ),
                ],

                const SizedBox(height: 16),

                // ==================== 🔥 ACTION BUTTONS ====================

                // Pending: Edit + Cancel
                if (status == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editRequest(booking),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryCyan,
                            side: const BorderSide(color: primaryCyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelBooking(booking.id!),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Accepted: Chat + Delete
                if (status == 'accepted' && booking.technicianId != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openChat(booking),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Chat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryCyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteConfirmation(
                              booking.id!, booking.serviceName),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Expired: Repost + Edit + Delete
                if (status == 'expired') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showRePostDialog(booking.id!, booking),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Repost'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryCyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editRequest(booking),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryCyan,
                            side: const BorderSide(color: primaryCyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteConfirmation(
                              booking.id!, booking.serviceName),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Rejected: Repost + Edit + Delete
                if (status == 'rejected') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showRePostDialog(booking.id!, booking),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Repost'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryCyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editRequest(booking),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryCyan,
                            side: const BorderSide(color: primaryCyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteConfirmation(
                              booking.id!, booking.serviceName),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================

  Widget _buildDetailRow(IconData icon, String label, String value,
      {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: darkBlue.withOpacity(0.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: darkBlue.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: darkBlue,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel;
      case 'expired':
        return Icons.timer_off;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getServiceIcon(String serviceType) {
    final type = serviceType.toLowerCase();
    if (type.contains('ac') || type.contains('cooling')) {
      return Icons.ac_unit;
    } else if (type.contains('plumbing') || type.contains('pipe')) {
      return Icons.plumbing;
    } else if (type.contains('electric') || type.contains('wiring')) {
      return Icons.electrical_services;
    } else if (type.contains('carpentry') || type.contains('wood')) {
      return Icons.handyman;
    } else if (type.contains('paint') || type.contains('wall')) {
      return Icons.format_paint;
    } else if (type.contains('cleaning') || type.contains('house')) {
      return Icons.cleaning_services;
    } else {
      return Icons.build;
    }
  }
}