// presentation/AdminScreen/admin_requests.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widget/hover_scale.dart';
import 'AdminTaskDetailScreen.dart'; // ✅ Import Task Detail

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Service Requests'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
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
      body: Column(
        children: [
          // Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'All'),
                  _buildFilterChip('Pending', 'pending'),
                  _buildFilterChip('Accepted', 'accepted'),
                  // _buildFilterChip('In Progress', 'in_progress'),
                  _buildFilterChip('Completed', 'completed'),
                  _buildFilterChip('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_requests')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var requests = snapshot.data!.docs;

                if (_selectedFilter != 'All') {
                  requests = requests.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == _selectedFilter;
                  }).toList();
                }

                if (requests.isEmpty) {
                  return const Center(child: Text('No requests found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final doc = requests[index];
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id; // ✅ Add ID
                    return _buildRequestCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'All';
          });
        },
        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
        checkmarkColor: const Color(0xFF2563EB),
      ),
    );
  }

  // ✅ HOVER-ANIMATED REQUEST CARD WITH ONTAP
  Widget _buildRequestCard(String requestId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      // case 'in_progress':
      //   statusColor = Colors.orange;
      //   statusIcon = Icons.hourglass_empty;
      //   break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return HoverScale(
      onTap: () {
        // ✅ Navigate to Task Detail Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AdminTaskDetailScreen(taskId: requestId, taskData: data),
          ),
        );
      },
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovering
                  ? statusColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? statusColor.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.05),
                blurRadius: isHovering ? 16 : 8,
                offset: Offset(0, isHovering ? 6 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['serviceName'] ?? 'Service Request',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: ${data['userName'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Budget: ₹${data['budget'] ?? 0}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ✅ Status Dropdown (Fixed)
              _buildStatusDropdown(requestId, status, statusColor),
            ],
          ),
        );
      },
    );
  }

  // ✅ FIXED: Status Dropdown with proper items
  Widget _buildStatusDropdown(
    String requestId,
    String currentStatus,
    Color statusColor,
  ) {
    // ✅ All possible status options
    final List<String> allStatuses = [
      'pending',
      'accepted',
      //'in_progress',
      'completed',
      'cancelled',
    ];

    // ✅ Ensure current status is in the list
    final validStatuses = allStatuses.contains(currentStatus)
        ? allStatuses
        : ['pending', 'accepted', 'completed', 'cancelled'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: validStatuses.contains(currentStatus)
                ? currentStatus
                : 'pending',
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            iconSize: 20,
            elevation: 2,
            underline: const SizedBox(),
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (newStatus) {
              if (newStatus != null) {
                _updateRequestStatus(requestId, newStatus);
              }
            },
            items: validStatuses.map((status) {
              String label;
              switch (status) {
                case 'pending':
                  label = 'Pending';
                  break;
                case 'accepted':
                  label = 'Accepted';
                  break;
                //case 'in_progress': label = 'In Progress'; break;
                case 'completed':
                  label = 'Completed';
                  break;
                case 'cancelled':
                  label = 'Cancelled';
                  break;
                default:
                  label = status;
              }
              return DropdownMenuItem<String>(
                value: status,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      // case 'in_progress': return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
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
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
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
