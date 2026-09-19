import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thumstechs/presentation/authScreen/ChatScreen.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTechnicianDataSeen extends StatefulWidget {
  final String userId;
  final String userRole;
  final String? requestId;

  const CustomerTechnicianDataSeen({
    super.key,
    required this.userId,
    required this.userRole,
    this.requestId,
  });

  @override
  State<CustomerTechnicianDataSeen> createState() =>
      _CustomerTechnicianDataSeenState();
}

class _CustomerTechnicianDataSeenState
    extends State<CustomerTechnicianDataSeen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          _userData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
        print('✅ User data loaded: ${_userData?['name']}');
        print('📊 Role: ${_userData?['role']}');
        print('📸 Work Images: ${_userData?['workImages']}');
        print('✅ Verified: ${_userData?['isVerified']}');
      } else {
        setState(() {
          _isLoading = false;
        });
        print('❌ User document not found');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  void _openChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String requestId = widget.requestId ?? _userData?['requestId'] ?? '';

      if (requestId.isEmpty) {
        requestId = 'CHAT_${DateTime.now().millisecondsSinceEpoch}';
      }

      String conversationId = _generateConversationId(
        currentUser.uid,
        widget.userId,
        requestId,
      );

      await _createConversationIfNotExists(conversationId, requestId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            requestId: requestId,
            otherUserId: widget.userId,
            otherUserName: _userData?['name'] ?? 'User',
            otherUserRole: widget.userRole,
            otherUserProfileImage: _userData?['profileImageUrl'] ?? '',
          ),
        ),
      );
    } catch (e) {
      print('Error opening chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateConversationId(String userId1, String userId2, String requestId) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}_$requestId';
  }

  Future<void> _createConversationIfNotExists(String conversationId, String requestId) async {
    try {
      final conversationRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId);

      final conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        final currentUser = FirebaseAuth.instance.currentUser!;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userName = userDoc.data()?['name'] ?? currentUser.displayName ?? 'User';

        final String customerId;
        final String customerName;
        final String technicianId;
        final String technicianName;

        if (widget.userRole == 'customer') {
          customerId = widget.userId;
          customerName = _userData?['name'] ?? 'Customer';
          technicianId = currentUser.uid;
          technicianName = userName;
        } else {
          customerId = currentUser.uid;
          customerName = userName;
          technicianId = widget.userId;
          technicianName = _userData?['name'] ?? 'Technician';
        }

        await conversationRef.set({
          'conversationId': conversationId,
          'requestId': requestId,
          'customerId': customerId,
          'customerName': customerName,
          'technicianId': technicianId,
          'technicianName': technicianName,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'customerUnreadCount': 0,
          'technicianUnreadCount': 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating conversation: $e');
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWorkImageFull(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 300,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42D7D7)),
          ),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'User Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off,
                size: 80,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'User not found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _userData!;
    String role = data['role'] ?? 'user';
    String name = data['name'] ?? 'Unknown User';
    String email = data['email'] ?? 'No email';
    String phone = data['phone'] ?? data['phoneNumber'] ?? 'No phone';
    String profileImage = data['profileImageUrl'] ?? '';
    List<dynamic> pincodes = data['pincodes'] ?? [];
    bool isVerified = data['isVerified'] ?? false;
    String address = data['address'] ?? 'Not provided';
    String city = data['city'] ?? 'Not provided';
    String state = data['state'] ?? 'Not provided';
    String description = data['description'] ?? '';
    List<dynamic> workImages = data['workImages'] ?? [];
    String introVideoUrl = data['introVideoUrl'] ?? '';
    String idCardImage = data['idCardImage'] ?? '';
    List<dynamic> categories = data['categories'] ?? [];
    String status = data['status'] ?? 'pending';

    bool isTechnician = role == 'technician';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isTechnician ? 'Technician Profile' : 'Customer Profile',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,

      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF42D7D7).withOpacity(0.1),
                    const Color(0xFF42D7D7).withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Profile Image
                  GestureDetector(
                    onTap: () {
                      if (profileImage.isNotEmpty) {
                        _showFullImage(profileImage);
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isVerified ? Colors.green : const Color(0xFF42D7D7),
                              width: isVerified ? 4 : 3,
                            ),
                            image: profileImage.isNotEmpty
                                ? DecorationImage(
                              image: NetworkImage(profileImage),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: profileImage.isEmpty
                              ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.grey,
                          )
                              : null,
                        ),
                        if (isVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0C1B4D),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTechnician
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isTechnician ? '🛠️ Technician' : '👤 Customer',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isTechnician
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),

                  // Verified Badge Text
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verified Professional',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Contact Info Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.contact_phone,
                        color: Color(0xFF42D7D7),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0C1B4D),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Email
                  _buildDetailRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: email,
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  _buildDetailRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: phone,
                  ),
                  const SizedBox(height: 12),

                  // Role
                  _buildDetailRow(
                    icon: Icons.person_outline,
                    label: 'Role',
                    value: isTechnician ? 'Technician' : 'Customer',
                  ),
                  const SizedBox(height: 12),

                  // Address
                  if (address.isNotEmpty && address != 'Not provided')
                    _buildDetailRow(
                      icon: Icons.location_on,
                      label: 'Address',
                      value: address,
                    ),
                  const SizedBox(height: 12),

                  // City
                  if (city.isNotEmpty && city != 'Not provided')
                    _buildDetailRow(
                      icon: Icons.location_city,
                      label: 'City',
                      value: city,
                    ),
                  const SizedBox(height: 12),

                  // State
                  if (state.isNotEmpty && state != 'Not provided')
                    _buildDetailRow(
                      icon: Icons.map,
                      label: 'State',
                      value: state,
                    ),
                  const SizedBox(height: 12),

                  // // Pincodes
                  // if (pincodes.isNotEmpty)
                  //   _buildDetailRow(
                  //     icon: Icons.local_post_office,
                  //     label: 'Pincodes',
                  //     value: pincodes.join(', '),
                  //   ),
                ],
              ),
            ),

            // Technician Specific Info
            if (isTechnician) ...[
              const SizedBox(height: 16),

              // Categories Card
              // if (categories.isNotEmpty)
              //   Container(
              //     margin: const EdgeInsets.symmetric(horizontal: 16),
              //     padding: const EdgeInsets.all(16),
              //     decoration: BoxDecoration(
              //       color: Colors.white,
              //       borderRadius: BorderRadius.circular(16),
              //       boxShadow: [
              //         BoxShadow(
              //           color: Colors.grey.withOpacity(0.05),
              //           blurRadius: 10,
              //           offset: const Offset(0, 2),
              //         ),
              //       ],
              //     ),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         const Row(
              //           children: [
              //             Icon(
              //               Icons.category,
              //               color: Color(0xFF42D7D7),
              //               size: 20,
              //             ),
              //             SizedBox(width: 8),
              //             Text(
              //               'Service Categories',
              //               style: TextStyle(
              //                 fontSize: 16,
              //                 fontWeight: FontWeight.bold,
              //                 color: Color(0xFF0C1B4D),
              //               ),
              //             ),
              //           ],
              //         ),
              //         const Divider(height: 24),
              //         Wrap(
              //           spacing: 8,
              //           runSpacing: 8,
              //           children: categories.map((category) {
              //             return Container(
              //               padding: const EdgeInsets.symmetric(
              //                 horizontal: 12,
              //                 vertical: 6,
              //               ),
              //               decoration: BoxDecoration(
              //                 color: const Color(0xFF42D7D7).withOpacity(0.1),
              //                 borderRadius: BorderRadius.circular(20),
              //                 border: Border.all(
              //                   color: const Color(0xFF42D7D7).withOpacity(0.3),
              //                 ),
              //               ),
              //               child: Text(
              //                 category.toString(),
              //                 style: const TextStyle(
              //                   fontSize: 12,
              //                   color: Color(0xFF42D7D7),
              //                   fontWeight: FontWeight.w500,
              //                 ),
              //               ),
              //             );
              //           }).toList(),
              //         ),
              //       ],
              //     ),
              //   ),

              const SizedBox(height:1),

              // Description Card
              if (description.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.description,
                            color: Color(0xFF42D7D7),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'About',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C1B4D),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0C1B4D),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Work Images Card
              if (workImages.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.photo_library,
                            color: Color(0xFF42D7D7),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Work Samples',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C1B4D),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: workImages.length > 6 ? 6 : workImages.length,
                        itemBuilder: (context, index) {
                          String imageUrl = workImages[index].toString();
                          return GestureDetector(
                            onTap: () => _showWorkImageFull(imageUrl),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (workImages.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: Text(
                              '+${workImages.length - 6} more images',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

             ],

            const SizedBox(height: 2),

            // Action Buttons
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  Row(
                    children: [
                      // Call Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (phone.isNotEmpty && phone != 'No phone') {
                              _makePhoneCall(phone);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone number not available'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.phone, size: 20),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Chat Button
                      // Expanded(
                      //   child: ElevatedButton.icon(
                      //     onPressed: _openChat,
                      //     icon: const Icon(Icons.chat, size: 20),
                      //     label: const Text('Chat'),
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: const Color(0xFF42D7D7),
                      //       foregroundColor: Colors.white,
                      //       padding: const EdgeInsets.symmetric(vertical: 14),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(12),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF42D7D7).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF42D7D7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0C1B4D),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}