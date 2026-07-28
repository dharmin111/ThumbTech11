// screens/ServiceRequestDetailScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../model/ServiceRequestModel.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic>? requestData;

  const ServiceRequestDetailScreen({
    super.key,
    required this.requestId,
    this.requestData,
  });

  @override
  State<ServiceRequestDetailScreen> createState() =>
      _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState
    extends State<ServiceRequestDetailScreen> {
  late YoutubePlayerController _youtubeController;
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  bool _isFromBanner = false;

  // 🔥 Form Controllers
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedServiceType = 'Washing Machine Cleaning';
  final bool _showForm = false;

  final FirebaseFirestoreStorageCustomerOrder _firestoreService =
      FirebaseFirestoreStorageCustomerOrder();

  final String _videoId = '4W5nWPEoy7Y';

  @override
  void initState() {
    super.initState();

    if (widget.requestData != null) {
      _requestData = widget.requestData;
      _isFromBanner = widget.requestData?['isFromBanner'] ?? false;
      _selectedServiceType =
          _requestData?['serviceName'] ?? 'Washing Machine Cleaning';
      _isLoading = false;
    }

    final videoId = widget.requestData?['videoId'] ?? '4W5nWPEoy7Y';

    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );

    _loadUserData();
  }

  @override
  void dispose() {
    _youtubeController.close();
    _pincodeController.dispose();
    _addressController.dispose();
    _fullNameController.dispose();
    _mobileController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _fullNameController.text = data?['name'] ?? '';
          _mobileController.text = data?['phone'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadRequestData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(widget.requestId)
          .get();

      if (doc.exists) {
        setState(() {
          _requestData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading request: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackbar('Please login first', Colors.red);
      return;
    }

    // Validation
    if (_pincodeController.text.isEmpty) {
      _showSnackbar('Please enter your pincode', Colors.red);
      return;
    }
    if (_addressController.text.isEmpty) {
      _showSnackbar('Please enter your address', Colors.red);
      return;
    }
    if (_fullNameController.text.isEmpty) {
      _showSnackbar('Please enter your full name', Colors.red);
      return;
    }
    if (_mobileController.text.isEmpty) {
      _showSnackbar('Please enter your mobile number', Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 🔥 Convert DateTime to Timestamp
      final Timestamp createdAtTimestamp = Timestamp.fromDate(DateTime.now());

      final String videoId = _requestData?['videoId'] ?? '';

      final request = ServiceRequestModel(
        userId: user.uid,
        videoId: videoId,
        serviceName: _selectedServiceType,
        serviceType: _selectedServiceType,
        userName: _fullNameController.text,
        userPhone: _mobileController.text,
        userEmail: user.email ?? '',
        location: _addressController.text,
        pincode: _pincodeController.text,
        budget: (_requestData?['budget'] ?? 999).toDouble(),
        issue: _issueController.text,
        status: 'pending',
        createdAt: createdAtTimestamp, // 🔥 Pass Timestamp here
        additionalNote: '',
        imageUrls: [],
        updatedAt: createdAtTimestamp,
      );

      final requestId = await _firestoreService.saveServiceRequestWithMatching(
        request: request,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackbar(
          '✅ Service request submitted! ID: #${requestId.substring(0, 8).toUpperCase()}',
          Colors.green,
        );

        // Clear form
        _pincodeController.clear();
        _addressController.clear();
        _issueController.clear();

        // Navigate back after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showSnackbar('Error: $e', Colors.red);
    }
  }

  // Future<void> _submitRequest() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) {
  //     _showSnackbar('Please login first', Colors.red);
  //     return;
  //   }
  //
  //   // Validation
  //   if (_pincodeController.text.isEmpty) {
  //     _showSnackbar('Please enter your pincode', Colors.red);
  //     return;
  //   }
  //   if (_addressController.text.isEmpty) {
  //     _showSnackbar('Please enter your address', Colors.red);
  //     return;
  //   }
  //   if (_fullNameController.text.isEmpty) {
  //     _showSnackbar('Please enter your full name', Colors.red);
  //     return;
  //   }
  //   if (_mobileController.text.isEmpty) {
  //     _showSnackbar('Please enter your mobile number', Colors.red);
  //     return;
  //   }
  //
  //   setState(() {
  //     _isSubmitting = true;
  //   });
  //
  //   try {
  //     // 🔥 Convert DateTime to Timestamp
  //     final Timestamp createdAtTimestamp = Timestamp.fromDate(DateTime.now());
  //
  //     final request = ServiceRequestModel(
  //       userId: user.uid,
  //       serviceName: _selectedServiceType,
  //       serviceType: _selectedServiceType,
  //       userName: _fullNameController.text,
  //       userPhone: _mobileController.text,
  //       userEmail: user.email ?? '',
  //       location: _addressController.text,
  //       pincode: _pincodeController.text,
  //       budget: (_requestData?['budget'] ?? 999).toDouble(),
  //       issue: _issueController.text,
  //       status: 'pending',
  //       createdAt: createdAtTimestamp,
  //       additionalNote: '',
  //       imageUrls: [],
  //       updatedAt: createdAtTimestamp,
  //     );
  //
  //     // 🔥 Save to Firestore - This handles all notifications internally
  //     // Notification is sent inside saveServiceRequestWithMatching()
  //     final requestId = await _firestoreService.saveServiceRequestWithMatching(
  //       request: request,
  //     );
  //
  //     if (mounted) {
  //       setState(() {
  //         _isSubmitting = false;
  //       });
  //       _showSnackbar(
  //         '✅ Service request submitted! ID: #${requestId.substring(0, 8).toUpperCase()}',
  //         Colors.green,
  //       );
  //
  //       // Clear form
  //       _pincodeController.clear();
  //       _addressController.clear();
  //       _issueController.clear();
  //
  //       // Navigate back after 2 seconds
  //       Future.delayed(const Duration(seconds: 2), () {
  //         if (mounted) {
  //           Navigator.pop(context);
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isSubmitting = false;
  //     });
  //     _showSnackbar('Error: $e', Colors.red);
  //   }
  // }
  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Service Request'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: const Center(child: Text('Request not found')),
      );
    }

    final data = _requestData!;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          data['serviceName'] ?? 'Service Request',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== VIDEO SECTION ====================
            _buildVideoSection(),

            const SizedBox(height: 2),

            // ==================== BANNER IMAGE ====================
            _buildInBetweenBanner(),

            const SizedBox(height: 2),

            // ==================== CUSTOMER DETAILS ====================
            // _buildCustomerDetails(data),
            // const SizedBox(height: 16),

            // ==================== SERVICE DETAILS ====================
            // _buildServiceDetails(data),
            // const SizedBox(height: 16),

            // 🔥 ==================== BOOKING FORM ====================
            _buildBookingForm(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ==================== REQUEST CARD ====================
  Widget _buildRequestCard(Map<String, dynamic> data) {
    // 🔥 Safe substring
    String requestIdDisplay = widget.requestId;
    if (requestIdDisplay.length >= 8) {
      requestIdDisplay = requestIdDisplay.substring(0, 8).toUpperCase();
    } else {
      requestIdDisplay = requestIdDisplay.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF42D7D7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Special Offer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF42D7D7),
                  ),
                ),
              ),
              // Row(
              //   children: [
              //     _buildTimer('0:00', Colors.red),
              //     const SizedBox(width: 8),
              //     _buildTimer('1:23', Colors.green),
              //   ],
              // ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            data['serviceName'] ?? 'Service Request',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0C1B4D),
            ),
          ),
          // const SizedBox(height: 4),
          // Text(
          //   'Request ID: #$requestIdDisplay',
          //   style: TextStyle(
          //     fontSize: 12,
          //     color: Colors.grey[600],
          //   ),
          // ),
          // const SizedBox(height: 8),
          // Row(
          //   children: [
          //     Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
          //     const SizedBox(width: 6),
          //     Text(
          //       'Requested on: ${_formatDate(data['createdAt'])}',
          //       style: TextStyle(
          //         fontSize: 13,
          //         color: Colors.grey[600],
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 4),
          // Row(
          //   children: [
          //     Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
          //     const SizedBox(width: 6),
          //     Text(
          //       'Duration: ${data['duration'] ?? '40 mins'}',
          //       style: TextStyle(
          //         fontSize: 13,
          //         color: Colors.grey[600],
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 8),
          // Row(
          //   children: [
          //     const Text(
          //       'Price: ',
          //       style: TextStyle(
          //         fontSize: 16,
          //         fontWeight: FontWeight.w600,
          //         color: Color(0xFF0C1B4D),
          //       ),
          //     ),
          //     Text(
          //       '₹${data['budget'] ?? 0}',
          //       style: const TextStyle(
          //         fontSize: 18,
          //         fontWeight: FontWeight.bold,
          //         color: Color(0xFF42D7D7),
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 8),
          // Row(
          //   children: [
          //     Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
          //     const SizedBox(width: 6),
          //     Text(
          //       data['distance'] ?? '2.5 km away',
          //       style: TextStyle(
          //         fontSize: 13,
          //         color: Colors.grey[600],
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 4),
          // Row(
          //   children: [
          //     Icon(Icons.event, size: 14, color: Colors.grey[600]),
          //     const SizedBox(width: 6),
          //     Text(
          //       'Preferred Time: ${data['preferredTime'] ?? 'Not specified'}',
          //       style: TextStyle(
          //         fontSize: 13,
          //         color: Colors.grey[600],
          //       ),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  // ==================== VIDEO SECTION ====================
  Widget _buildVideoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Row(
          //   children: [
          //     Icon(Icons.video_library, color: Colors.red, size: 20),
          //     SizedBox(width: 8),
          //     Text(
          //       'How to Fix This Issue',
          //       style: TextStyle(
          //         fontSize: 16,
          //         fontWeight: FontWeight.bold,
          //         color: Color(0xFF0C1B4D),
          //       ),
          //     ),
          //   ],
          // ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayer(
              controller: _youtubeController,
              aspectRatio: 16 / 9,
            ),
          ),
          const SizedBox(height: 8),
          // Text(
          //   'Watch this tutorial to understand the service process',
          //   style: TextStyle(
          //     fontSize: 12,
          //     color: Colors.grey[600],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildInBetweenBanner() {
    return GestureDetector(
      // onTap: () {
      //   _onBannerTap();
      // },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: double.infinity,
        height: 187, //  Kam height (pehle 150 tha)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/AppLogoo/machine cleaning.PNG',
            width: double.infinity,
            height: 120, // 🔥 Match container height
            fit: BoxFit.fill, // 🔥 Changed from cover to fill
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 120,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Text(
                    'Banner not found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== CUSTOMER DETAILS ====================
  Widget _buildCustomerDetails(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: Color(0xFF42D7D7), size: 20),
              SizedBox(width: 8),
              Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1B4D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Full Name', data['userName'] ?? 'Customer'),
          _buildDetailRow('Mobile Number', data['userPhone'] ?? 'N/A'),
          _buildDetailRow('Address', data['location'] ?? 'N/A'),
          _buildDetailRow('Pincode', data['pincode'] ?? 'N/A'),
        ],
      ),
    );
  }

  // ==================== SERVICE DETAILS ====================
  Widget _buildServiceDetails(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF42D7D7), size: 20),
              SizedBox(width: 8),
              Text(
                'Service Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1B4D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Service Type', data['serviceName'] ?? 'N/A'),
          _buildDetailRow('Preferred Date', data['preferredDate'] ?? 'N/A'),
          _buildDetailRow('Preferred Time', data['preferredTime'] ?? 'N/A'),
          _buildDetailRow('Issue Description', data['issue'] ?? 'N/A'),
          if (data['additionalNote'] != null &&
              data['additionalNote'].isNotEmpty)
            _buildDetailRow('Additional Note', data['additionalNote']),
        ],
      ),
    );
  }

  // 🔥 ==================== BOOKING FORM ====================
  // Widget _buildBookingForm() {
  //   final double fixedBudget = 999.0;
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 16),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.grey.withOpacity(0.1),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Row(
  //           children: [
  //             Icon(Icons.edit_note, color: Color(0xFF42D7D7), size: 20),
  //             SizedBox(width: 8),
  //             Text(
  //               'Book This Service',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //                 color: Color(0xFF0C1B4D),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 16),
  //
  //         // 🔥 Service Type - Only Washing Machine Cleaning (No Dropdown)
  //         _buildFormLabel('Service Type'),
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  //           decoration: BoxDecoration(
  //             color: Colors.grey.shade50,
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(color: Colors.grey.shade200),
  //           ),
  //           child: Row(
  //             children: [
  //               const Icon(Icons.cleaning_services, color: Color(0xFF42D7D7), size: 20),
  //               const SizedBox(width: 10),
  //               Text(
  //                 _selectedServiceType,
  //                 style: const TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: FontWeight.w500,
  //                   color: Color(0xFF0C1B4D),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         // 🔥 Budget Display
  //         _buildFormLabel('Budget'),
  //         Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  //           decoration: BoxDecoration(
  //             color: Colors.grey.shade50,
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(color: Colors.grey.shade200),
  //           ),
  //           child: Row(
  //             children: [
  //               const Icon(Icons.currency_rupee, color: Color(0xFF42D7D7), size: 20),
  //               const SizedBox(width: 10),
  //               Text(
  //                 '${fixedBudget.toStringAsFixed(0)}',
  //                 style: const TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: FontWeight.bold,
  //                   color: Color(0xFF42D7D7),
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               Text(
  //                 '(Fixed Price)',
  //                 style: TextStyle(
  //                   fontSize: 12,
  //                   color: Colors.grey[600],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //
  //         const SizedBox(height: 16),
  //
  //         // Pincode
  //         _buildFormLabel('Enter Pincode'),
  //         TextField(
  //           controller: _pincodeController,
  //           keyboardType: TextInputType.number,
  //           maxLength: 6,
  //           decoration: InputDecoration(
  //             hintText: 'Enter your area pincode',
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide(color: Colors.grey.shade300),
  //             ),
  //             counterText: '',
  //             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 16),
  //
  //         // Address
  //         _buildFormLabel('Enter Address'),
  //         TextField(
  //           controller: _addressController,
  //           maxLines: 1,
  //           decoration: InputDecoration(
  //             hintText: 'Enter your complete address',
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide(color: Colors.grey.shade300),
  //             ),
  //             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 16),
  //
  //         // Full Name
  //         _buildFormLabel('Full Name'),
  //         TextField(
  //           controller: _fullNameController,
  //           decoration: InputDecoration(
  //             hintText: 'Enter your full name',
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide(color: Colors.grey.shade300),
  //             ),
  //             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 16),
  //
  //         // Mobile Number
  //         _buildFormLabel('Mobile Number'),
  //         TextField(
  //           controller: _mobileController,
  //           keyboardType: TextInputType.phone,
  //           maxLength: 10,
  //           decoration: InputDecoration(
  //             hintText: 'Enter your mobile number',
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide(color: Colors.grey.shade300),
  //             ),
  //             counterText: '',
  //             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 16),
  //
  //         // Issue Description
  //         _buildFormLabel('Describe the issue (Optional)'),
  //         TextField(
  //           controller: _issueController,
  //           maxLines: 3,
  //           decoration: InputDecoration(
  //             hintText: 'Please describe your issue in detail...',
  //             border: OutlineInputBorder(
  //               borderRadius: BorderRadius.circular(12),
  //               borderSide: BorderSide(color: Colors.grey.shade300),
  //             ),
  //             contentPadding: const EdgeInsets.symmetric(horizontal: 12),
  //           ),
  //         ),
  //
  //         const SizedBox(height: 20),
  //
  //         // Book Now Button
  //         SizedBox(
  //           width: double.infinity,
  //           height: 56,
  //           child: ElevatedButton(
  //             onPressed: _isSubmitting ? null : _submitRequest,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: const Color(0xFF42D7D7),
  //               foregroundColor: Colors.white,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //             ),
  //             child: _isSubmitting
  //                 ? const CircularProgressIndicator(color: Colors.white)
  //                 : const Row(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Icon(Icons.book_online, size: 24),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   'Book Now',
  //                   style: TextStyle(
  //                     fontSize: 18,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  // 🔥 ==================== BOOKING FORM ====================
  Widget _buildBookingForm() {
    // 🔥 Fixed Budget
    final double fixedBudget = 999.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF42D7D7), size: 20),
              SizedBox(width: 8),
              Text(
                'Book This Service',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1B4D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🔥 Service Type
          _buildFormLabel('Service Type'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cleaning_services,
                  color: Color(0xFF42D7D7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedServiceType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 🔥 Budget Display
          _buildFormLabel('Budget'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.currency_rupee,
                  color: Color(0xFF42D7D7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  '₹${fixedBudget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF42D7D7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Fixed Price)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // 🔥 ==================== CLIENT REQUIREMENT: PRICE NOTE ====================
          const SizedBox(height: 8),
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
                // 🔥 Line 1: Price Applies to Top Load Machine only
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Price Applies to Top Load Machine only',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 🔥 Line 2: For Front Load machines instruction
                Row(
                  children: [
                    Icon(Icons.build, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For Front Load machines: Please Book and Confirm Pricing with the Technician.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pincode
          _buildFormLabel('Enter Pincode'),
          TextField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Enter your area pincode',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Address
          _buildFormLabel('Enter Address'),
          TextField(
            controller: _addressController,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'Enter your complete address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Full Name
          _buildFormLabel('Full Name'),
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Mobile Number
          _buildFormLabel('Mobile Number'),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: InputDecoration(
              hintText: 'Enter your mobile number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Issue Description
          _buildFormLabel('Describe the issue (Optional)'),
          TextField(
            controller: _issueController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Please describe your issue in detail...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

          const SizedBox(height: 20),

          // Total Amount Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF42D7D7).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF42D7D7).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
                Text(
                  '₹${fixedBudget.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF42D7D7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Book Now Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42D7D7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.book_online, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Book Now',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0C1B4D),
        ),
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _makePhoneCall();
                  },
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call Customer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF42D7D7),
                    side: const BorderSide(color: Color(0xFF42D7D7)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _openChat();
                  },
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42D7D7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accept the request to connect with the customer. You can call or chat to confirm and provide the service.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildTimer(String time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0C1B4D)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day} ${_getMonth(date.month)} ${date.year}, $hour:$minute $ampm';
    }
    if (timestamp is DateTime) {
      final date = timestamp;
      final hour = date.hour > 12 ? date.hour - 12 : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final ampm = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day} ${_getMonth(date.month)} ${date.year}, $hour:$minute $ampm';
    }
    return 'N/A';
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  // ==================== ACTIONS ====================

  void _makePhoneCall() {
    final phone = _requestData?['userPhone'] ?? '';
    if (phone.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling $phone...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openChat() {
    final userId = _requestData?['userId'] ?? '';
    final userName = _requestData?['userName'] ?? 'Customer';

    if (userId.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening chat...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
