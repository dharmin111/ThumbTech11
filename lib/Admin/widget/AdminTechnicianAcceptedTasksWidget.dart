// lib/Admin/widget/AdminTechnicianAcceptedTasksWidget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../AdminScreens/AdminTaskDetailScreen.dart';
import 'hover_scale.dart';

class AdminTechnicianAcceptedTasksWidget extends StatefulWidget {
  final bool isEmbedded;

  const AdminTechnicianAcceptedTasksWidget({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<AdminTechnicianAcceptedTasksWidget> createState() =>
      _AdminTechnicianAcceptedTasksWidgetState();
}

class _AdminTechnicianAcceptedTasksWidgetState
    extends State<AdminTechnicianAcceptedTasksWidget> {
  String _selectedFilter = 'accepted'; // 'all', 'accepted', 'completed', 'pending'
  final Map<String, Map<String, dynamic>> _techDataCache = {};

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'N/A') return;
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
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

  Widget _buildTechnicianProofs(String techId) {
    if (_techDataCache.containsKey(techId)) {
      return _renderProofImages(_techDataCache[techId]!);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(techId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                SizedBox(width: 6),
                Text('Loading proof images...',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox();
        }

        final techData = snapshot.data!.data() as Map<String, dynamic>;
        _techDataCache[techId] = techData;

        return _renderProofImages(techData);
      },
    );
  }

  Widget _renderProofImages(Map<String, dynamic> techData) {
    final String? idCardUrl =
        techData['idCardImageUrl'] ?? techData['idCardImage'];
    final List<dynamic> rawWorkPhotos = techData['workImages'] ??
        techData['previousWorkImageUrls'] ??
        techData['imageUrls'] ??
        [];
    final List<String> workPhotos =
        rawWorkPhotos.map((e) => e.toString()).toList();

    final bool hasIdCard = idCardUrl != null && idCardUrl.trim().isNotEmpty;
    final bool hasWorkPhotos = workPhotos.isNotEmpty;

    if (!hasIdCard && !hasWorkPhotos) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasIdCard) ...[
          const Text(
            '🪪 Identity Proof (ID Card):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showFullImageDialog(idCardUrl),
            child: Container(
              height: 60,
              width: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  idCardUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image,
                        size: 18, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (hasWorkPhotos) ...[
          const Text(
            '📸 Work Experience & Store Photos:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: workPhotos.length,
              itemBuilder: (context, index) {
                final url = workPhotos[index];
                return GestureDetector(
                  onTap: () => _showFullImageDialog(url),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image,
                              size: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FILTER CHIPS
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Accepted Tasks', 'accepted'),
                _buildFilterChip('All Tasks', 'all'),
                _buildFilterChip('Completed', 'completed'),
                _buildFilterChip('Pending (Unassigned)', 'pending'),
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

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No task requests found'));
              }

              var docs = snapshot.data!.docs;

              // Filter logic
              if (_selectedFilter == 'accepted') {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? '';
                  final hasTech = (data['technicianId'] != null &&
                          data['technicianId'].toString().isNotEmpty) ||
                      (data['technicianName'] != null &&
                          data['technicianName'].toString().isNotEmpty);
                  return (status == 'accepted' || status == 'in_progress' || hasTech);
                }).toList();
              } else if (_selectedFilter != 'all') {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == _selectedFilter;
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'accepted'
                              ? 'No tasks accepted by technicians yet'
                              : 'No tasks found for this filter',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return _buildTaskCard(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Technician Task Assignments',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: content,
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
          if (selected) {
            setState(() => _selectedFilter = value);
          }
        },
        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF2563EB),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTaskCard(String taskId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final serviceName = data['serviceName'] ?? 'Service Task';
    final customerName = data['userName'] ?? 'Customer';
    final customerPhone = data['userPhone'] ?? 'N/A';

    final String? techName = data['technicianName'];
    final String? techPhone = data['technicianPhone'];
    final String? techId = data['technicianId'];

    final bool hasTechnician = (techName != null && techName.isNotEmpty) ||
        (techId != null && techId.isNotEmpty);

    Color statusColor = Colors.orange;
    if (status == 'accepted') statusColor = const Color(0xFF2563EB);
    if (status == 'in_progress') statusColor = Colors.purple;
    if (status == 'completed') statusColor = Colors.green;
    if (status == 'cancelled') statusColor = Colors.red;

    String formattedDate = '';
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      formattedDate = DateFormat('dd MMM, hh:mm a')
          .format((data['createdAt'] as Timestamp).toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: HoverScale(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AdminTaskDetailScreen(taskId: taskId, taskData: data),
            ),
          );
        },
        builder: (context, isHovering, isPressed) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHovering
                    ? statusColor.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
                width: isHovering ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHovering
                      ? statusColor.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isHovering ? 14 : 6,
                  offset: Offset(0, isHovering ? 6 : 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TASK HEADER & STATUS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // CUSTOMER INFO
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Customer: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$customerName ($customerPhone)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // TECHNICIAN ACCEPTANCE SECTION
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasTechnician
                        ? const Color(0xFFEFF6FF)
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasTechnician
                          ? const Color(0xFFBFDBFE)
                          : Colors.amber.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasTechnician
                                ? Icons.engineering
                                : Icons.hourglass_empty,
                            size: 18,
                            color: hasTechnician
                                ? const Color(0xFF1D4ED8)
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasTechnician
                                ? 'ACCEPTED BY TECHNICIAN'
                                : 'NO TECHNICIAN ASSIGNED YET',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hasTechnician
                                  ? const Color(0xFF1D4ED8)
                                  : Colors.amber.shade900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (hasTechnician) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    techName ?? 'Technician Name N/A',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (techPhone != null &&
                                      techPhone.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Phone: $techPhone',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (techPhone != null && techPhone.isNotEmpty)
                              InkWell(
                                onTap: () => _makePhoneCall(techPhone),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Call',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // ✅ PROOF IMAGES (ID CARD & WORK/STORE PHOTOS)
                        if (techId != null && techId.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _buildTechnicianProofs(techId),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // FOOTER: LOCATION & BUDGET
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (data['location'] != null)
                      Expanded(
                        child: Text(
                          '📍 ${data['location']}${formattedDate.isNotEmpty ? " • $formattedDate" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      'Budget: ₹${data['budget'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
