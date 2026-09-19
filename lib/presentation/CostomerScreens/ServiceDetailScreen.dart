// lib/presentation/CostomerScreens/ServiceDetailScreen.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'CustomerReviewScreen.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../model/LocationModel.dart';
import '../../Map/screens/location_picker_screen.dart'; // ✅ Location Picker import

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const lightBlue = Color(0xFF7EC8FF);
const yellow = Color(0xFFFFD428);
const background = Color(0xFFFFFFFF);

class ServiceDetailScreen extends StatefulWidget {
  final String serviceName;
  final String? editRequestId;

  const ServiceDetailScreen({
    super.key,
    required this.serviceName,
    this.editRequestId,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestoreStorageCustomerOrder _firebaseService =
  FirebaseFirestoreStorageCustomerOrder();

  // 🔥 Controllers for form fields
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String pincode = '';
  String address = '';
  String phoneNumber='';
  String issueDescription = '';
  List<XFile> uploadedImages = [];
  String budget = '800';
  String selectedServiceType = '';

  // ✅ LOCATION PICKER VARIABLES
  LocationModel? _selectedLocation;
  bool _hasLocation = false;

  bool _isLoading = false;
  bool _isEditMode = false;

  String getServiceDescription() {
    Map<String, String> descriptions = {
      'Washing Machine Repair':
      'Expert washing machine repair services including drum replacement, motor repair, water leakage fixes, and electronic board troubleshooting. We handle all major brands with warranty on parts.',
      'Microwave Repair':
      'Professional microwave repair for all issues including heating problems, sparking, turntable not rotating, and keypad malfunction. Same-day service available.',
      'Refrigerator Repair':
      'Complete refrigerator repair services including cooling issues, gas refilling, compressor replacement, and thermostat repair. 90-day service warranty.',
      'AC Repair & Service':
      'Comprehensive AC services including gas refilling, compressor repair, filter cleaning, and PCB repair. Annual maintenance contracts available.',
      'Geyser Repair':
      'Expert geyser repair and installation services for all types. We fix heating issues, leaks, thermostat problems, and safety valve replacements.',
      'Air Cooler Repair':
      'Professional air cooler services including pump repair, pad replacement, motor servicing, and complete cleaning. Summer-ready maintenance packages.',
      'TV Repair':
      'LCD, LED, and Smart TV repair specialists. We fix display issues, sound problems, motherboard repair, and power supply issues.',
      'Plumbing Service':
      '24/7 plumbing services for all emergency repairs. Fixing leaks, unclogging drains, installing fixtures, and complete bathroom renovation.',
      'Carpenter':
      'Skilled carpenters for all woodwork needs. Furniture repair, custom cabinets, door and window fitting, and wooden flooring installation.',
      'CCTV Installation & Services':
      'Professional CCTV installation for homes and businesses. We provide camera installation, DVR setup, mobile viewing configuration, and maintenance.',
      'Water Purifier / RO Service':
      'Thorough water tank cleaning and disinfection services. We use professional equipment and eco-friendly cleaning solutions.',
      'Electrical Work':
      'Licensed electricians for all electrical work including wiring, switchboard installation, fan and light fitting, and circuit breaker repair.',
      'Chimney Repair':
      'Kitchen chimney repair and maintenance services. We clean filters, repair motors, fix control panels, and provide installation services.',
      'Furniture Assembly':
      'Professional furniture assembly for all types. We assemble beds, sofas, tables, chairs, wardrobes, and office furniture quickly.',
      'Water Tank Cleaning':
      'Professional cleaning and disinfection of water tanks to ensure safe, clean water supply for your home or business.',
    };

    return descriptions[widget.serviceName] ??
        'We provide professional repair, installation, and maintenance services for ${widget.serviceName} at your doorstep. Our certified technicians ensure quality service with warranty.';
  }

  String getServiceType() {
    Map<String, String> serviceTypes = {
      'Washing Machine Repair': 'Washing Machine Repair',
      'Microwave Repair': 'Microwave Repair',
      'Refrigerator Repair': 'Refrigerator Repair',
      'AC Repair & Service': 'AC Repair & Service',
      'Geyser Repair': 'Geyser Repair',
      'Air Cooler Repair': 'Air Cooler Repair',
      'TV Repair': 'TV Repair',
      'Plumbing Service': 'Plumbing Service',
      'Carpenter': 'Carpenter',
      'CCTV Installation & Services': 'CCTV Installation & Services',
      'Water Tank Cleaning': 'Water Tank Cleaning',
      'Electrical Work': 'Electrical Work',
      'Chimney Repair': 'Chimney Repair',
      'Furniture Assembly': 'Furniture Assembly',
    };
    return serviceTypes[widget.serviceName] ?? widget.serviceName;
  }

  @override
  void initState() {
    super.initState();
    selectedServiceType = getServiceType();

    if (widget.editRequestId != null && widget.editRequestId!.isNotEmpty) {
      _isEditMode = true;
      _loadExistingData();
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) {
      phoneNumber = user!.phoneNumber!;
      _phoneController.text = phoneNumber;
    }

  }

  @override
  void dispose() {
    _pincodeController.dispose();
    _addressController.dispose();
    _issueController.dispose();
    _budgetController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    try {
      final request = await _firebaseService.getServiceRequestById(
          widget.editRequestId!);

      if (request != null && mounted) {
        setState(() {
          _pincodeController.text = request.pincode;
          _addressController.text = request.location;
          _issueController.text = request.issue;
          _budgetController.text = request.budget.toString();
          pincode = request.pincode;
          _phoneController.text=request.userPhone;
          phoneNumber = request.userPhone ?? '';
          address = request.location;
          issueDescription = request.issue;
          budget = request.budget.toString();
          selectedServiceType = request.serviceType;

          // ✅ Load location if exists
          if (request.locationModel != null) {
            _selectedLocation = request.locationModel;
            _hasLocation = true;
          }
        });
      }
    } catch (e) {
      print('❌ Error loading request data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ OPEN LOCATION PICKER
  Future<void> _openLocationPicker() async {
    // ✅ Get current user ID
    final userId = FirebaseFirestore.instance.collection('users').doc().id;

    print('📍 Opening LocationPicker');
    print('🔑 userId: $userId');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          userId: userId,
          purpose: 'service_location',
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null && result is LocationModel) {
      setState(() {
        _selectedLocation = result;
        _hasLocation = true;

      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Location selected successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Choose Option',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: primaryCyan),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: primaryCyan),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImagesFromGallery();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          uploadedImages.add(image);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error picking image from camera: $e');
    }
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);

      if (images.isNotEmpty) {
        setState(() {
          uploadedImages.addAll(images);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${images.length} image(s) selected successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error picking images from gallery: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      uploadedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Service' : widget.serviceName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditMode)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryCyan.withOpacity(0.1),
                    lightBlue.withOpacity(0.1),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditMode
                        ? 'Editing: ${widget.serviceName}'
                        : widget.serviceName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    getServiceDescription(),
                    style: TextStyle(
                      fontSize: 14,
                      color: darkBlue.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Service Type
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Service Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.build_circle_outlined,
                      size: 20,
                      color: primaryCyan,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedServiceType,
                        style: const TextStyle(
                          fontSize: 14,
                          color: darkBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ LOCATION PICKER CARD (NEW)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select Location *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _openLocationPicker,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasLocation
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                      width: _hasLocation ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasLocation
                              ? Colors.green.shade50
                              : primaryCyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _hasLocation
                              ? Icons.location_on
                              : Icons.map,
                          color: _hasLocation
                              ? Colors.green.shade700
                              : primaryCyan,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasLocation
                                  ? _selectedLocation?.placeName ??
                                  'Location Selected'
                                  : 'Select Your Location',
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
                            const SizedBox(height: 4),
                            Text(
                              _hasLocation
                                  ? _selectedLocation?.address ??
                                  'Location selected'
                                  : 'Tap to open map and select your location',
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasLocation
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_hasLocation) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_pin,
                                    size: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Arrow / Status
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _hasLocation
                              ? Colors.green.shade100
                              : primaryCyan.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _hasLocation
                              ? Icons.check
                              : Icons.arrow_forward_ios,
                          color: _hasLocation
                              ? Colors.green.shade700
                              : primaryCyan,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),


            // Enter Pincode
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Enter Pincode *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (value) {
                    setState(() {
                      pincode = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter your area pincode',
                    hintStyle:
                    TextStyle(fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    counterText: '',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ✅ Phone Number Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Phone Number *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onChanged: (value) {
                    setState(() {
                      phoneNumber = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter your 10-digit mobile number',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                    prefixIcon: Icon(Icons.phone, color: primaryCyan, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    counterText: '',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Enter Address
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Enter Address *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _addressController,
                  maxLines: 2,
                  onChanged: (value) {
                    setState(() {
                      address = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter your complete address',
                    hintStyle:
                    TextStyle(fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Describe the issue
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Describe The Issue *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: darkBlue.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _issueController,
                  maxLines: 3,
                  onChanged: (value) {
                    setState(() {
                      issueDescription = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Please describe your issue in detail...',
                    hintStyle:
                    TextStyle(fontSize: 14, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Upload Photos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Photos (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkBlue.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add photos to help technician understand the issue better',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: darkBlue.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _showImagePickerOptions,
                    icon: const Icon(Icons.add_photo_alternate,
                        color: primaryCyan),
                    tooltip: 'Add Photos',
                  ),
                ],
              ),
            ),

            if (uploadedImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Selected Images (${uploadedImages.length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: darkBlue.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: uploadedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: FileImage(
                                      File(uploadedImages[index].path),
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                  border: Border.all(
                                    color: primaryCyan,
                                    width: 1,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 5,
                                top: 5,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Budget
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Expected Budget (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkBlue.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.info,
                          color: primaryCyan, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          budget = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText:
                        'Share Your Approximate Budget, If Any',
                        hintStyle: TextStyle(
                            fontSize: 12, color: Colors.grey),
                        prefixText: '₹ ',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '   Leave Blank If You Are Unsure',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Technician Visit Charges Notice Card
            Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.orange.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A technician visit may include a visit/inspection charge.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            'Please confirm the charges with the technician before the visit.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Continue Button
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 20),
              child: ElevatedButton(
                onPressed: () {
                  // ✅ VALIDATION
                  if (!_hasLocation || _selectedLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select your location'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (pincode.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your pincode'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (phoneNumber.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your phone number'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (phoneNumber.length != 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid 10-digit phone number'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (address.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your address'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (issueDescription.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please describe the issue'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // ✅ DEBUG
                  print('═══════════════════════════════════════════');
                  print('🔵 ServiceDetailScreen - Continue Pressed');
                  print('📍 _selectedLocation: $_selectedLocation');
                  print('📍 Lat: ${_selectedLocation?.latitude}');
                  print('📍 Lng: ${_selectedLocation?.longitude}');
                  print('📍 Address: ${_selectedLocation?.address}');
                  print('📍 _hasLocation: $_hasLocation');
                  print('═══════════════════════════════════════════');

                  if (!_hasLocation || _selectedLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select your location'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // ✅ PASS LOCATION TO REVIEW SCREEN
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReviewScreen(
                        serviceName: widget.serviceName,
                        serviceType: selectedServiceType,
                        pincode: pincode,
                        address: address,
                        phoneNumber: phoneNumber,
                        issueDescription: issueDescription,
                        images: uploadedImages,
                        budget: budget.isEmpty ? '0' : budget,
                        editRequestId: widget.editRequestId,
                        locationModel: _selectedLocation, // ✅ Pass location
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isEditMode ? 'Update Service' : 'Continue',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}