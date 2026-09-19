// lib/presentation/Userform/UserInfoScreen.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Services/oneSignalNotificationService.dart';
import '../presentation/CustomerOnboardingScreens/CustReadOne.dart';
import '../presentation/TechnicianOnboardingScreens/TechReadOne.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedRole;
  bool _isUploading = false;

  // 🔥 PINCODES LIST - Manual pincodes
  List<String> _manualPincodesList = [];
  final TextEditingController _pincodeController = TextEditingController();

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  // ==================== DEFAULT PINCODES ====================

  List<String> getDefaultPincodes() {
    return [
      '390025',
      '390019',
      '390018',
      '390020',
      '390002',
      '390005',
      '390021',
      '390007',
      '390015',
      '391410',
      '390012',
      '390011',
      '390014',
      '390010',
    ];
  }

  // ==================== MERGE PINCODES ====================

  List<String> _getMergedPincodes() {
    List<String> defaultPincodes = getDefaultPincodes();
    List<String> allPincodes = [..._manualPincodesList, ...defaultPincodes];
    List<String> uniquePincodes = allPincodes.toSet().toList();
    uniquePincodes.sort();
    return uniquePincodes;
  }

  // ==================== MANUAL PINCODE METHODS ====================

  void _addPincode() {
    final pincode = _pincodeController.text.trim();

    // Validation
    if (pincode.isEmpty) {
      _showSnackbar('Please enter a pincode', Colors.orange);
      return;
    }
    if (pincode.length < 4) {
      _showSnackbar('Pincode must be at least 4 digits', Colors.orange);
      return;
    }
    if (pincode.length > 6) {
      _showSnackbar('Pincode must be at most 6 digits', Colors.orange);
      return;
    }

    // Check if already in manual list
    if (_manualPincodesList.contains(pincode)) {
      _showSnackbar('Pincode already added manually', Colors.orange);
      return;
    }

    // Check if already in default list
    if (getDefaultPincodes().contains(pincode)) {
      _showSnackbar('Pincode already exists in default list', Colors.orange);
      return;
    }

    // ✅ Technician: Max 4 manual pincodes
    if (_selectedRole == 'technician' && _manualPincodesList.length >= 4) {
      _showSnackbar('Maximum 4 manual pincodes allowed for technicians', Colors.orange);
      return;
    }

    // ✅ Customer: Max 1 manual pincode
    if (_selectedRole == 'customer' && _manualPincodesList.length >= 1) {
      _showSnackbar('Only 1 pincode allowed for customers', Colors.orange);
      return;
    }

    // ✅ Add manual pincode
    setState(() {
      _manualPincodesList.add(pincode);
      _pincodeController.clear();
    });

    _showSnackbar('✅ Pincode added successfully', Colors.green);
  }

  void _removePincode(String pincode) {
    setState(() {
      _manualPincodesList.remove(pincode);
    });
    _showSnackbar('Pincode removed', Colors.blue);
  }

  // ✅ Check if minimum pincodes are met
  bool _hasMinimumPincodes() {
    if (_selectedRole == 'customer') {
      return _manualPincodesList.length >= 1;
    } else if (_selectedRole == 'technician') {
      // ✅ Technician needs exactly 4 manual pincodes
      return _manualPincodesList.length >= 4;
    }
    return false;
  }

  int _getRequiredPincodes() {
    return _selectedRole == 'technician' ? 4 : 1;
  }

  int _getCurrentCount() {
    return _manualPincodesList.length;
  }

  // ==================== IMAGE METHODS ====================

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        _showSnackbar('Profile picture selected successfully', Colors.green);
      }
    } catch (e) {
      _showError('Error selecting image: $e');
    }
  }

  void _showImageSourceDialog() {
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
              leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _removeProfileImage() {
    setState(() {
      _profileImage = null;
    });
    _showSnackbar('Profile picture removed', Colors.blue);
  }

  Future<String?> _uploadProfileImageToStorage(String userId) async {
    if (_profileImage == null) return null;

    try {
      String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(
        'users/$userId/profile/$fileName',
      );

      UploadTask uploadTask = ref.putFile(_profileImage!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // ==================== SAVE DATA ====================

  Future<void> _saveUserDataAndNavigate() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRole == null) {
      _showError('Please select your role (Customer or Technician)');
      return;
    }

    // ✅ Validate manual pincodes
    if (_selectedRole == 'technician' && _manualPincodesList.length < 4) {
      _showError('Please add ${4 - _manualPincodesList.length} more pincode(s) (Total 4 required)');
      return;
    }
    if (_selectedRole == 'customer' && _manualPincodesList.isEmpty) {
      _showError('Please add your pincode');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      String userId = user.uid;

      // Upload profile image if selected
      String? profileImageUrl = await _uploadProfileImageToStorage(userId);

      // ✅ Get merged pincodes (manual + default)
      List<String> mergedPincodes = _getMergedPincodes();

      // ✅ Prepare user data
      Map<String, dynamic> userData = {
        'id': userId,
        'name': _nameController.text.trim(),
        'email': user.email ?? '',
        'phoneNumber': _phoneController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'pincodes': mergedPincodes, // ✅ Merged (Manual + Default)
        'manualPincodes': _manualPincodesList, // ✅ Only manual
        'profileImageUrl': profileImageUrl,
        'role': _selectedRole,
        'isActive': true,
        'notificationsEnabled': true, // ✅ Add this
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print('📮 Manual Pincodes: $_manualPincodesList');
      print('📦 Merged Pincodes: $mergedPincodes');

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData,SetOptions(merge: true));

      print('✅ User data saved successfully!');
      await OneSignalNotificationService.saveCurrentUserOneSignalId();
      if (!mounted) return;

      // Navigate based on role
      if (_selectedRole == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CustReadOne()),
        );
      } else if (_selectedRole == 'technician') {
        final technicianData = {
          'id': userId,
          'name': _nameController.text.trim(),
          'email': user.email ?? '',
          'phoneNumber': _phoneController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'pincodes': mergedPincodes,
          'manualPincodes': _manualPincodesList,
        };


        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TechReadOne(
              userData: technicianData,
              profileImage: _profileImage,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error saving data: $e');
      print('❌ Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // ==================== HELPER METHODS ====================

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2563EB).withOpacity(0.1),
                        const Color(0xFF2563EB).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete your profile to continue',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                        // Profile Picture
                        _buildSectionTitle('Profile Picture', Icons.camera_alt),
                        const SizedBox(height: 16),
                        _buildProfileImageSection(),
                        const SizedBox(height: 24),

                        // Personal Information
                        _buildSectionTitle('Personal Information', Icons.person_outline),
                        const SizedBox(height: 16),

                        // Role Selection
                        _buildRoleSelectionField(),
                        const SizedBox(height: 16),

                        // Name
                        _buildTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: 'Enter your phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.length < 10) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Address
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter your full address',
                          icon: Icons.location_on_outlined,
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // 🔥 PINCODE SECTION
                        _buildPincodeSection(),

                        const SizedBox(height: 32),

                        // 🔥 Continue Button - Disabled until 4 pincodes added
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: _hasMinimumPincodes()
                                ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2563EB),
                                const Color(0xFF1D4ED8),
                              ],
                            )
                                : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade500,
                              ],
                            ),
                            boxShadow: _hasMinimumPincodes()
                                ? [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ]
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: _isUploading || !_hasMinimumPincodes()
                                ? null
                                : _saveUserDataAndNavigate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isUploading
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
                                : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (!_hasMinimumPincodes() &&
                                    _selectedRole == 'technician')
                                  Text(
                                    '${_getRequiredPincodes() - _getCurrentCount()} more pincodes required',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                if (!_hasMinimumPincodes() &&
                                    _selectedRole == 'customer')
                                  const Text(
                                    'Add your pincode',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
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
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Saving your information...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== PINCODE SECTION WIDGET ====================

  Widget _buildPincodeSection() {
    bool isTechnician = _selectedRole == 'technician';
    int requiredPincodes = isTechnician ? 4 : 1;
    int currentCount = _manualPincodesList.length;
    bool isComplete = currentCount >= requiredPincodes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.08),
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
                    color: const Color(0xFF2563EB).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTechnician ? 'Service Areas (Pincodes)' : 'Pincode',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        isTechnician
                            ? 'Add 4 pincodes for your service areas'
                            : 'Add your location pincode',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? Colors.green.withOpacity(0.15)
                        : const Color(0xFF2563EB).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$currentCount/$requiredPincodes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? Colors.green : const Color(0xFF2563EB),
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
                // Add Pincode Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Enter pincode',
                          border: OutlineInputBorder(),
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _addPincode(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addPincode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
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

                // Progress Indicator
                if (isTechnician)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Progress: $currentCount/$requiredPincodes',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: currentCount / requiredPincodes,
                              backgroundColor: Colors.grey.shade200,
                              color: isComplete
                                  ? Colors.green
                                  : const Color(0xFF2563EB),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                // Display Pincodes List (Manual Only)
                if (_manualPincodesList.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Pincodes:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _manualPincodesList.asMap().entries.map((entry) {
                          int index = entry.key;
                          String pincode = entry.value;
                          return Chip(
                            label: Text(pincode),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removePincode(pincode),
                            backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                            labelStyle: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w500,
                            ),
                            side: const BorderSide(color: Color(0xFF2563EB)),
                            avatar: CircleAvatar(
                              backgroundColor: const Color(0xFF2563EB),
                              radius: 12,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_manualPincodesList.length} pincode(s) added',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (isTechnician && currentCount < requiredPincodes)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '${requiredPincodes - currentCount} more required',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (isTechnician && isComplete)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '✅ All 4 pincodes added! You can proceed.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text(
                          'No pincodes added',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          isTechnician
                              ? 'Add 4 pincodes to continue'
                              : 'Add your pincode to continue',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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

  Widget _buildRoleSelectionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Select Role',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text(
                    'Customer',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('I want to book services'),
                  value: 'customer',
                  groupValue: _selectedRole,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                      _manualPincodesList.clear();
                      _pincodeController.clear();
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text(
                    'Technician',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('I want to provide services'),
                  value: 'technician',
                  groupValue: _selectedRole,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                      _manualPincodesList.clear();
                      _pincodeController.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _profileImage == null
          ? Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2563EB),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to add profile picture',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: FileImage(_profileImage!),
                  ),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _removeProfileImage,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            color: Colors.grey.withOpacity(0.05),
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
}