// lib/presentation/Merchant/MerchantDetailScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:thumstechs/Services/authServices.dart';
import 'package:thumstechs/presentation/authScreen/LoginScreen.dart';
import 'package:thumstechs/model/LocationModel.dart';

import '../../Map/screens/location_picker_screen.dart';
import 'StepTwoScreen.dart'; // ✅ Import

class MerchantDetailScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const MerchantDetailScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<MerchantDetailScreen> createState() => _MerchantDetailScreenState();
}

class _MerchantDetailScreenState extends State<MerchantDetailScreen> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _googleMapsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();



  // ✅ Location variables
  LocationModel? _storeLocation;
  bool _hasLocation = false;

  List<String> _selectedCategories = [];
  List<File> _storePhotos = [];
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  final List<String> _availableCategories = [
    'AC Parts',
    'Plumbing Parts',
    'Electrical Parts',
    'Carpenter Tools',
    'Cleaning Equipment',
    'Washing Machine Parts',
    'Refrigerator Parts',
    'Water purifier',
    'TV Parts',
    'Hardware Tools',
    'Home Appliance Parts',
    'Water Purifier Parts',
    'CCTV Parts',
    'Geyser Parts',
    'Chimney Parts',
    'Furniture Hardware',
    'Automotive Parts',
  ];

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _googleMapsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // ✅ DEBUG: Check userId when screen loads
    print('🔑🔑🔑 MerchantDetailScreen INIT STATE 🔑🔑🔑');
    print('📌 userId: "${widget.userId}"');
    print('📌 userId length: ${widget.userId.length}');
    print('📌 userEmail: "${widget.userEmail}"');

    if (widget.userId.isEmpty) {
      print('❌❌❌ CRITICAL: userId is EMPTY in MerchantDetailScreen! ❌❌❌');
    } else {
      print('✅ userId is VALID: ${widget.userId}');
    }
  }


  // ✅ Open Location Picker
  Future<void> _openLocationPicker() async {
    // ✅ Debug before opening
    print('📍 Opening LocationPicker');
    print('🔑 Current userId: "${widget.userId}"');

    if (widget.userId.isEmpty) {
      print('❌ ERROR: Cannot open location picker - userId is empty!');
      _showSnackbar('User not logged in. Please restart the app.', Colors.red);
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          userId: widget.userId,
          purpose: 'store_location',
          initialLocation: _storeLocation,
        ),
      ),
    );

    if (result != null && result is LocationModel) {
      setState(() {
        _storeLocation = result;
        _hasLocation = true;
        _googleMapsController.text = result.address ?? 'Location selected';
      });

      _showSnackbar('✅ Store location selected!', Colors.green);
    }
  }

  Future<void> _pickStorePhotos() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (images.isNotEmpty) {
        setState(() {
          _storePhotos.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _storePhotos.removeAt(index);
    });
  }

  Future<List<String>> _uploadStorePhotos(String userId) async {
    List<String> photoUrls = [];
    for (int i = 0; i < _storePhotos.length; i++) {
      try {
        final file = _storePhotos[i];
        final ref = FirebaseStorage.instance
            .ref()
            .child('merchants/$userId/store_photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        photoUrls.add(url);
      } catch (e) {
        print('Error uploading photo: $e');
      }
    }
    return photoUrls;
  }

  Future<void> _saveMerchantDetails() async {
    // Validation
    if (_storeNameController.text.isEmpty) {
      _showSnackbar('Please enter store name', Colors.red);
      return;
    }
    if (_ownerNameController.text.isEmpty) {
      _showSnackbar('Please enter owner name', Colors.red);
      return;
    }
    if (_contactController.text.isEmpty) {
      _showSnackbar('Please enter contact number', Colors.red);
      return;
    }
    if (_selectedCategories.isEmpty) {
      _showSnackbar('Please select at least one category', Colors.red);
      return;
    }
    // ✅ Validate location
    if (!_hasLocation || _storeLocation == null) {
      _showSnackbar('Please select your store location on the map', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload photos
      List<String> photoUrls = await _uploadStorePhotos(widget.userId);

      // ✅ Save merchant data with location
      final merchantData = {
        'storeName': _storeNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'whatsappNumber': _whatsappController.text.trim(),
        'googleMapsLink': _googleMapsController.text.trim(),
        'categories': _selectedCategories,
        'shortDescription': _descriptionController.text.trim(),
        'storePhotoUrls': photoUrls,
        // ✅ Location data
        'location': {
          'latitude': _storeLocation!.latitude,
          'longitude': _storeLocation!.longitude,
          'address': _storeLocation!.address,
          'placeName': _storeLocation!.placeName,
        },
        'geoPoint': GeoPoint(_storeLocation!.latitude, _storeLocation!.longitude),
        'status': 'pending',
        'isVerified': false,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .set(merchantData);

      // Update user with merchant flag and location
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'isMerchant': true,
        'role': 'merchant',
        'hasCompletedMerchantProfile': true,
        'hasLocation': true,
        'geoPoint': GeoPoint(_storeLocation!.latitude, _storeLocation!.longitude),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackbar('✅ Merchant profile created successfully!', Colors.green);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StepTwoScreen(
              userId: widget.userId,
              userEmail: widget.userEmail,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackbar('Error: $e', Colors.red);
      print('❌ Error saving merchant: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> logout() async {
    final service = AuthService();
    await service.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Merchant Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Name
            _buildTextField(
              controller: _storeNameController,
              label: 'Store Name *',
              hint: 'Enter your store name',
              icon: Icons.storefront,
            ),
            const SizedBox(height: 16),

            // Owner Name
            _buildTextField(
              controller: _ownerNameController,
              label: 'Owner Name *',
              hint: 'Enter owner name',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),

            // Contact Number
            _buildTextField(
              controller: _contactController,
              label: 'Contact Number *',
              hint: 'Enter contact number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // WhatsApp Number
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number (Optional)',
              hint: 'Enter WhatsApp number',
              icon: Icons.chat,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // ✅ GOOGLE MAPS LOCATION CARD (NEW)
            _buildLocationCard(),
            const SizedBox(height: 16),

            // Categories
            const Text(
              'Select Categories *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1B4D),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableCategories.map((category) {
                  bool isSelected = _selectedCategories.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF42D7D7).withOpacity(0.2),
                    backgroundColor: Colors.grey.shade50,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? const Color(0xFF42D7D7)
                          : Colors.black87,
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: const Color(0xFF42D7D7),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF42D7D7)
                          : Colors.grey.shade300,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_selectedCategories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Selected: ${_selectedCategories.length} categories',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Short Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Short Description (Optional)',
              hint: 'Describe your store and services',
              icon: Icons.description,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Store Photos
            const Text(
              'Store Photos (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1B4D),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickStorePhotos,
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _storePhotos.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap to add store photos',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _storePhotos.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_storePhotos[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
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
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveMerchantDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42D7D7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Complete Registration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ Location Card Widget
  Widget _buildLocationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Store Location *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1B4D),
              ),
            ),
            const SizedBox(width: 8),
            if (_hasLocation)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '✅ Selected',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasLocation ? Colors.green.shade300 : Colors.grey.shade300,
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
                        : const Color(0xFF42D7D7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _hasLocation ? Icons.location_on : Icons.map,
                    color: _hasLocation ? Colors.green.shade700 : const Color(0xFF42D7D7),
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
                            ? _storeLocation?.placeName ?? ''
                            : 'Select Your Store Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _hasLocation ? FontWeight.w600 : FontWeight.w500,
                          color: _hasLocation ? Colors.black87 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasLocation
                            ? _storeLocation?.address ?? 'Location selected'
                            : 'Tap to open map and select your store location',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasLocation ? Colors.grey.shade700 : Colors.grey.shade500,
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
                              'Lat: ${_storeLocation!.latitude.toStringAsFixed(6)}, '
                                  'Lng: ${_storeLocation!.longitude.toStringAsFixed(6)}',
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
                        : const Color(0xFF42D7D7).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _hasLocation ? Icons.check : Icons.arrow_forward_ios,
                    color: _hasLocation ? Colors.green.shade700 : const Color(0xFF42D7D7),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_hasLocation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '📍 Your store location will be shown to customers',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C1B4D),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF42D7D7)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF42D7D7)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }
}