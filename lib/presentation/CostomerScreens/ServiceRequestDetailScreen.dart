// screens/ServiceRequestDetailScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thumstechs/presentation/CostomerScreens/BookingScreen.dart';
import 'package:thumstechs/presentation/CostomerScreens/ServiceBookingScreen.dart';
import 'package:video_player/video_player.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../model/ServiceRequestModel.dart';
import '../../model/LocationModel.dart';
import '../../Map/screens/location_picker_screen.dart'; // ✅ Location Picker

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
  late VideoPlayerController? _videoController;
  bool _isLoading = true;
  Map<String, dynamic>? _requestData;
  bool _isFromBanner = false;
  bool _isVideoInitialized = false;
  bool _isVideo = true;

  // Form Controllers
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();

  bool _isSubmitting = false;
  String _selectedServiceType = 'Washing Machine Cleaning';
  double _fixedBudget = 899.0;

  // ✅ LOCATION VARIABLES
  LocationModel? _selectedLocation;
  bool _hasLocation = false;

  final FirebaseFirestoreStorageCustomerOrder _firestoreService =
  FirebaseFirestoreStorageCustomerOrder();

  @override
  void initState() {
    super.initState();

    if (widget.requestData != null) {
      _requestData = widget.requestData;
      _isFromBanner = widget.requestData?['isFromBanner'] ?? false;
      _selectedServiceType =
          _requestData?['serviceName'] ?? 'Washing Machine Cleaning';
      _fixedBudget = (_requestData?['budget'] ?? 899).toDouble();
      _isVideo = _requestData?['isVideo'] ?? true;
      _isLoading = false;
    }

    if (_isVideo) {
      _videoController = VideoPlayerController.asset(
        'assets/videos/projectVideo.MP4',
      )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController?.play();
          _videoController?.setLooping(true);
        }
      }).catchError((error) {
        print('❌ Video initialization error: $error');
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
          });
        }
      });
    } else {
      _videoController = null;
      _isVideoInitialized = false;
    }

    _loadUserData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
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

  // ✅ OPEN LOCATION PICKER
  Future<void> _openLocationPicker() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackbar('Please login first', Colors.red);
      return;
    }

    print('📍 Opening LocationPicker');
    print('🔑 userId: ${user.uid}');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          userId: user.uid,
          purpose: 'service_location',
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null && result is LocationModel) {
      setState(() {
        _selectedLocation = result;
        _hasLocation = true;

        // ✅ Auto-fill address if empty
        // if (_addressController.text.isEmpty) {
        //   _addressController.text = result.address ?? '';
        // }
      });

      _showSnackbar('✅ Location selected successfully!', Colors.green);
    }
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackbar('Please login first', Colors.red);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String profileImageUrl = userDoc.data()?['profileImageUrl'] ?? '';

    // ✅ VALIDATIONS
    if (_pincodeController.text.isEmpty) {
      _showSnackbar('Please enter your pincode', Colors.red);
      return;
    }
    if (_pincodeController.text.length < 4) {
      _showSnackbar('Please enter a valid pincode (min 4 digits)', Colors.red);
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
    if (_mobileController.text.length < 10) {
      _showSnackbar('Please enter a valid 10-digit mobile number', Colors.red);
      return;
    }

    // ✅ LOCATION VALIDATION
    if (!_hasLocation || _selectedLocation == null) {
      _showSnackbar('Please select your location on map', Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final Timestamp createdAtTimestamp = Timestamp.fromDate(DateTime.now());
      bool isWaterPurifier =
      _selectedServiceType.toLowerCase().contains('water purifier');
      String visitingCharges = isWaterPurifier ? 'visitingCharges' : '';

      // ✅ DEBUG
      print('═══════════════════════════════════════════');
      print('🔵 ServiceRequestDetailScreen - Submit');
      print('📍 _selectedLocation: ${_selectedLocation?.latitude}, ${_selectedLocation?.longitude}');
      print('📍 Address: ${_selectedLocation?.address}');
      print('═══════════════════════════════════════════');

      // ✅ Create request WITH location
      final request = ServiceRequestModel(
        userId: user.uid,
        visitingCharges: visitingCharges,
        videoId: '',
        serviceName: _selectedServiceType,
        serviceType: _selectedServiceType,
        userName: _fullNameController.text,
        userPhone: _mobileController.text,
        userEmail: user.email ?? '',
        location: _addressController.text,
        pincode: _pincodeController.text,
        budget: _fixedBudget,
        issue: _issueController.text,
        status: 'pending',
        createdAt: createdAtTimestamp,
        additionalNote: '',
        imageUrls: [],
        updatedAt: createdAtTimestamp,
        profileImageUrl: profileImageUrl,
        locationModel: _selectedLocation, // ✅ LOCATION PASS
      );

      // ✅ Save with matching (location included)
      final requestId = await _firestoreService.saveServiceRequestWithMatching(
        request: request,
        locationModel: _selectedLocation, // ✅ LOCATION PASS
      );

      print('✅ Service request saved: $requestId');
      print('📍 Location saved: ${_selectedLocation?.latitude}');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackbar(
          '✅ Service request submitted! ID: #${requestId.substring(0, 8).toUpperCase()}',
          Colors.green,
        );

        _pincodeController.clear();
        _addressController.clear();
        _issueController.clear();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceBookingScreen(initialTab: 0),
              ),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showSnackbar('Error: $e', Colors.red);
      print('❌ Error: $e');
    }
  }

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
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              _showShareOptions();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoSection(),
            const SizedBox(height: 2),
            if (_isVideo) _buildInBetweenBanner(),
            const SizedBox(height: 2),
            _buildBookingForm(),
            const SizedBox(height: 30),
          ],
        ),
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
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (_isVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isVideoInitialized && _videoController != null
                  ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController!),
                    Positioned(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoController!.setVolume(
                                _videoController!.value.volume == 0
                                    ? 1
                                    : 0);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _videoController!.value.volume == 0
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : Container(
                height: 200,
                color: Colors.grey.shade100,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF42D7D7),
                  ),
                ),
              ),
            ),
          if (!_isVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/AppLogoo/waterui.PNG',
                width: double.infinity,
                height: 210,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Image not found',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          if (_isVideo && _isVideoInitialized && _videoController != null)
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _videoController!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: const Color(0xFF42D7D7),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _videoController!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF42D7D7),
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _formatDuration(_videoController!.value.position),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ ${_formatDuration(_videoController!.value.duration)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                IconButton(
                  icon: Icon(Icons.fullscreen,
                      color: Colors.grey[600], size: 20),
                  onPressed: () {
                    _enterFullscreen();
                  },
                ),
              ],
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _enterFullscreen() {
    _showSnackbar('Fullscreen mode coming soon!', Colors.blue);
  }

  // ==================== IN-BETWEEN BANNER ====================
  Widget _buildInBetweenBanner() {
    return GestureDetector(
      onTap: () {
        _showSnackbar('Special offer details coming soon!', Colors.blue);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: double.infinity,
        height: 187,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/AppLogoo/machinecleaning1.png',
            width: double.infinity,
            height: 150,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: 150,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Banner not found',
                          style: TextStyle(color: Colors.grey)),
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

  // ==================== PRICE NOTE ====================
  Widget _buildPriceNote() {
    bool isWaterPurifier =
    _selectedServiceType.toLowerCase().contains('water purifier');
    bool isWashingMachine =
    _selectedServiceType.toLowerCase().contains('washing machine');

    if (isWaterPurifier) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellow.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '₹199 applies if No work is done.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    'No visiting charges if you get the service.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isWashingMachine) {
      return Container(
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
                Icon(Icons.info_outline,
                    size: 16, color: Colors.amber.shade700),
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
      );
    }

    return const SizedBox.shrink();
  }

  // ==================== BOOKING FORM ====================
  Widget _buildBookingForm() {
    bool isWaterPurifier =
    _selectedServiceType.toLowerCase().contains('water purifier');
    bool isWashingMachine =
    _selectedServiceType.toLowerCase().contains('washing machine');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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

          // Service Type
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
                const Icon(Icons.cleaning_services,
                    color: Color(0xFF42D7D7), size: 20),
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

          // Budget
          _buildFormLabel(isWaterPurifier ? 'Visiting Charges' : 'Budget'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isWaterPurifier
                  ? Colors.orange.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isWaterPurifier
                    ? Colors.orange.shade200
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                Text(
                  isWaterPurifier
                      ? '₹199 (Visiting Charges)'
                      : '₹${_fixedBudget.toStringAsFixed(0)} (Fixed Price)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isWaterPurifier
                        ? Colors.deepOrange
                        : const Color(0xFF42D7D9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _buildPriceNote(),
          const SizedBox(height: 16),

          // Pincode
          _buildFormLabel('Enter Pincode *'),
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
              prefixIcon: const Icon(Icons.local_post_office, size: 20),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ LOCATION PICKER CARD
          _buildFormLabel('Select Location *'),
          GestureDetector(
            onTap: _openLocationPicker,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasLocation
                      ? Colors.green.shade300
                      : Colors.grey.shade300,
                  width: _hasLocation ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _hasLocation
                          ? Colors.green.shade50
                          : const Color(0xFF42D7D7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _hasLocation ? Icons.location_on : Icons.map,
                      color: _hasLocation
                          ? Colors.green.shade700
                          : const Color(0xFF42D7D7),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasLocation
                              ? _selectedLocation?.placeName ??
                              'Location Selected'
                              : 'Tap to Select Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _hasLocation
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: _hasLocation
                                ? Colors.black87
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _hasLocation
                              ? _selectedLocation?.address ??
                              'Location selected'
                              : 'Open map to select your location',
                          style: TextStyle(
                            fontSize: 11,
                            color: _hasLocation
                                ? Colors.grey.shade700
                                : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_hasLocation) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                                'Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Arrow / Check
                  Icon(
                    _hasLocation ? Icons.check_circle : Icons.arrow_forward_ios,
                    color: _hasLocation
                        ? Colors.green.shade700
                        : const Color(0xFF42D7D7),
                    size: _hasLocation ? 24 : 16,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Address
          _buildFormLabel('Enter Address *'),
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
              prefixIcon: const Icon(Icons.location_on, size: 20),
            ),
          ),

          const SizedBox(height: 16),

          // Full Name
          _buildFormLabel('Full Name *'),
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              prefixIcon: const Icon(Icons.person, size: 20),
            ),
          ),

          const SizedBox(height: 16),

          // Mobile Number
          _buildFormLabel('Mobile Number *'),
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
              prefixIcon: const Icon(Icons.phone, size: 20),
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
              prefixIcon: const Icon(Icons.description, size: 20),
            ),
          ),

          const SizedBox(height: 20),

          // Total Amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF42D7D7).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF42D7D7).withOpacity(0.2),
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
                  isWaterPurifier
                      ? '₹199'
                      : '₹${_fixedBudget.toStringAsFixed(0)}',
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
                elevation: 2,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
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

          const SizedBox(height: 8),

          // Terms
          Row(
            children: [
              Icon(Icons.security, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'By booking, you agree to our Terms & Conditions',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            ],
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

  // ==================== SHARE OPTIONS ====================
  void _showShareOptions() {
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
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF42D7D7)),
              title: const Text('Share this service'),
              onTap: () {
                Navigator.pop(context);
                _showSnackbar('Share feature coming soon!', Colors.blue);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Color(0xFF42D7D7)),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(context);
                _showSnackbar('Link copied to clipboard!', Colors.green);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}