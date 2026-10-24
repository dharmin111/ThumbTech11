// lib/presentation/CostomerScreens/FindingTechnicianScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../DashBoard/CustomerDashboard.dart';
import '../authScreen/ChatScreen.dart';

class FindingTechnicianScreen extends StatefulWidget {
  final String requestId;

  const FindingTechnicianScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<FindingTechnicianScreen> createState() => _FindingTechnicianScreenState();
}

class _FindingTechnicianScreenState extends State<FindingTechnicianScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isChatLoading = false;

  String _getServiceImagePath(String? serviceName) {
    if (serviceName == null) return 'assets/Appliance/Ap1.png';
    final name = serviceName.toLowerCase();
    if (name.contains('ac')) return 'assets/Appliance/Ac.jpeg';
    if (name.contains('washing')) return 'assets/Appliance/Ap1.png';
    if (name.contains('water') || name.contains('ro') || name.contains('purifier')) return 'assets/Appliance/waterp.jpeg';
    if (name.contains('microwave')) return 'assets/Appliance/ap2.png';
    if (name.contains('chimney')) return 'assets/Appliance/chimney.jpeg';
    if (name.contains('geyser')) return 'assets/Appliance/ap3.png';
    if (name.contains('cctv')) return 'assets/Appliance/hm1.png';
    if (name.contains('tv')) return 'assets/Appliance/ap8.png';
    if (name.contains('plumbing')) return 'assets/Appliance/ap4.png';
    if (name.contains('cooler')) return 'assets/Appliance/ap6.png';
    if (name.contains('refrigerator') || name.contains('fridge')) return 'assets/Appliance/ap7.png';
    if (name.contains('carpenter')) return 'assets/Appliance/ap5.png';
    if (name.contains('tank')) return 'assets/Appliance/hm2.png';
    if (name.contains('electric')) return 'assets/Appliance/elec1.png';
    return 'assets/Appliance/Ap1.png';
  }

  void _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch call to $phoneNumber')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error making call: $e')),
      );
    }
  }

  Future<void> _openChat({
    required String requestId,
    required String customerId,
    required String customerName,
    required String technicianId,
    required String technicianName,
    String? technicianProfileImage,
  }) async {
    if (_isChatLoading) return;

    setState(() => _isChatLoading = true);

    try {
      final ids = [customerId, technicianId]..sort();
      final conversationId = '${ids[0]}_${ids[1]}_$requestId';

      final conversationRef = _firestore.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        await conversationRef.set({
          'conversationId': conversationId,
          'requestId': requestId,
          'customerId': customerId,
          'customerName': customerName,
          'technicianId': technicianId,
          'technicianName': technicianName,
          'status': 'active',
          'lastMessage': 'Conversation started',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'customerUnreadCount': 0,
          'technicianUnreadCount': 0,
        });
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            requestId: requestId,
            otherUserId: technicianId,
            otherUserName: technicianName,
            otherUserRole: 'technician',
            otherUserProfileImage: technicianProfileImage,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChatLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryCyan = Color(0xFF00C4CC);
    const darkBlue = Color(0xFF0C1B4D);
    final double topPadding = MediaQuery.of(context).padding.top;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const CustomerDashboard()),
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('service_requests').doc(widget.requestId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(primaryCyan)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('Service request not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerDashboard()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryCyan),
                    child: const Text('Go to Home', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'pending').toString().toLowerCase();

          final String? techId = data['technicianId'];
          final String? techName = data['technicianName'];
          final String? techPhone = data['technicianPhone'];
          final String? techProfilePic = data['technicianProfileImage'] ?? data['profileImageUrl'];

          final bool isAccepted = (status == 'accepted' || status == 'assigned' || status == 'in_progress') ||
              (techId != null && techId.isNotEmpty && techName != null && techName.isNotEmpty);

          final String bookingIdShort = widget.requestId.length >= 4
              ? widget.requestId.substring(0, 4).toUpperCase()
              : widget.requestId.toUpperCase();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ========================================================
                // UPPER MAP / BANNER IMAGE SECTION WITH LOGO & CLOSE BUTTON
                // ========================================================
                SizedBox(
                  width: double.infinity,
                  height: 340,
                  child: Stack(
                    children: [
                      // LAYER 1: Full-width Map / Status Image
                      Positioned.fill(
                        child: Image.asset(
                          isAccepted
                              ? 'assets/images/AcceptTech.PNG'
                              : 'assets/images/Fetching.PNG',
                          width: double.infinity,
                          height: double.infinity,
                          alignment: const Alignment(0.0, 0.1),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              color: const Color(0xFFE2E8F0),
                              child: const Center(
                                child: Icon(Icons.map_outlined, size: 60, color: darkBlue),
                              ),
                            );
                          },
                        ),
                      ),

                      // LAYER 2: TOP HEADER OVERLAY (ThumbTech Logo & Close 'X' Button)
                      Positioned(
                        top: topPadding + 10,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                          SizedBox(height: 10,),

                            // Close Button 'X'
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: darkBlue, size: 20),
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CustomerDashboard()),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ========================================================
                // LOWER ROUNDED SHEET CONTENT
                // ========================================================
                Transform.translate(
                  offset: const Offset(0, 10),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    child: Column(
                      children: [
                        // SMALL GRAY HANDLE BAR
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ========================================================
                        // STATE 1: SEARCHING / FINDING TECHNICIAN
                        // ========================================================
                        if (!isAccepted) ...[
                          // CIRCULAR PROGRESS INDICATOR
                          const SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // HEADING TEXT
                          const Text(
                            'Finding A Technician\nNear You...',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                              height: 1.25,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),

                          // SERVICE CATEGORY CARD (Image, Title, Booking ID)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    _getServiceImagePath(data['serviceName']),
                                    width: 75,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(1.6, 0.0),
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 75,
                                      height: 56,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.build, color: darkBlue),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 28),

                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 2),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['serviceName'] ?? 'Service Repair',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: darkBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Booking ID: TT-$bookingIdShort',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // INFORMATIONAL BANNER BOX
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Please keep the app open while we find an available technician.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF0369A1),
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ]

                        // ========================================================
                        // STATE 2: TECHNICIAN ASSIGNED / ACCEPTED! (EXACT MATCH FOR USER SCREENSHOT)
                        // ========================================================
                        else ...[
                          // HEADER ROW: STATUS & ARRIVING SOON BADGE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        RichText(
                                          text: const TextSpan(
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: darkBlue,
                                            ),
                                            children: [
                                              TextSpan(text: 'Task  '),
                                              TextSpan(
                                                text: 'Accepted',
                                                style: TextStyle(color: Color(0xFF10B981)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Technician is on the way to your location.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Container(
                              //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              //   decoration: BoxDecoration(
                              //     color: const Color(0xFFE0F2FE),
                              //     borderRadius: BorderRadius.circular(20),
                              //   ),
                              //   child: const Row(
                              //     mainAxisSize: MainAxisSize.min,
                              //     children: [
                              //       Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7), size: 16),
                              //       SizedBox(width: 4),
                              //       Text(
                              //         'Arriving soon',
                              //         style: TextStyle(
                              //           color: Color(0xFF0284C7),
                              //           fontWeight: FontWeight.bold,
                              //           fontSize: 11,
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // TECHNICIAN PROFILE CARD WITH CALL & MESSAGE BUTTONS
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // AVATAR WITH ONLINE DOT (Image.network)
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 36,
                                          backgroundColor: primaryCyan.withOpacity(0.2),
                                          backgroundImage: (techProfilePic != null && techProfilePic.trim().isNotEmpty)
                                              ? NetworkImage(techProfilePic)
                                              : null,
                                          child: (techProfilePic == null || techProfilePic.trim().isEmpty)
                                              ? const Icon(Icons.person, size: 40, color: darkBlue)
                                              : null,
                                        ),
                                        Positioned(
                                          right: 2,
                                          top: 2,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            techName ?? 'Technician',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: darkBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            data['serviceType'] ?? 'Appliance Technician',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              const Text(
                                                '4.8',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '|',
                                                style: TextStyle(color: Colors.grey.shade400),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '120+ jobs completed',
                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // CALL & MESSAGE BUTTONS
                                Row(
                                  children: [
                                    // CALL BUTTON
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _makePhoneCall(techPhone ?? ''),
                                        icon: const Icon(Icons.phone_outlined, color: darkBlue, size: 18),
                                        label: const Text(
                                          'Call',
                                          style: TextStyle(
                                            color: darkBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: darkBlue, width: 1.5),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // MESSAGE / CHAT BUTTON
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isChatLoading
                                            ? null
                                            : () {
                                                final currentUser = _auth.currentUser;
                                                if (currentUser == null) return;

                                                _openChat(
                                                  requestId: widget.requestId,
                                                  customerId: currentUser.uid,
                                                  customerName: data['userName'] ?? 'Customer',
                                                  technicianId: techId!,
                                                  technicianName: techName ?? 'Technician',
                                                  technicianProfileImage: techProfilePic,
                                                );
                                              },
                                        icon: _isChatLoading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: primaryCyan),
                                              )
                                            : const Icon(Icons.chat_bubble_outline, color: primaryCyan, size: 18),
                                        label: Text(
                                          _isChatLoading ? 'Opening...' : 'Message',
                                          style: const TextStyle(
                                            color: primaryCyan,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: primaryCyan, width: 1.5),
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
                            ),
                          ),

                          const SizedBox(height: 12),

                          // SERVICE CATEGORY TILE
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    _getServiceImagePath(data['serviceName']),
                                    width: 75,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(1, 0.0),
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(width: 75, height: 56, color: Colors.grey.shade200),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['serviceName'] ?? 'Washing Machine Repair',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: darkBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Booking ID: TT-$bookingIdShort',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // SERVICE ADDRESS TILE
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Service address',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        data['location'] ?? 'Near Parivar Char Rasta, Vadodara',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: darkBlue,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                              ],
                            ),
                          ),

                          const SizedBox(height: 10),
                          const SizedBox(height: 10),

                          // INFORMATIONAL BANNER BOX
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Please discuss the work, cost and timing with technician before sharing full address.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0369A1),
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                // const Icon(
                                //   Icons.chevron_right,
                                //   color: Color(0xFF0369A1),
                                //   size: 18,
                                // ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}
