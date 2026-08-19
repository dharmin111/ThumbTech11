// lib/presentation/TechnicianScreen/TechnicianProfileScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../../Services/oneSignalNotificationService.dart';
import '../../TechnicianCustomertermAndCondition/TechnicianTermsScreen.dart';
import '../authScreen/LoginScreen.dart';
import '../privacy/PrivacyPolicyScreen.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? technicianName;
  String? technicianEmail;
  String? technicianPhone;
  String? technicianAddress;
  List<String> technicianPincodes = [];
  String? profileImageUrl;
  List<String> technicianCategories = [];
  bool isActive = true;
  bool isLoading = true;
  bool isUploading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  final List<String> availableCategories = [
    'AC Repair & Service',
    'Plumbing Service',
    'Electrical Work',
    'Carpenter',
    'Painting',
    'Cleaning',
    'Washing Machine Repair',
    'Refrigerator Repair',
    'Mobile Repair',
    'Computer Repair',
    'TV Repair',
    'Hardware Services',
    'Beauty Services',
    'Home Appliance Repair',
    'Water Purifier / RO Service',
    'CCTV Installation & Services',
    'Geyser Repair',
    'Chimney Repair',
    'Furniture Assembly',
    'Water Tank Cleaning',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTechnicianProfile();
    _ensureOneSignalId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  // ==================== SHOW PASSWORD DIALOG ====================

  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirm Your Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'For security, please enter your current password to delete your account.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your current password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // ==================== ACCOUNT DELETION ====================

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final email = user.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Email not found. Please contact support.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final password = await _showPasswordDialog();
    if (password == null || password.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting your account...'),
          ],
        ),
      ),
    );

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      print('✅ Re-authentication successful');

      final userId = user.uid;

      // Delete profile image
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(profileImageUrl!);
          await ref.delete();
          print('✅ Profile image deleted');
        } catch (e) {
          print('⚠️ Error deleting profile image: $e');
        }
      }

      // Delete service requests
      final requestsSnapshot = await _firestore
          .collection('service_requests')
          .where('technicianId', isEqualTo: userId)
          .get();

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) {
          for (String url in List<String>.from(data['imageUrls'])) {
            try {
              final ref = _storage.refFromURL(url);
              await ref.delete();
            } catch (e) {
              print('⚠️ Error deleting image: $e');
            }
          }
        }
        await doc.reference.delete();
      }
      print('✅ ${requestsSnapshot.docs.length} service requests deleted');

      // Delete conversations
      final chatsSnapshot = await _firestore
          .collection('conversations')
          .where('technicianId', isEqualTo: userId)
          .get();

      for (var doc in chatsSnapshot.docs) {
        final messages = await _firestore
            .collection('messages')
            .where('conversationId', isEqualTo: doc.id)
            .get();
        for (var msg in messages.docs) {
          await msg.reference.delete();
        }
        await doc.reference.delete();
      }
      print('✅ ${chatsSnapshot.docs.length} conversations deleted');

      // Delete pending requests
      final pendingSnapshot = await _firestore
          .collection('technician_pending_requests')
          .where('technicianId', isEqualTo: userId)
          .get();

      for (var doc in pendingSnapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ ${pendingSnapshot.docs.length} pending requests deleted');

      // Delete user document
      await _firestore.collection('users').doc(userId).delete();
      print('✅ User Firestore document deleted');

      // Delete auth account
      await user.delete();
      print('✅ Firebase Authentication account deleted');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code}');

      if (mounted) {
        Navigator.pop(context);
        String message;
        switch (e.code) {
          case 'wrong-password':
            message = '❌ Incorrect password. Please try again.';
            break;
          case 'user-disabled':
            message = '❌ This account has been disabled.';
            break;
          case 'user-not-found':
            message = '❌ User not found.';
            break;
          case 'requires-recent-login':
            message = '❌ Please log in again before deleting account.';
            break;
          default:
            message = '❌ Account deletion failed: ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Account deletion error: $e');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete your account?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'This will permanently delete:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Your profile and all data'),
                  const Text('• All your service requests'),
                  const Text('• All chat conversations'),
                  const Text('• Your authentication account'),
                  const Text('• All uploaded images'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // ==================== SUPPORT PAGE ====================

  Future<void> _openSupportPage() async {
    const supportUrl = 'https://thumbtech-521ae.web.app/support';
    final Uri uri = Uri.parse(supportUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $supportUrl';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open support page: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  Future<void> _privacyPolicy() async {
    const supportUrl = 'https://thumbtech-521ae.web.app/privacy-policy';
    final Uri uri = Uri.parse(supportUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $supportUrl';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open support page: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // ==================== EXISTING METHODS ====================

  Future<void> _ensureOneSignalId() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final oneSignalId = doc.data()?['oneSignalId'];

      if (oneSignalId == null || oneSignalId.toString().isEmpty) {
        print('📱 Auto-saving OneSignal ID for technician');
        await OneSignalNotificationService.saveOneSignalId(
          userId: user.uid,
          userRole: 'technician',
        );
      } else {
        print('✅ OneSignal ID already exists: $oneSignalId');
      }
    } catch (e) {
      print('Error ensuring OneSignal ID: $e');
    }
  }

  Future<void> _fetchTechnicianProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        technicianEmail = user.email;

        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;

          List<String> pincodesList = [];
          if (data['pincodes'] != null &&
              (data['pincodes'] as List).isNotEmpty) {
            pincodesList = List<String>.from(data['pincodes']);
          } else if (data['pincode'] != null &&
              data['pincode'].toString().isNotEmpty) {
            pincodesList = [data['pincode'].toString()];
          }

          setState(() {
            technicianName = data['name'];
            technicianPhone = data['phoneNumber'] ?? data['phone'];
            technicianAddress = data['address'];
            technicianPincodes = pincodesList;
            profileImageUrl = data['profileImageUrl'];
            isActive = data['isActive'] ?? true;
            technicianCategories = List<String>.from(data['categories'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error fetching profile: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'name': _nameController.text,
          'phoneNumber': _phoneController.text,
          'address': _addressController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          technicianName = _nameController.text;
          technicianPhone = _phoneController.text;
          technicianAddress = _addressController.text;
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addPincode() async {
    if (_pincodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a pincode')));
      return;
    }

    final newPincode = _pincodeController.text.trim();
    if (technicianPincodes.contains(newPincode)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pincode already added')));
      return;
    }

    if (newPincode.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 4-digit pincode')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update(
        {
          'pincodes': FieldValue.arrayUnion([newPincode]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      setState(() {
        technicianPincodes.add(newPincode);
        _pincodeController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pincode $newPincode added successfully')),
      );
    }
  }

  Future<void> _removePincode(String pincode) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update(
        {
          'pincodes': FieldValue.arrayRemove([pincode]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      setState(() {
        technicianPincodes.remove(pincode);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pincode $pincode removed')));
    }
  }

  Future<void> _updateCategories(List<String> newCategories) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          isLoading = true;
        });

        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'categories': newCategories,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          technicianCategories = newCategories;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categories updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error updating categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating categories: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfileImage() async {
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
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          isUploading = true;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading image...'),
              ],
            ),
          ),
        );

        final User? user = _auth.currentUser;
        if (user != null) {
          final storageRef = _storage.ref().child(
            'technicians/${user.uid}/profile/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

          await storageRef.putFile(File(image.path));
          final downloadUrl = await storageRef.getDownloadURL();

          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({
            'profileImageUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            profileImageUrl = downloadUrl;
            isUploading = false;
          });

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      setState(() {
        isUploading = false;
      });
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditCategoriesDialog() {
    List<String> tempSelectedCategories = List.from(technicianCategories);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit Service Categories'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  const Text(
                    'Select the services you provide (you can select multiple)',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableCategories.length,
                      itemBuilder: (context, index) {
                        String category = availableCategories[index];
                        bool isSelected = tempSelectedCategories.contains(
                          category,
                        );
                        return CheckboxListTile(
                          title: Text(category),
                          value: isSelected,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (selected) {
                            setStateDialog(() {
                              if (selected == true) {
                                tempSelectedCategories.add(category);
                              } else {
                                tempSelectedCategories.remove(category);
                              }
                            });
                          },
                          activeColor: const Color(0xFF2563EB),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (tempSelectedCategories.isNotEmpty) {
                    _updateCategories(tempSelectedCategories);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select at least one category'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) {
                Navigator.pop(dialogContext);
              }

              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) =>
                  const Center(child: CircularProgressIndicator()),
                );
              }

              try {
                await _auth.signOut();
                await Future.delayed(const Duration(milliseconds: 500));

                if (mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                        (route) => false,
                  );
                }
              } catch (e) {
                print('Logout error: $e');
                if (mounted) {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error logging out'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildProfileHeader(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileInfoCard(),
                const SizedBox(height: 16),
                _buildPincodesCard(),
                const SizedBox(height: 16),
                _buildCategoriesCard(),
                const SizedBox(height: 16),
                _buildSettingsCard(),
                const SizedBox(height: 16),
                _buildLegalCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // ✅ Terms & Conditions
          _buildProfileMenuItem(
            icon: Icons.description,
            title: 'Terms & Conditions',
            subtitle: 'Read our technician terms and conditions',
            onTap: _showTermsAndConditions,
          ),
          const Divider(height: 1),

          // ✅ Privacy Policy
          // _buildProfileMenuItem(
          //   icon: Icons.privacy_tip,
          //   title: 'Privacy Policy',
          //   subtitle: 'Learn how we protect your data',
          //   onTap: _showPrivacyPolicy,
          // ),
          const Divider(height: 1),

          // ✅ Get Support - Opens Support Page
          _buildProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Get Support',
            subtitle: 'Visit our support page',
            onTap: _openSupportPage,
          ),
          const Divider(height: 1),

          // ✅ Delete Account
          _buildProfileMenuItem(
            icon: Icons.delete_forever,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            onTap: _showDeleteAccountConfirmation,
            isRed: true,
          ),
          const Divider(height: 1),

          // ✅ Logout
          _buildProfileMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out from your account',
            onTap: _showLogoutConfirmation,
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TechnicianTermsScreen()),
    );
  }

  // void _showPrivacyPolicy() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
  //   );
  // }

  // ==================== REST OF THE EXISTING CODE ====================

  Widget _buildPincodesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Service Areas (Pincodes)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (technicianPincodes.isEmpty)
                  const Text(
                    'No pincodes added. Add your service areas above.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: technicianPincodes.map((pincode) {
                      return Chip(
                        label: Text(pincode),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removePincode(pincode),
                        backgroundColor: const Color(
                          0xFF2563EB,
                        ).withOpacity(0.1),
                        labelStyle: const TextStyle(color: Color(0xFF2563EB)),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                      );
                    }).toList(),
                  ),
                if (technicianPincodes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${technicianPincodes.length} service area(s)',
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

  Widget _buildProfileHeader() {
    return Container(
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
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                profileImageUrl != null && profileImageUrl!.isNotEmpty
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: profileImageUrl == null || profileImageUrl!.isEmpty
                    ? const Icon(Icons.person, size: 55, color: Colors.grey)
                    : null,
              ),
              if (isUploading)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                GestureDetector(
                  onTap: _updateProfileImage,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            technicianName ?? 'Technician Name',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildProfileMenuItem(
            icon: Icons.person_outline,
            title: 'Personal Information',
            onTap: _showEditProfileDialog,
          ),
          const Divider(height: 1),
          _buildProfileMenuItem(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: technicianEmail,
            onTap: null,
          ),
          const Divider(height: 1),
          _buildProfileMenuItem(
            icon: Icons.phone_outlined,
            title: 'Phone Number',
            subtitle: technicianPhone,
            onTap: null,
          ),
          const Divider(height: 1),
          _buildProfileMenuItem(
            icon: Icons.location_on_outlined,
            title: 'Address',
            subtitle: technicianAddress ?? 'Not set',
            onTap: _showServiceArea,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Service Categories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (technicianCategories.isEmpty)
                  const Text(
                    'No categories selected',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: technicianCategories.map((category) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF2563EB,
                            ).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showEditCategoriesDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Categories'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildProfileMenuItem(
            icon: Icons.notifications_active,
            title: 'Push Notifications',
            subtitle: 'Always enabled for service requests',
            onTap: null,
          ),
          const Divider(height: 1),




          _buildProfileMenuItem(
            icon: Icons.security,
            title: 'Privacy & Security',
            onTap: () {
              _privacyPolicy();
            },
          ),



          const Divider(height: 1),
          _buildProfileMenuItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: _openSupportPage,
          ),
          const Divider(height: 1),
          _buildProfileMenuItem(
            icon: Icons.info_outline,
            title: 'About App',
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isRed = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isRed ? Colors.red : const Color(0xFF2563EB),
      ),
      title: Text(title, style: isRed ? const TextStyle(color: Colors.red) : null),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing:
      trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  void _showEditProfileDialog() {
    _nameController.text = technicianName ?? '';
    _phoneController.text = technicianPhone ?? '';
    _addressController.text = technicianAddress ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showServiceArea() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Areas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${technicianAddress ?? "Not set"}'),
            const SizedBox(height: 8),
            Text(
              'Pincodes: ${technicianPincodes.isEmpty ? "Not set" : technicianPincodes.join(", ")}',
            ),
          ],
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About App'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Thumb Tech - Service Provider App'),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text('© 2024 All rights reserved'),
          ],
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
}