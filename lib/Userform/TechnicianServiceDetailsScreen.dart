import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:thumstechs/presentation/DashBoard/TechnicianDashboard.dart';
import 'package:thumstechs/Services/FirebaseStorageService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../Services/FirebaseFirestoreService.dart';
import '../../Services/oneSignalNotificationService.dart';

class TechnicianServiceDetailsScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String address;
  final String pincode;
  final File? profileImage;
  final String userId;

  const TechnicianServiceDetailsScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    required this.pincode,
    required this.userId,
    this.profileImage,
  });

  @override
  State<TechnicianServiceDetailsScreen> createState() =>
      _TechnicianServiceDetailsScreenState();
}

class _TechnicianServiceDetailsScreenState
    extends State<TechnicianServiceDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Services
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();

  bool _isSubmitting = false;

  // Multiple pincodes list
  final List<String> _servicePincodes = [];

  // Categories with their subcategories
  final Map<String, List<String>> _categories = {
    'Appliance Repair & Service': [
      'AC Repair & Service',
      'Washing Machine Repair',
      'Water Purifier / RO Service',
      'Microwave Repair',
      'Chimney Repair',
      'Geyser Repair',
      'Refrigerator Repair',
      'TV Repair',
      'Air Cooler Repair',
    ],
    'Home Repair & Installation': [
      'Plumbing Service',
      'Electrical Work',
      'Carpenter',
      'CCTV Installation & Services',
      'Water Tank Cleaning',
      'Door Lock Repair',
      'Fan Installation',
      'Painting',
      'Tile Work',
    ],
  };

  // Track selected skills
  final Map<String, bool> _selectedSkills = {};

  // Images - Store as File for upload
  final List<File> _previousWorkImages = [];
  File? _idCardImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialize all skills as false
    for (var category in _categories.values) {
      for (var skill in category) {
        _selectedSkills[skill] = false;
      }
    }

    // Add initial pincode from widget
    if (widget.pincode.isNotEmpty) {
      _servicePincodes.add(widget.pincode);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  // ✅ Save OneSignal ID for technician
  Future<void> _saveTechnicianOneSignalId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      print('📱 Saving OneSignal ID for technician: ${user.uid}');

      // Wait for OneSignal ID to be available (up to 5 seconds)
      String? oneSignalId;
      for (int i = 0; i < 10; i++) {
        oneSignalId = OneSignal.User.pushSubscription.id;
        if (oneSignalId != null && oneSignalId.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (oneSignalId == null || oneSignalId.isEmpty) {
        print('❌ OneSignal ID not available yet');
        return;
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'oneSignalId': oneSignalId,
        'userRole': 'technician',
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Technician OneSignal ID saved: $oneSignalId');
    } catch (e) {
      print('❌ Error saving technician OneSignal ID: $e');
    }
  }

  // Show leave confirmation dialog
  Future<void> _showLeaveConfirmation() async {
    final shouldLeave =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Registration?'),
            content: const Text(
              'Are you sure you want to leave? Your progress will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldLeave) {
      Navigator.pop(context);
    }
  }

  // Add new pincode
  void _addPincode() {
    if (_pincodeController.text.trim().isEmpty) {
      _showError('Please enter a pincode');
      return;
    }

    final newPincode = _pincodeController.text.trim();
    if (_servicePincodes.contains(newPincode)) {
      _showError('Pincode already added');
      return;
    }

    if (newPincode.length < 4) {
      _showError('Please enter a valid 4-digit pincode');
      return;
    }

    setState(() {
      _servicePincodes.add(newPincode);
      _pincodeController.clear();
    });
  }

  // Remove pincode
  void _removePincode(String pincode) {
    setState(() {
      _servicePincodes.remove(pincode);
    });
  }

  Future<void> _pickImage(bool isPreviousWork, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          if (isPreviousWork) {
            _previousWorkImages.add(File(image.path));
          } else {
            _idCardImage = File(image.path);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isPreviousWork ? 'Work image' : 'ID card'} added successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  void _showImageSourceDialog(bool isPreviousWork) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF2563EB),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(isPreviousWork, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(isPreviousWork, ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index, bool isPreviousWork) {
    setState(() {
      if (isPreviousWork) {
        _previousWorkImages.removeAt(index);
      } else {
        _idCardImage = null;
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _submitForm() async {
    // Get selected skills
    List<String> selectedSkillsList = _selectedSkills.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedSkillsList.isEmpty) {
      _showError('Please select at least one service category');
      return;
    }

    // Validate multiple pincodes
    if (_servicePincodes.isEmpty) {
      _showError('Please add at least one service area pincode');
      return;
    }

    if (_idCardImage == null) {
      _showError('Please upload your ID card for verification');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Uploading your application...'),
          ],
        ),
      ),
    );

    try {
      // 1. Upload Profile Image (if exists)
      String? profileImageUrl;
      if (widget.profileImage != null) {
        profileImageUrl = await _storageService.uploadImage(
          imageFile: widget.profileImage!,
          userId: widget.userId,
          folderName: 'profile',
          fileName: 'profile.jpg',
        );
      }

      // 2. Upload ID Card Image
      String? idCardImageUrl = await _storageService.uploadIdCardImage(
        idCardFile: _idCardImage!,
        userId: widget.userId,
      );

      // 3. Upload Previous Work Images
      List<String> previousWorkUrls = await _storageService
          .uploadMultipleImages(
            imageFiles: _previousWorkImages,
            userId: widget.userId,
            folderName: 'work_images',
          );

      // 4. Save all data to Firestore with multiple pincodes
      Map<String, dynamic> result = await _firestoreService.saveTechnicianData(
        userId: widget.userId,
        name: widget.name,
        phone: widget.phone,
        address: widget.address,
        pincodes: _servicePincodes,
        description: _descriptionController.text,
        selectedCategories: selectedSkillsList,
        previousWorkImageUrls: previousWorkUrls,
        idCardImageUrl: idCardImageUrl,
        profileImageUrl: profileImageUrl,
      );

      // Close loading dialog
      Navigator.pop(context);

      if (result['success']) {
        // ✅ Save OneSignal ID for technician after successful registration
        await _saveTechnicianOneSignalId();

        // Show success dialog with service areas
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 60),
                SizedBox(height: 16),
                Text('Application Submitted Successfully!'),
              ],
            ),
            content: Text(
              'Thank you ${widget.name} for applying to become a technician!\n\n'
              'Your application for:\n'
              '${selectedSkillsList.take(3).join(", ")}${selectedSkillsList.length > 3 ? " + ${selectedSkillsList.length - 3} more" : ""}\n\n'
              'Service Areas: ${_servicePincodes.join(", ")}\n\n'
              'has been received. Our team will review your application and contact you soon at ${widget.phone}.\n\n'
              'Status: Pending Review',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Clear all navigation history and go to dashboard
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const TechnicianDashboard(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        );
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading dialog
      }
      _showError('Error submitting application: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Build pincode section UI
  Widget _buildPincodeSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Service Areas (Pincodes)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Add pincode input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Enter pincode (e.g., 110001)',
                          border: OutlineInputBorder(),
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addPincode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Display pincodes list
                if (_servicePincodes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No pincodes added. Add your service areas above.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Service Areas:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _servicePincodes.map((pincode) {
                          return Chip(
                            label: Text(pincode),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removePincode(pincode),
                            backgroundColor: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.1),
                            labelStyle: const TextStyle(
                              color: Color(0xFF2563EB),
                            ),
                            side: const BorderSide(color: Color(0xFF2563EB)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_servicePincodes.length} service area(s) selected',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _showLeaveConfirmation();
        return false; // We handle navigation manually
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'Technician Service Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _showLeaveConfirmation,
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header Banner with Technician Info Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.1),
                      const Color(0xFF2563EB).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Technician Registration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.person, 'Name', widget.name),
                          const Divider(),
                          _buildInfoRow(Icons.phone, 'Phone', widget.phone),
                          const Divider(),
                          _buildInfoRow(
                            Icons.location_on,
                            'Address',
                            widget.address,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Multiple Pincodes Section
                      _buildPincodeSection(),

                      const SizedBox(height: 24),

                      // Service Categories Section
                      _buildSectionTitle(
                        'Select Service Categories',
                        Icons.category_outlined,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Choose the services you can provide',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Categories
                      ..._categories.entries.map((entry) {
                        return _buildCategoryCard(
                          categoryName: entry.key,
                          skills: entry.value,
                          selectedSkills: _selectedSkills,
                          onSkillTapped: (skill) {
                            setState(() {
                              _selectedSkills[skill] =
                                  !(_selectedSkills[skill] ?? false);
                            });
                          },
                        );
                      }),

                      const SizedBox(height: 24),

                      // Previous Work Images Section
                      _buildSectionTitle(
                        'Previous Work Examples',
                        Icons.image_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildImageUploadSection(
                        title:
                            'Upload photos of your previous work (Max 10 images)',
                        images: _previousWorkImages,
                        onAddPressed: () => _showImageSourceDialog(true),
                        onRemovePressed: (index) => _removeImage(index, true),
                      ),
                      const SizedBox(height: 24),

                      // ID Card Image Section
                      _buildSectionTitle(
                        'Identity Proof',
                        Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildImageUploadSection(
                        title:
                            'Upload your ID card (Aadhar, PAN, Driving License, etc.)',
                        images: _idCardImage != null ? [_idCardImage!] : [],
                        isSingleImage: true,
                        onAddPressed: () => _showImageSourceDialog(false),
                        onRemovePressed: (index) => _removeImage(index, false),
                      ),
                      const SizedBox(height: 24),

                      // Work Description Section
                      _buildSectionTitle(
                        'About Your Work',
                        Icons.description_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Work Description',
                        hint:
                            'Describe your experience, expertise, tools you have, and approach to work...',
                        icon: Icons.edit_note,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please describe your work';
                          }
                          if (value.length < 10) {
                            return 'Please provide more details (minimum 10 characters)';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Submit Technician Application',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
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
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String categoryName,
    required List<String> skills,
    required Map<String, bool> selectedSkills,
    required Function(String) onSkillTapped,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    categoryName == 'Appliance Repair & Service'
                        ? Icons.electrical_services
                        : Icons.home_repair_service,
                    color: const Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Text(
                  '${skills.where((s) => selectedSkills[s] == true).length} selected',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: skills.map((skill) {
                bool isSelected = selectedSkills[skill] ?? false;
                return GestureDetector(
                  onTap: () => onSkillTapped(skill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 18,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          skill,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection({
    required String title,
    required List<File> images,
    required VoidCallback onAddPressed,
    required Function(int) onRemovePressed,
    bool isSingleImage = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          if (images.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No images uploaded',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: onAddPressed,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Upload Images'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ...images.asMap().entries.map((entry) {
                    int index = entry.key;
                    File image = entry.value;
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 12, bottom: 16),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(image),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => onRemovePressed(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
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
                  }),
                  if (!isSingleImage)
                    GestureDetector(
                      onTap: onAddPressed,
                      child: Container(
                        margin: const EdgeInsets.only(right: 12, bottom: 16),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 32,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add More',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
