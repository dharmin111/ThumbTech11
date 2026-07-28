// Admin/AdminScreens/AdminUserDetailScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Map<String, dynamic> userData;
  late String userId;

  @override
  void initState() {
    super.initState();
    // ✅ Assign values
    userId = widget.userId;
    userData = widget.userData;

    print('✅ UserDetailScreen opened for: $userId');
    print('📦 Data: $userData');
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Check if data exists
    if (userData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Details'),
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('No user data available'),
            ],
          ),
        ),
      );
    }

    final role = userData['role'] ?? 'customer';
    final isActive = userData['isActive'] ?? true;
    final isApproved = userData['isApproved'] ?? false;
    final name = userData['name'] ?? 'Unknown User';
    final email = userData['email'] ?? 'No Email';
    final phone = userData['phone'] ?? userData['phoneNumber'] ?? 'N/A';
    final createdAt = (userData['createdAt'] as Timestamp?)?.toDate();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          role == 'technician'
              ? 'Technician Details'
              : role == 'admin'
              ? 'Admin Details'
              : 'Customer Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Profile Header
            _buildProfileHeader(role, isActive, isApproved, name, email),
            const SizedBox(height: 16),

            // ✅ Personal Information
            _buildInfoSection(
              title: '📋 Personal Information',
              icon: Icons.person,
              children: [
                _buildInfoRow('Full Name', name),
                _buildInfoRow('Email', email),
                _buildInfoRow('Phone', phone),
                _buildInfoRow('Role', role.toUpperCase()),
                if (userData['bio'] != null && userData['bio'].isNotEmpty)
                  _buildInfoRow('Bio', userData['bio']),
              ],
            ),
            const SizedBox(height: 16),

            // ✅ Customer Specific Info
            if (role == 'customer') _buildCustomerInfo(),
            if (role == 'customer') const SizedBox(height: 16),

            // ✅ Technician Specific Info
            if (role == 'technician') _buildTechnicianInfo(),
            if (role == 'technician') const SizedBox(height: 16),

            // ✅ Account Info
            _buildAccountInfo(createdAt),
            const SizedBox(height: 16),

            // ✅ Action Buttons
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==================== PROFILE HEADER ====================
  Widget _buildProfileHeader(
    String role,
    bool isActive,
    bool isApproved,
    String name,
    String email,
  ) {
    Color roleColor;
    IconData roleIcon;
    String roleLabel;

    switch (role) {
      case 'technician':
        roleColor = Colors.blue;
        roleIcon = Icons.build;
        roleLabel = 'Technician';
        break;
      case 'admin':
        roleColor = Colors.purple;
        roleIcon = Icons.admin_panel_settings;
        roleLabel = 'Admin';
        break;
      default:
        roleColor = Colors.green;
        roleIcon = Icons.person;
        roleLabel = 'Customer';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor, roleColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(roleIcon, size: 40, color: roleColor),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  roleLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Approval Badge (for admin)
              if (role == 'admin')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isApproved ? 'APPROVED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 11,
                      color: isApproved
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== CUSTOMER INFO ====================
  Widget _buildCustomerInfo() {
    return _buildInfoSection(
      title: '🏠 Customer Details',
      icon: Icons.home,
      children: [
        if (userData['address'] != null && userData['address'].isNotEmpty)
          _buildInfoRow('Address', userData['address']),
        if (userData['city'] != null && userData['city'].isNotEmpty)
          _buildInfoRow('City', userData['city']),
        if (userData['state'] != null && userData['state'].isNotEmpty)
          _buildInfoRow('State', userData['state']),
        if (userData['pincode'] != null && userData['pincode'].isNotEmpty)
          _buildInfoRow('Pincode', userData['pincode']),
      ],
    );
  }

  // ==================== TECHNICIAN INFO ====================
  Widget _buildTechnicianInfo() {
    final categories = userData['categories'] ?? [];
    final pincodes = userData['pincodes'] ?? [];
    final status = userData['status'] ?? 'pending';

    return _buildInfoSection(
      title: '🔧 Technician Details',
      icon: Icons.build,
      children: [
        _buildInfoRow('Status', status.toUpperCase()),
        if (userData['description'] != null &&
            userData['description'].isNotEmpty)
          _buildInfoRow('Description', userData['description']),
        if (categories.isNotEmpty) _buildChipsRow('Categories', categories),
        if (pincodes.isNotEmpty) _buildChipsRow('Service Areas', pincodes),
      ],
    );
  }

  // ==================== ACCOUNT INFO ====================
  Widget _buildAccountInfo(DateTime? createdAt) {
    return _buildInfoSection(
      title: '⏰ Account Info',
      icon: Icons.account_circle,
      children: [
        _buildInfoRow(
          'Created At',
          createdAt != null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)
              : 'N/A',
        ),
        if (userData['lastLogin'] != null)
          _buildInfoRow(
            'Last Login',
            DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format((userData['lastLogin'] as Timestamp).toDate()),
          ),
      ],
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons() {
    final isActive = userData['isActive'] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleUserStatus(userId, isActive),
                  icon: Icon(
                    isActive ? Icons.block : Icons.check_circle,
                    size: 18,
                  ),
                  label: Text(isActive ? 'Deactivate' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _deleteUser(userId),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Users'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
              Icon(icon, color: const Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsRow(String label, List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2563EB),
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

  // ==================== ACTIONS ====================
  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isActive': !currentStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${currentStatus ? 'deactivated' : 'activated'} successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          userData['isActive'] = !currentStatus;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text(
          'Are you sure you want to delete this user? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
