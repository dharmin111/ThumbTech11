// lib/presentation/CostomerScreens/ProfileScreen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../TechnicianCustomertermAndCondition/TermsAndConditionsScreen.dart';
import '../authScreen/LoginScreen.dart';
import '../../Services/oneSignalNotificationService.dart';
import '../widgets/ReportDialog.dart';
import '../widgets/BlockDialog.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _ensureOneSignalId();
  }

  // ==================== RE-AUTHENTICATION ====================

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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
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
    if (password == null || password.isEmpty) return;

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
      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      print('✅ Re-authentication successful');

      final userId = user.uid;

      // Delete profile image
      if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(_profileImageUrl!);
          await ref.delete();
          print('✅ Profile image deleted');
        } catch (e) {
          print('⚠️ Error deleting profile image: $e');
        }
      }

      // Delete service requests
      final requestsSnapshot = await _firestore
          .collection('service_requests')
          .where('userId', isEqualTo: userId)
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
          .where('customerId', isEqualTo: userId)
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

  // ==================== EXISTING METHODS ====================

  Future<void> _ensureOneSignalId() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final oneSignalId = doc.data()?['oneSignalId'];

      if (oneSignalId == null || oneSignalId.toString().isEmpty) {
        print('📱 Auto-saving OneSignal ID for customer');
        await OneSignalNotificationService.saveOneSignalId(
          userId: user.uid,
          userRole: 'customer',
        );
      } else {
        print('✅ OneSignal ID already exists: $oneSignalId');
      }
    } catch (e) {
      print('Error ensuring OneSignal ID: $e');
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
            _profileImageUrl = _userData?['profileImageUrl'];
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }

    setState(() => _isLoading = false);
  }
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close dialog
              Navigator.pop(dialogContext);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext loadingContext) =>
                const Center(child: CircularProgressIndicator()),
              );

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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      case 'pincodes':
        return 'Pincodes';
      default:
        return field;
    }
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧 Email: flakeinsta@gmail.com'),
            SizedBox(height: 8),
            Text('📱 Phone: +91 7087 234563'),
            SizedBox(height: 8),
            Text('🕐 Support Hours: 9:00 AM – 9:00 PM (Mon–Sat)'),
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

  // ==================== OPEN SUPPORT PAGE ====================

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

  // ==================== BUILD ====================

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
                onPressed: () => Navigator.pushNamed(context, '/login'),
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
                    value: _userData?['pincode']?.toString() ?? 'Not provided',
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

            // ✅ Terms & Conditions
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TermsAndConditionsScreen(),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.description, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Terms & Conditions",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ✅ Support - Opens Support Page
            GestureDetector(
              onTap: _openSupportPage,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.help_outline, color: primaryCyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Get Support",
                      style: TextStyle(
                        color: primaryCyan,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ✅ Help & Support (In-App Dialog)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _showHelpSupport,
                icon: const Icon(Icons.support_agent),
                label: const Text('Help & Support'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryCyan,
                  side: const BorderSide(color: primaryCyan),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _showLogoutConfirmation,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Delete Account Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _showDeleteAccountConfirmation,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                  minimumSize: const Size(double.infinity, 45),
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