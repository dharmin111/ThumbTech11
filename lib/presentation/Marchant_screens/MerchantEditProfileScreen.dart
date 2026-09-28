// lib/presentation/Merchant/MerchantEditProfileScreen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepSevenScreen.dart';
import '../../Map/screens/location_picker_screen.dart';
import '../../model/LocationModel.dart';

class MerchantEditProfileScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const MerchantEditProfileScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<MerchantEditProfileScreen> createState() =>
      _MerchantEditProfileScreenState();
}

class _MerchantEditProfileScreenState
    extends State<MerchantEditProfileScreen> {
  // ========== CONTROLLERS ==========
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // ========== STATE ==========
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhotos = false;

  // ✅ Data
  List<String> _selectedCategories = [];
  List<File> _newPhotos = [];          // New photos to upload
  List<String> _existingPhotos = [];   // Already uploaded URLs
  LocationModel? _storeLocation;
  bool _hasLocation = false;

  final ImagePicker _picker = ImagePicker();

  // ✅ Categories list
  final List<String> _availableCategories = [
    'AC Parts',
    'Plumbing Parts',
    'Electrical Parts',
    'Carpentry Tools',
    'Painting Supplies',
    'Cleaning Equipment',
    'Washing Machine Parts',
    'Refrigerator Parts',
    'Mobile Repair Parts',
    'Computer Parts',
    'TV Parts',
    'Hardware Tools',
    'Beauty Supplies',
    'Home Appliance Parts',
    'Water Purifier Parts',
    'CCTV Parts',
    'Geyser Parts',
    'Chimney Parts',
    'Furniture Hardware',
    'Automotive Parts',
  ];

  // ========== INIT ==========
  @override
  void initState() {
    super.initState();
    _loadMerchantData();
  }
  Future<void> getUser()async{
    User? auth= await FirebaseAuth.instance.currentUser;
  }
  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ✅ Load existing merchant data
  Future<void> _loadMerchantData() async {
    setState(() => _isLoading = true);

    try {
      print('═══════════════════════════════════════════');
      print('📥 Loading merchant data...');

      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;

        // ✅ Fill controllers
        _storeNameController.text = data['storeName'] ?? '';
        _ownerNameController.text = data['ownerName'] ?? '';
        _contactController.text = data['contactNumber'] ?? '';
        _whatsappController.text = data['whatsappNumber'] ?? '';
        _descriptionController.text = data['shortDescription'] ?? '';

        // ✅ Load categories
        _selectedCategories =
        List<String>.from(data['categories'] ?? []);

        // ✅ Load photos
        _existingPhotos =
        List<String>.from(data['storePhotoUrls'] ?? []);

        // ✅ Load location
        final locationData = data['location'] ?? data['locationModel'];
        if (locationData != null) {
          _storeLocation = LocationModel(
            latitude: locationData['latitude']?.toDouble() ?? 0.0,
            longitude: locationData['longitude']?.toDouble() ?? 0.0,
            address: locationData['address'] ?? '',
            placeName: locationData['placeName'] ?? '',
          );
          _hasLocation = true;
        }

        print('✅ Data loaded successfully');
        print('   Store: ${_storeNameController.text}');
        print('   Categories: ${_selectedCategories.length}');
        print('   Photos: ${_existingPhotos.length}');
      }
    } catch (e) {
      print('❌ Error loading merchant: $e');
      _showSnackBar('Error loading data: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========== PICK PHOTOS ==========
  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMultipleImages();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF42D7D7).withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF42D7D7).withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF42D7D7)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF42D7D7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _newPhotos.add(File(image.path));
        });
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images =
      await _picker.pickMultiImage(imageQuality: 80);
      if (images.isNotEmpty) {
        setState(() {
          _newPhotos.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ✅ Remove existing photo
  Future<void> _removeExistingPhoto(int index) async {
    try {
      // ✅ Delete from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(_existingPhotos[index]);
      await ref.delete();
      print('✅ Deleted from Storage');
    } catch (e) {
      print('⚠️ Could not delete from Storage: $e');
    }

    setState(() {
      _existingPhotos.removeAt(index);
    });
  }

  // ✅ Remove new photo
  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
    });
  }

  // ========== LOCATION PICKER ==========
  Future<void> _openLocationPicker() async {
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
      });
      _showSnackBar('✅ Location updated!', Colors.green);
    }
  }

  // ========== SAVE CHANGES ==========
  Future<void> _saveChanges() async {
    // ========== VALIDATION ==========
    if (_storeNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter store name', Colors.red);
      return;
    }
    if (_ownerNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter owner name', Colors.red);
      return;
    }
    if (_contactController.text.trim().isEmpty) {
      _showSnackBar('Please enter contact number', Colors.red);
      return;
    }
    if (_selectedCategories.isEmpty) {
      _showSnackBar('Please select at least one category', Colors.red);
      return;
    }
    if (!_hasLocation || _storeLocation == null) {
      _showSnackBar('Please select your store location', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ========== 1. UPLOAD NEW PHOTOS ==========
      List<String> newPhotoUrls = [];
      if (_newPhotos.isNotEmpty) {
        setState(() => _isUploadingPhotos = true);

        for (int i = 0; i < _newPhotos.length; i++) {
          try {
            final file = _newPhotos[i];
            final ref = FirebaseStorage.instance.ref().child(
                'merchants/${widget.userId}/store_photos/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
            await ref.putFile(file);
            final url = await ref.getDownloadURL();
            newPhotoUrls.add(url);
            print('✅ Photo $i uploaded');
          } catch (e) {
            print('❌ Error uploading photo $i: $e');
          }
        }
      }

      // ✅ Combine existing + new photos
      final allPhotos = [..._existingPhotos, ...newPhotoUrls];

      // ========== 2. UPDATE MERCHANTS COLLECTION ==========
      final merchantData = {
        'storeName': _storeNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'whatsappNumber': _whatsappController.text.trim(),
        'shortDescription': _descriptionController.text.trim(),
        'categories': _selectedCategories,
        'storePhotoUrls': allPhotos,
        'location': {
          'latitude': _storeLocation!.latitude,
          'longitude': _storeLocation!.longitude,
          'address': _storeLocation!.address ?? '',
          'placeName': _storeLocation!.placeName ?? '',
        },
        'geoPoint': GeoPoint(
          _storeLocation!.latitude,
          _storeLocation!.longitude,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .update(merchantData);

      print('✅ merchants/{id} updated');

      // ========== 3. UPDATE USERS COLLECTION ==========
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'name': _ownerNameController.text.trim(),
        'phone': _contactController.text.trim(),
        'geoPoint': GeoPoint(
          _storeLocation!.latitude,
          _storeLocation!.longitude,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ users/{id} updated');

      // ========== 4. SUCCESS ==========
      HapticFeedback.mediumImpact();
      _showSnackBar('✅ Profile updated successfully!', Colors.green);

      // ✅ Navigate back after delay
      await Future.delayed(const Duration(seconds: 1));
      User? user=FirebaseAuth.instance.currentUser;

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder:
          (context) => StepSevenScreen(userId:user!.uid, userEmail: user.email??''),));
      }

    } catch (e) {
      print('❌ Error saving: $e');
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingPhotos = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Edit Merchant Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0C1B4D),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0C1B4D),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF42D7D7),
        ),
      )
          : _isSaving
          ? _buildSavingScreen()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Header Info
            _buildInfoBanner(),

            const SizedBox(height: 16),

            // ✅ Store Photos Section
            _buildPhotosSection(),

            const SizedBox(height: 20),

            // ✅ Store Name
            _buildTextField(
              controller: _storeNameController,
              label: 'Store Name',
              hint: 'Enter store name',
              icon: Icons.storefront,
              required: true,
            ),

            const SizedBox(height: 16),

            // ✅ Owner Name
            _buildTextField(
              controller: _ownerNameController,
              label: 'Owner Name',
              hint: 'Enter owner name',
              icon: Icons.person,
              required: true,
            ),

            const SizedBox(height: 16),

            // ✅ Contact Number
            _buildTextField(
              controller: _contactController,
              label: 'Contact Number',
              hint: 'Enter contact number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              required: true,
            ),

            const SizedBox(height: 16),

            // ✅ WhatsApp Number
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number',
              hint: 'Enter WhatsApp number',
              icon: Icons.chat,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),

            // ✅ Location Card
            _buildLocationCard(),

            const SizedBox(height: 16),

            // ✅ Categories
            _buildCategoriesSection(),

            const SizedBox(height: 16),

            // ✅ Description
            _buildTextField(
              controller: _descriptionController,
              label: 'About Store',
              hint: 'Describe your store and services',
              icon: Icons.description,
              maxLines: 4,
            ),

            const SizedBox(height: 30),

            // ✅ Save Button
            _buildSaveButton(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ Info Banner
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF42D7D7).withAlpha(30),
            const Color(0xFF42D7D7).withAlpha(10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF42D7D7).withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF42D7D7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Your Store Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Keep your info up to date to attract more customers',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Photos Section
  Widget _buildPhotosSection() {
    final totalPhotos = _existingPhotos.length + _newPhotos.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library,
                size: 20,
                color: Color(0xFF42D7D7),
              ),
              const SizedBox(width: 8),
              const Text(
                'Store Photos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1B4D),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF42D7D7).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalPhotos photos',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF42D7D7),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Photos Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: totalPhotos + 1, // +1 for add button
            itemBuilder: (context, index) {
              // ✅ Add Button
              if (index == totalPhotos) {
                return GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF42D7D7).withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF42D7D7),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 30,
                          color: Color(0xFF42D7D7),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF42D7D7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // ✅ Existing Photos
              if (index < _existingPhotos.length) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingPhotos[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeExistingPhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
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
                    // "Uploaded" badge
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SAVED',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // ✅ New Photos (Not yet uploaded)
              final newIndex = index - _existingPhotos.length;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _newPhotos[newIndex],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeNewPhoto(newIndex),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
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
                  // "New" badge
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
          Text(
            'Tap photos to remove. Add button se new photos add karein.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Location Card
  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: _openLocationPicker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasLocation
                ? Colors.green.shade300
                : const Color(0xFF42D7D7).withAlpha(80),
            width: _hasLocation ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasLocation
                    ? Colors.green.shade50
                    : const Color(0xFF42D7D7).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _hasLocation ? Icons.location_on : Icons.map,
                color: _hasLocation
                    ? Colors.green.shade700
                    : const Color(0xFF42D7D7),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Store Location',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0C1B4D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasLocation
                        ? _storeLocation?.address ?? 'Location selected'
                        : 'Tap to select your store location',
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
                    Text(
                      'Lat: ${_storeLocation!.latitude.toStringAsFixed(6)}, '
                          'Lng: ${_storeLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
    );
  }

  // ✅ Categories Section
  Widget _buildCategoriesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.category,
                size: 20,
                color: Color(0xFF42D7D7),
              ),
              const SizedBox(width: 8),
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1B4D),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF42D7D7).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedCategories.length} selected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF42D7D7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCategories.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSelected) {
                      _selectedCategories.remove(category);
                    } else {
                      _selectedCategories.add(category);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF42D7D7).withAlpha(25)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF42D7D7)
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Color(0xFF42D7D7),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF42D7D7)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ✅ Text Field Builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1B4D),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF42D7D7)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF42D7D7),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Save Button
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF42D7D7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: _isSaving
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Saving...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, size: 22),
            SizedBox(width: 8),
            Text(
              'SAVE CHANGES',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Saving Screen
  Widget _buildSavingScreen() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF42D7D7),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _isUploadingPhotos
                  ? 'Uploading photos...'
                  : 'Saving changes...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1B4D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait, do not close the app',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}