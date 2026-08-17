// lib/presentation/CostomerScreens/ProfileScreen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../TechnicianCustomertermAndCondition/TermsAndConditionsScreen.dart';
import '../authScreen/LoginScreen.dart';
import '../../Services/oneSignalNotificationService.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const background = Color(0xFFFFFFFF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  // ==================== ACCOUNT DELETION ====================

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      final userId = user.uid;

      // 1. Delete profile image from Firebase Storage (if exists)
      if (_userData?['profileImageUrl'] != null && _userData!['profileImageUrl'].toString().isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(_userData!['profileImageUrl']);
          await ref.delete();
          print('✅ Profile image deleted');
        } catch (e) {
          print('⚠️ Error deleting profile image: $e');
        }
      }

      // 2. Delete all service requests created by this user
      final requestsSnapshot = await _firestore
          .collection('service_requests')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in requestsSnapshot.docs) {
        // Delete associated images from storage
        final data = doc.data();
        if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) {
          for (String url in List<String>.from(data['imageUrls'])) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(url);
              await ref.delete();
            } catch (e) {
              print('⚠️ Error deleting image: $e');
            }
          }
        }
        await doc.reference.delete();
      }
      print('✅ ${requestsSnapshot.docs.length} service requests deleted');

      // 3. Delete all chats/conversations
      final chatsSnapshot = await _firestore
          .collection('conversations')
          .where('customerId', isEqualTo: userId)
          .get();

      for (var doc in chatsSnapshot.docs) {
        // Delete messages in this conversation
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

      // 4. Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();
      print('✅ User document deleted');

      // 5. Delete the Authentication account
      await user.delete();
      print('✅ Authentication account deleted');

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Account deletion error: $e');
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
                      const SizedBox(width: 8),
                      const Text(
                        'This will permanently delete:',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  // ==================== EXISTING METHODS ====================

  void _editField(String field) {
    TextEditingController controller = TextEditingController(
      text: _userData?[field] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_getFieldName(field)}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter ${_getFieldName(field)}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                final user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('users').doc(user.uid).update({
                    field: newValue,
                  });
                  await _loadUserData();
                }
              }
              Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_getFieldName(field)} updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryCyan,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getFieldName(String field) {
    switch (field) {
      case 'name':
        return 'Name';
      case 'phone':
        return 'Phone Number';
      case 'address':
        return 'Address';
      case 'pincode':
        return 'Pincode';
      default:
        return field;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 80,
                color: darkBlue.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Please login to view your profile',
                style: TextStyle(
                  fontSize: 16,
                  color: darkBlue.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: primaryCyan),
            onPressed: () => _editField('name'),
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
                    primaryCyan.withOpacity(0.1),
                    primaryCyan.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: primaryCyan.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryCyan, width: 3),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: primaryCyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userData?['name'] ?? user.displayName ?? 'Customer',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? 'No email',
                    style: TextStyle(
                      fontSize: 14,
                      color: darkBlue.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Profile Info Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildInfoCard(
                    icon: Icons.person,
                    title: 'Name',
                    value: _userData?['name'] ?? 'Not provided',
                    onEdit: () => _editField('name'),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.phone,
                    title: 'Phone Number',
                    value: _userData?['phone'] ?? 'Not provided',
                    onEdit: () => _editField('phone'),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Address',
                    value: _userData?['address'] ?? 'Not provided',
                    onEdit: () => _editField('address'),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.local_post_office,
                    title: 'Pincode',
                    value:
                    _userData?['pincode']?.toString() ??
                        'Not provided',
                    onEdit: () => _editField('pincode'),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.email,
                    title: 'Email',
                    value: user.email ?? 'Not provided',
                    isEditable: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TermsAndConditionsScreen(),
                ),
              ),
              child: Text(
                "                 Terms & Conditions ",
                style: TextStyle(color: Colors.red),
              ),
            ),

            const SizedBox(height: 25),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // 🔥 Delete Account Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: OutlinedButton.icon(
                onPressed: _showDeleteAccountConfirmation,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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
          children: [
            Icon(icon, color: primaryCyan, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: darkBlue.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
    bool isEditable = true,
  }) {
    return Container(
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
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryCyan, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: darkBlue.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
          ),
          if (isEditable && onEdit != null)
            IconButton(
              icon: Icon(Icons.edit, color: primaryCyan, size: 20),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}