// widgets/TechnicianMyServicesScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thumstechs/presentation/DashBoard/TechnicianDashboard.dart';
import 'package:thumstechs/presentation/TechnicianScreen/TechnicianHomeScreen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../authScreen/ChatScreen.dart';
import '../../profile/customer_technician_data_seen.dart';

class TechnicianMyServicesScreen extends StatefulWidget {
  const TechnicianMyServicesScreen({super.key});

  @override
  State<TechnicianMyServicesScreen> createState() =>
      _TechnicianMyServicesScreenState();
}

class _TechnicianMyServicesScreenState
    extends State<TechnicianMyServicesScreen>
    with SingleTickerProviderStateMixin {
  List<QueryDocumentSnapshot> acceptedRequests = [];
  List<QueryDocumentSnapshot> completedRequests = [];
  bool isLoading = true;
  bool _isActive = true;

  late TabController _tabController;

  final Map<String, String> _phoneNumberCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _isActive = false;
    super.dispose();
  }

  // ✅ Check if visiting charges text should show
  bool _shouldShowVisitingChargesText(Map<String, dynamic> data) {
    String serviceType = data['serviceType']?.toString() ?? '';
    double budget = (data['budget'] ?? 0).toDouble();

    bool isWaterPurifier = serviceType.toLowerCase().contains('water purifier');
    bool isBudget199 = budget == 199.0;

    return isWaterPurifier && isBudget199;
  }

  Future<void> _fetchMyServices() async {
    if (!_isActive || !mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot acceptedSnapshot = await FirebaseFirestore.instance
            .collection('service_requests')
            .where('technicianId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'accepted')
            .orderBy('acceptedAt', descending: true)
            .get();

        if (!_isActive || !mounted) return;

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

  Future<String> _getCustomerPhoneNumber(
      String customerId,
      String requestId,
      ) async {
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
          _phoneNumberCache[customerId] = phone;

          await FirebaseFirestore.instance
              .collection('service_requests')
              .doc(requestId)
              .update({'userPhone': phone});

          print('✅ Updated phone for request $requestId: $phone');

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

      var requestDoc = acceptedRequests.firstWhere(
            (doc) => doc.id == requestId,
      );
      setState(() {
        acceptedRequests.removeWhere((doc) => doc.id == requestId);
        completedRequests.insert(0, requestDoc);
      });

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

  // ═══════════════════════════════════════════════════════
  // ✅ NEW: OPEN MAP
  // ═══════════════════════════════════════════════════════
  //
  // Priority:
  //   1. locationModel (lat/lng) → exact map pin
  //   2. location (address text) → Google Maps search
  //
  Future<void> _openMap(Map<String, dynamic> data) async {
    try {
      // ✅ Try locationModel first (GPS coordinates)
      final locationData =
          data['locationModel'] ?? data['location'] ?? data['locationModel'];

      double? latitude;
      double? longitude;
      String? address;

      // Case 1: locationModel is a Map with lat/lng
      if (locationData is Map<String, dynamic>) {
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        address = locationData['address'];

        if (lat != null && lng != null) {
          latitude = (lat as num).toDouble();
          longitude = (lng as num).toDouble();
        }
      }
      // Case 2: locationModel is a GeoPoint
      else if (locationData is GeoPoint) {
        latitude = locationData.latitude;
        longitude = locationData.longitude;
      }

      // ✅ Fallback: use address string
      if (latitude == null || longitude == null) {
        final addressText = data['location'] as String? ?? '';
        if (addressText.isNotEmpty) {
          final Uri url = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addressText)}',
          );

          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            _showSnack('Cannot open Google Maps', Colors.red);
          }
          return;
        } else {
          _showSnack('No location available for this customer', Colors.orange);
          return;
        }
      }

      // ✅ Open exact coordinates
      final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );

      print('🗺️ Opening map: $latitude, $longitude');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Cannot open Google Maps', Colors.red);
      }
    } catch (e) {
      print('❌ Error opening map: $e');
      _showSnack('Error opening map: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ NEW: OPEN MAP WITH DIRECTIONS (Optional)
  // ═══════════════════════════════════════════════════════
  Future<void> _openMapWithDirections(Map<String, dynamic> data) async {
    try {
      final locationData = data['locationModel'];

      double? latitude;
      double? longitude;

      if (locationData is Map<String, dynamic>) {
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        if (lat != null && lng != null) {
          latitude = (lat as num).toDouble();
          longitude = (lng as num).toDouble();
        }
      } else if (locationData is GeoPoint) {
        latitude = locationData.latitude;
        longitude = locationData.longitude;
      }

      if (latitude == null || longitude == null) {
        _showSnack('No GPS location available', Colors.orange);
        return;
      }

      final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Cannot open Google Maps', Colors.red);
      }
    } catch (e) {
      print('❌ Error opening directions: $e');
      _showSnack('Error: $e', Colors.red);
    }
  }

  // ✅ Helper: Check if location is available
  bool _hasLocation(Map<String, dynamic> data) {
    final locationModel = data['locationModel'];

    if (locationModel is Map<String, dynamic>) {
      return locationModel['latitude'] != null &&
          locationModel['longitude'] != null;
    }

    if (locationModel is GeoPoint) {
      return true;
    }

    // Fallback: check address text
    final address = data['location'] as String? ?? '';
    return address.isNotEmpty;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Open Chat Screen
  void _openChat(String requestId, String customerId, String customerName,
      String? customerProfileImage) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final List<String> ids = [customerId, currentUser.uid]..sort();
    final conversationId = '${ids[0]}_${ids[1]}_$requestId';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversationId,
          requestId: requestId,
          otherUserId: customerId,
          otherUserName: customerName,
          otherUserRole: 'customer',
          otherUserProfileImage: customerProfileImage,
        ),
      ),
    );
  }

  void _viewCustomerProfile(String customerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerTechnicianDataSeen(
          userId: customerId,
          userRole: 'customer',
        ),
      ),
    );
  }

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
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Services',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C1B4D),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0C1B4D)),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TechnicianDashboard()),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2563EB),
          tabs: [
            Tab(text: 'Active (${acceptedRequests.length})'),
            Tab(text: 'Completed (${completedRequests.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveRequests(),
          _buildCompletedRequests(),
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
    String customerProfileImage = data['profileImageUrl'] ?? '';

    bool showVisitingCharges = _shouldShowVisitingChargesText(data);
    bool hasLocation = _hasLocation(data);

    if (customerPhone.isEmpty && customerId.isNotEmpty) {
      if (_phoneNumberCache.containsKey(customerId)) {
        customerPhone = _phoneNumberCache[customerId]!;
      } else {
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
            color: Colors.grey.withOpacity(0.05),
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
              GestureDetector(
                onTap: () => _viewCustomerProfile(customerId),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                  backgroundImage: customerProfileImage.isNotEmpty
                      ? NetworkImage(customerProfileImage)
                      : null,
                  child: customerProfileImage.isEmpty
                      ? Text(
                    customerName.isNotEmpty
                        ? customerName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                      : null,
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
                    Row(
                      children: [
                        Text(
                          '₹${(data['budget'] ?? 0).toInt().toString()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                        if (showVisitingCharges) ...[
                          const SizedBox(width: 2),
                          Text(
                            'Visiting Charges',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
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
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
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

          // Customer Name
          GestureDetector(
            onTap: () => _viewCustomerProfile(customerId),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Phone
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
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Location
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

          // ✅ VIEW ON MAP BUTTON (NEW)
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: hasLocation ? () => _openMap(data) : null,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                hasLocation
                    ? 'Get Direction'
                    : 'No location available',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: BorderSide(
                  color: hasLocation
                      ? const Color(0xFF2563EB)
                      : Colors.grey.shade300,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                    onPressed: () => _openChat(
                      requestId,
                      customerId,
                      customerName,
                      customerProfileImage,
                    ),
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
    bool showVisitingCharges = _shouldShowVisitingChargesText(data);

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
              if (showVisitingCharges) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '199 Visiting Charges',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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