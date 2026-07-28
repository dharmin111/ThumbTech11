// widgets/TechnicianMyServicesScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../authScreen/ChatScreen.dart';

class TechnicianMyServicesScreen extends StatefulWidget {
  const TechnicianMyServicesScreen({super.key});

  @override
  State<TechnicianMyServicesScreen> createState() =>
      _TechnicianMyServicesScreenState();
}

class _TechnicianMyServicesScreenState
    extends State<TechnicianMyServicesScreen> {
  List<QueryDocumentSnapshot> acceptedRequests = [];
  List<QueryDocumentSnapshot> completedRequests = [];
  bool isLoading = true;
  bool _isActive = true;

  // Cache for customer phone numbers
  final Map<String, String> _phoneNumberCache = {};

  @override
  void initState() {
    super.initState();
    _fetchMyServices();
  }

  @override
  void dispose() {
    _isActive = false;
    super.dispose();
  }

  Future<void> _fetchMyServices() async {
    if (!_isActive || !mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get accepted requests
        QuerySnapshot acceptedSnapshot = await FirebaseFirestore.instance
            .collection('service_requests')
            .where('technicianId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'accepted')
            .orderBy('acceptedAt', descending: true)
            .get();

        if (!_isActive || !mounted) return;

        // Get completed requests
        QuerySnapshot completedSnapshot = await FirebaseFirestore.instance
            .collection('service_requests')
            .where('technicianId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
            .get();

        if (!_isActive || !mounted) return;

        setState(() {
          acceptedRequests = acceptedSnapshot.docs;
          completedRequests = completedSnapshot.docs;
          isLoading = false;
        });

        // Fetch phone numbers for all accepted requests in background
        _fetchPhoneNumbersForRequests(acceptedRequests);
      } else {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching my services: $e');
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch phone numbers for all accepted requests
  Future<void> _fetchPhoneNumbersForRequests(
    List<QueryDocumentSnapshot> requests,
  ) async {
    for (var request in requests) {
      final data = request.data() as Map<String, dynamic>;
      final customerId = data['userId'];
      final existingPhone = data['userPhone'] ?? '';

      if (customerId != null && existingPhone.isEmpty) {
        await _getCustomerPhoneNumber(customerId, request.id);
      }
    }
  }

  // Get customer phone number from user document
  Future<String> _getCustomerPhoneNumber(
    String customerId,
    String requestId,
  ) async {
    // Check cache first
    if (_phoneNumberCache.containsKey(customerId)) {
      return _phoneNumberCache[customerId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();

      if (userDoc.exists) {
        final phone =
            userDoc.data()?['phoneNumber'] ?? userDoc.data()?['phone'] ?? '';

        if (phone.isNotEmpty) {
          // Save to cache
          _phoneNumberCache[customerId] = phone;

          // Update the service request document
          await FirebaseFirestore.instance
              .collection('service_requests')
              .doc(requestId)
              .update({'userPhone': phone});

          print('✅ Updated phone for request $requestId: $phone');

          // Refresh the UI
          if (mounted) {
            setState(() {});
          }

          return phone;
        }
      }
    } catch (e) {
      print('Error fetching customer phone: $e');
    }

    return '';
  }

  Future<void> _completeRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!_isActive || !mounted) return;

      // Move from accepted to completed list
      var requestDoc = acceptedRequests.firstWhere(
        (doc) => doc.id == requestId,
      );
      setState(() {
        acceptedRequests.removeWhere((doc) => doc.id == requestId);
        completedRequests.insert(0, requestDoc);
      });

      // Send notification to customer
      Map<String, dynamic> data = requestDoc.data() as Map<String, dynamic>;
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': data['userId'],
        'userRole': 'customer',
        'title': '✅ Service Completed!',
        'body': 'Your service request has been marked as completed.',
        'type': 'service_completed',
        'requestId': requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!_isActive || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service marked as completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error completing request: $e');
      if (!_isActive || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Open Chat Screen
  void _openChat(String requestId, String customerId, String customerName) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final conversationId = '${requestId}_${customerId}_${currentUser.uid}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          requestId: requestId,
          otherUserId: customerId,
          otherUserName: customerName,
          otherUserRole: 'customer',
        ),
      ),
    );
  }

  // Make Phone Call - Opens dialer with number
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available for this customer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      if (!_isActive || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error making call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2563EB),
              tabs: [
                Tab(text: 'Active (${acceptedRequests.length})'),
                Tab(text: 'Completed (${completedRequests.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_buildActiveRequests(), _buildCompletedRequests()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequests() {
    if (acceptedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Active Services',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Accepted service requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: acceptedRequests.length,
      itemBuilder: (context, index) {
        var request = acceptedRequests[index];
        Map<String, dynamic> data = request.data() as Map<String, dynamic>;
        return _buildServiceCard(request.id, data, isActive: true);
      },
    );
  }

  Widget _buildCompletedRequests() {
    if (completedRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Completed Services',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed service requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedRequests.length,
      itemBuilder: (context, index) {
        var request = completedRequests[index];
        Map<String, dynamic> data = request.data() as Map<String, dynamic>;
        return _buildServiceCard(request.id, data, isActive: false);
      },
    );
  }

  Widget _buildServiceCard(
    String requestId,
    Map<String, dynamic> data, {
    required bool isActive,
  }) {
    String customerName = data['userName'] ?? 'Customer';
    String customerId = data['userId'] ?? '';
    String customerPhone = data['userPhone'] ?? '';

    // If phone is empty, try to get it from cache or fetch
    if (customerPhone.isEmpty && customerId.isNotEmpty) {
      // Check cache
      if (_phoneNumberCache.containsKey(customerId)) {
        customerPhone = _phoneNumberCache[customerId]!;
      } else {
        // Trigger fetch in background
        _getCustomerPhoneNumber(customerId, requestId);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive ? Icons.build : Icons.check_circle,
                  color: isActive ? const Color(0xFF2563EB) : Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['serviceName'] ?? 'Service Request',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${data['budget']?.toString() ?? '0'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
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
                  color: isActive
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'COMPLETED',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.blue : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(customerName, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        customerPhone.isEmpty
                            ? 'Fetching number...'
                            : customerPhone,
                        style: TextStyle(
                          fontSize: 14,
                          color: customerPhone.isEmpty
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                    if (customerPhone.isEmpty && customerId.isNotEmpty)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['location'] ?? 'Location not specified',
                  style: const TextStyle(fontSize: 14),
                ),
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
                  Text(data['issue'], style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (isActive)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _openChat(requestId, customerId, customerName),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: customerPhone.isEmpty
                        ? null
                        : () => _makePhoneCall(customerPhone),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _completeRequest(requestId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Complete'),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: () => _showCompletedDetails(data),
              icon: const Icon(Icons.visibility),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
        ],
      ),
    );
  }

  void _showCompletedDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['serviceName'] ?? 'Service Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer', data['userName'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Phone', data['userPhone'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Location', data['location'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Pincode', data['pincode'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Budget', '₹${data['budget'] ?? 0}'),
              const SizedBox(height: 8),
              _buildDetailRow('Issue', data['issue'] ?? 'N/A'),
              if (data['completedAt'] != null)
                _buildDetailRow(
                  'Completed On',
                  _formatDate(data['completedAt']),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
