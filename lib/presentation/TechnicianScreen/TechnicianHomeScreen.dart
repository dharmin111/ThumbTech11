// widgets/TechnicianHomeScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Services/oneSignalNotificationService.dart';
import '../../Services/MembershipService.dart';
import '../Membership/MembershipScreen.dart';
import '../membership/MembershipExpiredScreen.dart';
import 'YouTubeVideoPlayerScreen.dart';

class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  // Technician Data
  String? technicianName;
  List<String> technicianCategories = [];
  List<String> technicianPincodes = [];
  bool isAvailable = true;
  bool isLoading = true;
  bool _isActive = true;

  // 🔥 MEMBERSHIP STATUS
  bool _hasActivePlan = false;
  bool _isCheckingPlan = true;
  bool _expiredScreenShown = false;

  // Requests
  int totalPending = 0;
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _requestsStream;
  int _lastRequestCount = 0;
  bool _isPopupShowing = false;
  bool _isFirstSnapshot = true;
  String? _highlightedRequestId;
  bool _shouldHighlight = false;
  final ScrollController _scrollController = ScrollController();

  // 🔥 Website URL for Membership
  static const String _membershipUrl = 'https://thumbtech-521ae.web.app/plans';

  @override
  void initState() {
    super.initState();
    // 🔥 Bypass all checks - directly go to membership screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MembershipScreen(),
          ),
        );
      }
    });
    // _checkMembershipAndLoadData();
  }

  @override
  void dispose() {
    _isActive = false;
    _scrollController.dispose();
    super.dispose();
  }

  // ================= 🔥 CHECK MEMBERSHIP FIRST =================
  Future<void> _checkMembershipAndLoadData() async {
    setState(() {
      _isCheckingPlan = true;
      isLoading = true;
    });

    try {
      final status = await MembershipService.getPlanStatus();
      _hasActivePlan = status['isActive'] ?? false;

      print('📊 Plan Status: $_hasActivePlan');

      await _fetchTechnicianData();

      setState(() {
        _isCheckingPlan = false;
        isLoading = false;
      });

      if (!_hasActivePlan && !_expiredScreenShown) {
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && !_expiredScreenShown) {
            _showExpiredScreen();
          }
        });
      }

    } catch (e) {
      print('❌ Error checking membership: $e');
      setState(() {
        _isCheckingPlan = false;
        isLoading = false;
      });
    }
  }

  // ================= 🔥 SHOW EXPIRED SCREEN =================
  void _showExpiredScreen() {
    if (_expiredScreenShown || !mounted) return;

    _expiredScreenShown = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MembershipExpiredScreen(
          onComplete: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ================= 🔥 OPEN MEMBERSHIP WEBSITE =================
  Future<void> _openMembershipWebsite() async {
    try {
      final url = Uri.parse(_membershipUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        _checkMembershipAndLoadData();
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening website: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= FETCH TECHNICIAN DATA =================
  Future<void> _fetchTechnicianData() async {
    if (!_isActive || !mounted) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
        _showIncompleteProfileDialog();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      List<String> pincodesList = [];
      if (data['pincodes'] != null && (data['pincodes'] as List).isNotEmpty) {
        pincodesList = List<String>.from(data['pincodes']);
      } else if (data['pincode'] != null && data['pincode'].toString().isNotEmpty) {
        pincodesList = [data['pincode'].toString()];
      }

      if (!_isActive || !mounted) return;

      setState(() {
        technicianName = data['name'] ?? 'Technician';
        technicianCategories = List<String>.from(data['categories'] ?? []);
        technicianPincodes = pincodesList;
        isAvailable = data['isActive'] ?? true;
      });

      if (technicianCategories.isNotEmpty && technicianPincodes.isNotEmpty) {
        _setupRealTimeStream();
      } else {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
        _showIncompleteProfileDialog();
      }
    } catch (e) {
      print('❌ Error fetching technician data: $e');
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // ================= SETUP REAL-TIME STREAM =================
  void _setupRealTimeStream() {
    if (technicianCategories.isEmpty || technicianPincodes.isEmpty) {
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      _requestsStream = FirebaseFirestore.instance
          .collection('service_requests')
          .where('status', isEqualTo: 'pending')
          .where('technicianId', isNull: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
        final filteredDocs = snapshot.docs.where((doc) {
          final data = doc.data();
          final serviceType = data['serviceType']?.toString() ?? '';
          final customerPincode = data['pincode']?.toString() ?? '';

          final categoryMatches = technicianCategories.contains(serviceType);
          final pincodeMatches = technicianPincodes.contains(customerPincode);

          return categoryMatches && pincodeMatches;
        }).toList();

        print('📊 Filtered Docs Count: ${filteredDocs.length}');
        print('📊 Last Request Count: $_lastRequestCount');

        if (_isFirstSnapshot) {
          _lastRequestCount = filteredDocs.length;
          _isFirstSnapshot = false;
          print('📊 First snapshot, count: $_lastRequestCount');
        } else {
          if (filteredDocs.length > _lastRequestCount && filteredDocs.isNotEmpty) {
            final newRequest = filteredDocs.first;
            final data = newRequest.data();

            print('🔔 NEW REQUEST DETECTED!');
            print('📦 Request ID: ${data['requestId']}');
            print('📦 Service Name: ${data['serviceName']}');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showNewTaskPopup(data);
              }
            });
          }
          _lastRequestCount = filteredDocs.length;
        }

        if (mounted) {
          setState(() {
            totalPending = filteredDocs.length;
          });
        }

        return filteredDocs;
      });

      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });

      print('✅ Real-time stream setup complete');
      print('📊 Categories: ${technicianCategories.join(", ")}');
      print('📊 Pincodes: ${technicianPincodes.join(", ")}');
    } catch (e) {
      print('❌ Error setting up stream: $e');
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // ================= POPUP FUNCTIONS =================
  void _showNewTaskPopup(Map<String, dynamic> data) {
    if (!mounted || _isPopupShowing) return;

    _isPopupShowing = true;
    final String requestId = data['requestId'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "New Service Request",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['serviceName'] ?? 'Service Request',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0C1B4D),
                ),
              ),
              const SizedBox(height: 12),
              _buildPopupDetailRow('Customer', data['userName'] ?? 'N/A'),
              const SizedBox(height: 6),
              _buildPopupDetailRow(
                'Phone',
                _hasActivePlan ? (data['userPhone'] ?? 'N/A') : '🔒 Locked',
                isLocked: !_hasActivePlan,
              ),
              const SizedBox(height: 6),
              _buildPopupDetailRow('Budget', '₹${data['budget'] ?? 0}'),
              const SizedBox(height: 6),
              _buildPopupDetailRow(
                'Location',
                _hasActivePlan ? (data['location'] ?? 'N/A') : '🔒 Locked',
                isLocked: !_hasActivePlan,
              ),
              const SizedBox(height: 6),
              _buildPopupDetailRow('Pincode', data['pincode'] ?? 'N/A'),
              if (data['issue'] != null && data['issue'].isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildPopupDetailRow('Issue', data['issue']),
              ],
              if (!_hasActivePlan) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Subscribe to view contact details and accept requests',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isPopupShowing = false;
                Navigator.pop(context);
                setState(() {
                  _highlightedRequestId = null;
                  _shouldHighlight = false;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 15),
              ),
            ),
            if (_hasActivePlan)
              ElevatedButton(
                onPressed: () {
                  _isPopupShowing = false;
                  Navigator.pop(context);

                  setState(() {
                    _highlightedRequestId = requestId;
                    _shouldHighlight = true;
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToHighlightedCard();
                  });

                  Future.delayed(const Duration(seconds: 30), () {
                    if (mounted) {
                      setState(() {
                        _highlightedRequestId = null;
                        _shouldHighlight = false;
                      });
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🔍 New task highlighted in green!'),
                      backgroundColor: Color(0xFF2563EB),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            if (!_hasActivePlan)
              ElevatedButton(
                onPressed: () {
                  _isPopupShowing = false;
                  Navigator.pop(context);
                  _openMembershipWebsite();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Subscribe Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        );
      },
    ).then((_) {
      _isPopupShowing = false;
    });
  }

  void _scrollToHighlightedCard() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
        print('📜 Scrolled to highlighted card');
      }
    });
  }

  Widget _buildPopupDetailRow(String label, String value, {bool isLocked = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isLocked ? Colors.red : const Color(0xFF0C1B4D),
            ),
          ),
        ),
      ],
    );
  }

  // ================= ACCEPT REQUEST =================
  Future<void> _acceptRequest(String requestId, Map<String, dynamic> requestData) async {
    if (!_hasActivePlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please subscribe to accept requests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'technicianId': user.uid,
        'technicianName': technicianName,
        'technicianPhone': user.phoneNumber ?? '',
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final pendingDoc = await FirebaseFirestore.instance
          .collection('technician_pending_requests')
          .doc('${user.uid}_$requestId')
          .get();

      if (pendingDoc.exists) {
        await pendingDoc.reference.delete();
      }

      await OneSignalNotificationService.sendRequestAcceptedNotification(
        customerId: requestData['userId'],
        technicianName: technicianName ?? 'Technician',
        technicianPhone: user.phoneNumber ?? '',
        requestId: requestId,
        serviceName: requestData['serviceName'] ?? 'Service',
      );

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': requestData['userId'],
        'userRole': 'customer',
        'title': '✅ Request Accepted!',
        'body': '$technicianName has accepted your service request.',
        'type': 'request_accepted',
        'requestId': requestId,
        'technicianName': technicianName,
        'technicianPhone': user.phoneNumber ?? '',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.uid,
        'userRole': 'technician',
        'title': '✅ Request Accepted Successfully!',
        'body': 'You have accepted the service request from ${requestData['userName']}.',
        'type': 'task_accepted',
        'requestId': requestId,
        'customerName': requestData['userName'],
        'customerPhone': requestData['userPhone'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!_isActive || !mounted) {
        Navigator.pop(context);
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Service request accepted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      Navigator.pop(context);
      print('❌ Error accepting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= REJECT REQUEST =================
  Future<void> _rejectRequest(String requestId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await OneSignalNotificationService.sendRequestRejectedNotification(
        customerId: requestData['userId'],
        requestId: requestId,
        serviceName: requestData['serviceName'] ?? 'Service',
      );

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': requestData['userId'],
        'userRole': 'customer',
        'title': '❌ Request Rejected',
        'body': 'Your service request has been rejected. You can post a new request.',
        'type': 'request_rejected',
        'requestId': requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!_isActive || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.orange,
        ),
      );

    } catch (e) {
      print('❌ Error rejecting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= TOGGLE AVAILABILITY =================
  Future<void> _toggleAvailability(bool value) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!_isActive || !mounted) return;

      setState(() {
        isAvailable = value;
      });

      if (value) {
        _setupRealTimeStream();
      } else {
        setState(() {
          _requestsStream = null;
          totalPending = 0;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '✅ You are now available for service' : 'You are now offline'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );

    } catch (e) {
      print('❌ Error toggling availability: $e');
    }
  }

  // ================= SHOW DIALOGS =================
  void _showIncompleteProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Profile Incomplete'),
        content: const Text(
          'Please complete your technician profile with categories and pincodes to start receiving service requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog(String requestId, Map<String, dynamic> data) {
    if (!_hasActivePlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please subscribe to accept requests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to accept this service request?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service: ${data['serviceName']}'),
                  const SizedBox(height: 4),
                  Text('Budget: ₹${data['budget']}'),
                  const SizedBox(height: 4),
                  Text('Customer: ${data['userName']}'),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${_hasActivePlan ? (data['userPhone'] ?? 'N/A') : '🔒 Locked'}',
                    style: TextStyle(
                      color: _hasActivePlan ? Colors.black : Colors.red,
                    ),
                  ),
                  Text(
                    'Location: ${_hasActivePlan ? (data['location'] ?? 'N/A') : '🔒 Locked'}',
                    style: TextStyle(
                      color: _hasActivePlan ? Colors.black : Colors.red,
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptRequest(requestId, data);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: const Text('Are you sure you want to reject this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectRequest(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ================= SHOW REQUEST DETAILS =================
  void _showRequestDetails(String requestId, Map<String, dynamic> data) {
    final String videoId = data['videoId'] ?? '';
    final bool hasVideo = videoId.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['serviceName'] ?? 'Service Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasVideo)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GestureDetector(
                    onTap: () => _openYouTubeVideo(videoId),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 160,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 160,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Text('Video not available'),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 35,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              _buildDetailRow('Customer Name', data['userName'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Phone',
                _hasActivePlan ? (data['userPhone'] ?? 'N/A') : '🔒 Subscribe to view',
                isLocked: !_hasActivePlan,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Email',
                _hasActivePlan ? (data['userEmail'] ?? 'N/A') : '🔒 Subscribe to view',
                isLocked: !_hasActivePlan,
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Service Type', data['serviceType'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Location',
                _hasActivePlan ? (data['location'] ?? 'N/A') : '🔒 Subscribe to view',
                isLocked: !_hasActivePlan,
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Pincode', data['pincode'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Budget', '₹${data['budget'] ?? 0}'),
              const SizedBox(height: 8),
              _buildDetailRow('Issue', data['issue'] ?? 'N/A'),
              if (data['additionalNote'] != null && data['additionalNote'].isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Additional Note', data['additionalNote']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (hasVideo)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openYouTubeVideo(videoId);
              },
              icon: const Icon(Icons.play_circle, size: 18),
              label: const Text('Watch Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ================= OPEN YOUTUBE VIDEO =================
  void _openYouTubeVideo(String videoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubeVideoPlayerScreen(videoId: videoId),
      ),
    );
  }

  // ================= VIDEO THUMBNAIL =================
  Widget _buildVideoThumbnail(String videoId) {
    return GestureDetector(
      onTap: () => _openYouTubeVideo(videoId),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.network(
                'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Text('Video not available'),
                    ),
                  );
                },
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 28,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLocked = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isLocked ? Colors.red : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    if (isLoading || _isCheckingPlan) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _checkMembershipAndLoadData();
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildWelcomeBanner(),
            _buildPlanStatusButton(),
            _buildAvailabilityToggle(),
            const SizedBox(height: 8),
            _buildStatsCards(),
            _buildPendingRequests(),
          ],
        ),
      ),
    );
  }

  // ================= PLAN STATUS BUTTON =================
  Widget _buildPlanStatusButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _openMembershipWebsite,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _hasActivePlan ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasActivePlan ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _hasActivePlan ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _hasActivePlan ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasActivePlan ? '✅ Plan Active' : '❌ Plan Expired',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _hasActivePlan ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          if (_hasActivePlan)
                            Text(
                              'Tap to manage subscription',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade600,
                              ),
                            )
                          else
                            Text(
                              'Tap to subscribe now!',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: _hasActivePlan ? Colors.green : Colors.red,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2563EB).withOpacity(0.1),
            const Color(0xFF2563EB).withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            technicianName ?? 'Technician',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          if (technicianCategories.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: technicianCategories.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 4),
          Text(
            'Service Areas: ${technicianPincodes.isNotEmpty ? technicianPincodes.join(", ") : "Not set"}',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isAvailable ? Icons.circle : Icons.circle_outlined,
                color: isAvailable ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isAvailable ? 'Available for Service' : 'Offline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
          Switch(
            value: isAvailable,
            onChanged: _toggleAvailability,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Pending Tasks',
              totalPending.toString(),
              Icons.pending_actions,
              totalPending > 0 ? Colors.orange : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Categories',
              technicianCategories.length.toString(),
              Icons.category,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Areas',
              technicianPincodes.length.toString(),
              Icons.location_on,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ================= PENDING REQUESTS =================
  Widget _buildPendingRequests() {
    if (technicianCategories.isEmpty || technicianPincodes.isEmpty) {
      return _buildIncompleteProfileWidget();
    }

    if (!isAvailable) {
      return _buildOfflineWidget();
    }

    if (_requestsStream == null) {
      return _buildEmptyWidget();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Service Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks matching your categories and service areas (auto-refresh)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _setupRealTimeStream,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyWidget();
              }

              final pendingRequests = snapshot.data!;

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingRequests.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var request = pendingRequests[index];
                  return _buildRequestCard(request);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= REQUEST CARD =================
  Widget _buildRequestCard(QueryDocumentSnapshot<Map<String, dynamic>> request) {
    Map<String, dynamic> data = request.data();
    final createdAt = (data['createdAt'] as Timestamp).toDate();

    final bool isHighlighted = _highlightedRequestId != null &&
        _shouldHighlight &&
        _highlightedRequestId == request.id;

    final String videoId = data['videoId'] ?? '';
    final bool hasVideo = videoId.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.green : Colors.grey.shade200,
          width: isHighlighted ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? Colors.green.withOpacity(0.4)
                : Colors.grey.withOpacity(0.05),
            blurRadius: isHighlighted ? 15 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.green.shade100
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isHighlighted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'New Request',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isHighlighted ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                _buildCountdownTimer(createdAt),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['serviceName'] ?? 'Service Request',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '₹${data['budget']?.toString() ?? '0'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),

                if (hasVideo) ...[
                  _buildVideoThumbnail(videoId),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['userName'] ?? 'Customer',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasActivePlan ? (data['userPhone'] ?? 'No phone') : '🔒 Subscribe to view',
                        style: TextStyle(
                          fontSize: 14,
                          color: _hasActivePlan ? Colors.black : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hasActivePlan ? (data['location'] ?? 'Location not specified') : '🔒 Subscribe to view',
                        style: TextStyle(
                          fontSize: 14,
                          color: _hasActivePlan ? Colors.black : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_city, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Pincode: ${data['pincode'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (data['issue'] != null && data['issue'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issue:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['issue'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showRequestDetails(request.id, data);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _hasActivePlan
                            ? () => _showAcceptDialog(request.id, data)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasActivePlan ? Colors.green : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _hasActivePlan ? 'Accept' : '🔒 Locked',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showRejectDialog(request.id);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),

                if (!_hasActivePlan) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Subscribe to accept requests',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openMembershipWebsite,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '@99₹ Only',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= COUNTDOWN TIMER =================
  Widget _buildCountdownTimer(DateTime createdAt) {
    return StatefulBuilder(
      builder: (context, setStateTimer) {
        final expiryTime = createdAt.add(const Duration(minutes: 3));

        return StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final remaining = expiryTime.difference(now);

            if (remaining.isNegative) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_off, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    const Text(
                      '0:00',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }

            final minutes = remaining.inMinutes;
            final seconds = remaining.inSeconds.remainder(60);

            Color timerColor;
            if (minutes >= 2) {
              timerColor = Colors.green;
            } else if (minutes >= 1) {
              timerColor = Colors.orange;
            } else {
              timerColor = Colors.red;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: timerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: timerColor),
                  const SizedBox(width: 4),
                  Text(
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= EMPTY STATE WIDGETS =================
  Widget _buildIncompleteProfileWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange[400]),
          const SizedBox(height: 16),
          const Text(
            'Profile Incomplete',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please complete your profile to start receiving requests.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.toggle_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'You are offline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn on availability to see pending service requests.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No pending requests',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks matching your categories and pincode will appear here automatically',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}