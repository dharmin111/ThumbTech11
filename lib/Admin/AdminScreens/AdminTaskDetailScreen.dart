// Admin/AdminScreens/AdminTaskDetailScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'AdminUserDetailScreen.dart';

class AdminTaskDetailScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const AdminTaskDetailScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  @override
  State<AdminTaskDetailScreen> createState() => _AdminTaskDetailScreenState();
}

class _AdminTaskDetailScreenState extends State<AdminTaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.taskData;
    final status = data['status'] ?? 'pending';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Completed';
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        statusLabel = 'Accepted';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'Cancelled';
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusLabel = 'In Progress';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusLabel = 'Pending';
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          data['serviceName'] ?? 'Task Details',
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
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ Status Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            statusIcon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['serviceName'] ?? 'Service Request',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Status: $statusLabel',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#${widget.taskId.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ✅ Customer Info
              _buildInfoSection(
                title: '👤 Customer Information',
                icon: Icons.person,
                children: [
                  _buildInfoRow('Customer Name', data['userName'] ?? 'N/A'),
                  _buildInfoRow('Phone', data['userPhone'] ?? 'N/A'),
                  _buildInfoRow('Email', data['userEmail'] ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Assigned / Accepted Technician Info
              _buildInfoSection(
                title: '🛠️ Assigned Technician Information',
                icon: Icons.engineering,
                children: [
                  _buildInfoRow(
                    'Technician Name',
                    data['technicianName'] ??
                        ((data['technicianId'] != null &&
                                data['technicianId'].toString().isNotEmpty)
                            ? 'Assigned Technician'
                            : 'No Technician Assigned Yet'),
                  ),
                  _buildInfoRow('Technician Phone', data['technicianPhone'] ?? 'N/A'),
                  if (data['technicianId'] != null &&
                      data['technicianId'].toString().isNotEmpty) ...[
                    _buildInfoRow('Technician ID', data['technicianId']),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openTechnicianProfile(data['technicianId']),
                        icon: const Icon(Icons.badge_outlined, size: 16),
                        label: const Text(
                          'View Technician Profile & Proofs',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Service Details
              _buildInfoSection(
                title: '🔧 Service Details',
                icon: Icons.build,
                children: [
                  _buildInfoRow('Service Type', data['serviceType'] ?? 'N/A'),
                  _buildInfoRow('Budget', '₹${data['budget'] ?? 0}'),
                  _buildInfoRow('Issue', data['issue'] ?? 'N/A'),
                  if (data['description'] != null &&
                      data['description'].isNotEmpty)
                    _buildInfoRow('Description', data['description']),
                  if (data['additionalNote'] != null &&
                      data['additionalNote'].isNotEmpty)
                    _buildInfoRow('Additional Note', data['additionalNote']),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Location Details
              if (data['location'] != null || data['pincode'] != null)
                _buildInfoSection(
                  title: '📍 Location Details',
                  icon: Icons.location_on,
                  children: [
                    if (data['location'] != null && data['location'].isNotEmpty)
                      _buildInfoRow('Location', data['location']),
                    if (data['pincode'] != null && data['pincode'].isNotEmpty)
                      _buildInfoRow('Pincode', data['pincode']),
                    if (data['city'] != null && data['city'].isNotEmpty)
                      _buildInfoRow('City', data['city']),
                    if (data['state'] != null && data['state'].isNotEmpty)
                      _buildInfoRow('State', data['state']),
                  ],
                ),
              const SizedBox(height: 16),

              // ✅ Timeline
              _buildInfoSection(
                title: '⏰ Timeline',
                icon: Icons.timeline,
                children: [
                  _buildInfoRow(
                    'Created At',
                    createdAt != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)
                        : 'N/A',
                  ),
                  if (data['updatedAt'] != null)
                    _buildInfoRow(
                      'Last Updated',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format((data['updatedAt'] as Timestamp).toDate()),
                    ),
                  if (data['assignedAt'] != null)
                    _buildInfoRow(
                      'Assigned At',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format((data['assignedAt'] as Timestamp).toDate()),
                    ),
                  if (data['completedAt'] != null)
                    _buildInfoRow(
                      'Completed At',
                      DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format((data['completedAt'] as Timestamp).toDate()),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ✅ Task Uploaded Photos
              if (data['imageUrls'] != null &&
                  (data['imageUrls'] as List).isNotEmpty) ...[
                _buildTaskImageSection(
                  List<String>.from(data['imageUrls']),
                ),
                const SizedBox(height: 16),
              ],

              // ✅ Action Buttons
              _buildActionButtons(status, statusColor),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== OPEN TECHNICIAN PROFILE ====================
  Future<void> _openTechnicianProfile(String techId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final techDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(techId)
          .get();

      if (mounted) Navigator.pop(context); // Close loading

      if (techDoc.exists && techDoc.data() != null) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminUserDetailScreen(
              userId: techId,
              userData: techDoc.data()!,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Technician user profile not found')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading technician profile: $e')),
        );
      }
    }
  }

  // ==================== TASK IMAGE SECTION ====================
  Widget _buildTaskImageSection(List<String> imageUrls) {
    return Container(
      width: double.infinity,
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
          const Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text(
                '📸 Task Photos (Uploaded by Customer)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final url = imageUrls[index];
                return GestureDetector(
                  onTap: () => _showFullImageDialog(url),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: const Text('Failed to load image'),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== INFO SECTION ====================
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

  // ==================== INFO ROW ====================
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons(String status, Color statusColor) {
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'pending')
                _buildActionButton(
                  label: 'Accept',
                  icon: Icons.check_circle,
                  color: Colors.green,
                  onTap: () => _updateStatus('accepted'),
                ),
              if (status == 'pending' || status == 'accepted')
                _buildActionButton(
                  label: 'In Progress',
                  icon: Icons.hourglass_empty,
                  color: Colors.orange,
                  onTap: () => _updateStatus('in_progress'),
                ),
              if (status == 'in_progress')
                _buildActionButton(
                  label: 'Complete',
                  icon: Icons.done_all,
                  color: Colors.green,
                  onTap: () => _updateStatus('completed'),
                ),
              if (status != 'completed' && status != 'cancelled')
                _buildActionButton(
                  label: 'Cancel',
                  icon: Icons.cancel,
                  color: Colors.red,
                  onTap: () => _updateStatus('cancelled'),
                ),
              _buildActionButton(
                label: 'Delete',
                icon: Icons.delete,
                color: Colors.red,
                onTap: () => _deleteTask(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: const Size(0, 40),
      ),
    );
  }

  // ==================== ACTIONS ====================
  Future<void> _updateStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(widget.taskId)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            if (newStatus == 'completed')
              'completedAt': FieldValue.serverTimestamp(),
            if (newStatus == 'accepted')
              'assignedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
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
            .collection('service_requests')
            .doc(widget.taskId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted successfully'),
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
