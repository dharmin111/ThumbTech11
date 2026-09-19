// lib/Admin/AdminScreens/AdminMerchantsScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../widget/hover_scale.dart';
import 'AdminMerchantDetailScreen.dart';

class AdminMerchantsScreen extends StatefulWidget {
  const AdminMerchantsScreen({super.key});

  @override
  State<AdminMerchantsScreen> createState() => _AdminMerchantsScreenState();
}

class _AdminMerchantsScreenState extends State<AdminMerchantsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Merchants Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF0C1B4D),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0C1B4D),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeaderStats(),
          _buildSearchAndFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('merchants')
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // ✅ Filter merchants
                List<Map<String, dynamic>> merchants = [];
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;

                  if (_searchQuery.isNotEmpty) {
                    final storeName = (data['storeName'] ?? '').toString().toLowerCase();
                    final ownerName = (data['ownerName'] ?? '').toString().toLowerCase();
                    final contactNumber = (data['contactNumber'] ?? '').toString();
                    final query = _searchQuery.toLowerCase();

                    if (!storeName.contains(query) &&
                        !ownerName.contains(query) &&
                        !contactNumber.contains(query)) {
                      continue;
                    }
                  }

                  final isVerified = data['isVerified'] == true;
                  if (_filterStatus == 'verified' && !isVerified) continue;
                  if (_filterStatus == 'pending' && isVerified) continue;

                  merchants.add(data);
                }

                if (merchants.isEmpty) {
                  return _buildNoResults();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: merchants.length,
                  itemBuilder: (context, index) {
                    return _buildMerchantCard(merchants[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ HEADER STATS BAR (TOP LEVEL)
  Widget _buildHeaderStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('merchants').snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        int verified = 0;
        int pending = 0;

        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['isVerified'] == true) {
              verified++;
            } else {
              pending++;
            }
          }
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              _buildHeaderStatCard(
                label: 'Total',
                value: total.toString(),
                icon: Icons.store,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildHeaderStatCard(
                label: 'Verified',
                value: verified.toString(),
                icon: Icons.verified,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildHeaderStatCard(
                label: 'Pending',
                value: pending.toString(),
                icon: Icons.pending,
                color: Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SEARCH + FILTER COMBINED
  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search store, owner, phone...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() => _searchQuery = '');
                  FocusScope.of(context).unfocus();
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),

          // Filter Chips
          Row(
            children: [
              _buildFilterChip('all', 'All', Icons.apps, Colors.blue),
              const SizedBox(width: 8),
              _buildFilterChip('verified', 'Verified', Icons.verified, Colors.green),
              const SizedBox(width: 8),
              _buildFilterChip('pending', 'Pending', Icons.pending, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String value,
      String label,
      IconData icon,
      Color color,
      ) {
    final isSelected = _filterStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _filterStatus = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(25) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ MERCHANT CARD (Fixed Image Display)
  Widget _buildMerchantCard(Map<String, dynamic> merchant) {
    final storeName = merchant['storeName'] ?? 'Unknown Store';
    final ownerName = merchant['ownerName'] ?? '';
    final contactNumber = merchant['contactNumber'] ?? '';
    final status = merchant['status'] ?? 'pending';
    final isVerified = merchant['isVerified'] == true;
    final isActive = merchant['isActive'] ?? true;

    // ✅ FIX: Read images from correct field
    final List<String> storePhotos =
    List<String>.from(merchant['storePhotoUrls'] ?? []);
    final categories = List<String>.from(merchant['categories'] ?? []);

    final locationData = merchant['location'] ?? merchant['locationModel'];
    final address = locationData?['address'] ?? '';

    return HoverScale(
      hoverScale: 1.02,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminMerchantDetailScreen(
              merchantId: merchant['id'] ?? '',
              merchantData: merchant,
            ),
          ),
        );
      },
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? const Color(0xFF2563EB).withAlpha(25)
                    : Colors.grey.withAlpha(20),
                blurRadius: isHovering ? 15 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ STORE IMAGE - FIXED
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: storePhotos.isNotEmpty
                              ? Image.network(
                            storePhotos[0],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            // ✅ DEBUG: Print URL
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              // ✅ Log the error for debugging
                              print('❌ Image error: $error');
                              print('❌ URL: ${storePhotos[0]}');
                              return _buildImagePlaceholder();
                            },
                          )
                              : _buildImagePlaceholder(),
                        ),
                        // Verified Badge
                        if (isVerified)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2E7D32),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // ✅ Photos Count Badge
                        if (storePhotos.length > 1)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(180),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${storePhotos.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // ✅ STORE INFO
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0C1B4D),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusBadge(status, isVerified),
                            ],
                          ),
                          const SizedBox(height: 4),

                          if (ownerName.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 3),
                                Text(
                                  ownerName,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),

                          const SizedBox(height: 4),

                          if (contactNumber.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 3),
                                Text(
                                  contactNumber,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),

                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ CATEGORIES
              if (categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: categories.take(3).map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42D7D7).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF42D7D7),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ✅ BOTTOM BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    // Photos count
                    Icon(
                      Icons.photo_library,
                      size: 14,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${storePhotos.length} photos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Active status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withAlpha(25)
                            : Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),

                    const Spacer(),

                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Status Badge
  Widget _buildStatusBadge(String status, bool isVerified) {
    Color color;
    String label;
    IconData icon;

    if (isVerified) {
      color = const Color(0xFF2E7D32);
      label = 'Verified';
      icon = Icons.verified;
    } else {
      switch (status) {
        case 'pending_approval':
          color = Colors.orange;
          label = 'Pending';
          icon = Icons.pending;
          break;
        case 'received':
        case 'uploaded':
          color = Colors.blue;
          label = 'Review';
          icon = Icons.hourglass_top;
          break;
        default:
          color = Colors.grey;
          label = 'Unverified';
          icon = Icons.help_outline;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.store,
        size: 36,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.store_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Merchants Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Merchants will appear here once they register',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading merchants',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}