// lib/Admin/AdminScreens/AdminMerchantDetailScreen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminMerchantDetailScreen extends StatefulWidget {
  final String merchantId;
  final Map<String, dynamic>? merchantData;

  const AdminMerchantDetailScreen({
    super.key,
    required this.merchantId,
    this.merchantData,
  });

  @override
  State<AdminMerchantDetailScreen> createState() =>
      _AdminMerchantDetailScreenState();
}

class _AdminMerchantDetailScreenState extends State<AdminMerchantDetailScreen> {
  Map<String, dynamic>? _merchantData;
  bool _isLoading = true;
  bool _isUpdating = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.merchantData != null) {
      _merchantData = widget.merchantData;
      _isLoading = false;
    } else {
      _loadMerchant();
    }
  }

  // ✅ Load merchant data
  Future<void> _loadMerchant() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.merchantId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        data?['id'] = doc.id;
        setState(() => _merchantData = data);
      }
    } catch (e) {
      print('❌ Error loading merchant: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUTTON 1: UPDATE STATUS (waiting → verified)
  // ═══════════════════════════════════════════════════════
  Future<void> _updateStatus() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      print('═══════════════════════════════════════════');
      print('🔄 UPDATING STATUS');
      print('📌 Merchant ID: ${widget.merchantId}');

      final currentStatus = _merchantData?['status'] ?? 'pending';
      final newStatus = currentStatus == 'verified' ? 'waiting' : 'verified';

      // ✅ ONLY update status field
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.merchantId)
          .update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ status updated: $currentStatus → $newStatus');

      // ✅ Update local state
      setState(() {
        _merchantData?['status'] = newStatus;
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'verified'
                  ? '✅ Status updated to VERIFIED!'
                  : '⏳ Status reverted to WAITING',
            ),
            backgroundColor:
            newStatus == 'verified' ? Colors.blue : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      print('═══════════════════════════════════════════');
    } catch (e) {
      print('❌ Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ BUTTON 2: UPDATE VERIFIED (isVerified false ↔ true)
  // ═══════════════════════════════════════════════════════
  Future<void> _updateIsVerified() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      print('═══════════════════════════════════════════');
      print('🔄 UPDATING IS_VERIFIED');
      print('📌 Merchant ID: ${widget.merchantId}');

      final currentValue = _merchantData?['isVerified'] == true;
      final newValue = !currentValue;

      // ✅ ONLY update isVerified field
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.merchantId)
          .update({
        'isVerified': newValue,
        'verifiedAt': newValue ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ isVerified updated: $currentValue → $newValue');

      // ✅ Update local state
      setState(() {
        _merchantData?['isVerified'] = newValue;
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? '✅ Verified badge ADDED!'
                  : '❌ Verified badge REMOVED!',
            ),
            backgroundColor: newValue ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      print('═══════════════════════════════════════════');
    } catch (e) {
      print('❌ Error updating isVerified: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ✅ Toggle Active Status
  Future<void> _toggleActive(bool newValue) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.merchantId)
          .update({
        'isActive': newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _merchantData?['isActive'] = newValue;
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? '✅ Merchant activated!' : '❌ Merchant deactivated',
            ),
            backgroundColor: newValue ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating active: $e');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ✅ Phone call
  Future<void> _makePhoneCall(String phone) async {
    try {
      final Uri url = Uri.parse('tel:$phone');
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ✅ WhatsApp
  Future<void> _openWhatsApp(String phone) async {
    try {
      String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!clean.startsWith('91') && clean.length == 10) {
        clean = '91$clean';
      }
      final Uri url = Uri.parse('https://wa.me/$clean');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ✅ Full screen image viewer
  void _openImage(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImageViewer(
          images: images,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      );
    }

    if (_merchantData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Merchant Details'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('Merchant not found')),
      );
    }

    final data = _merchantData!;
    final storeName = data['storeName'] ?? 'Unknown Store';
    final ownerName = data['ownerName'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';
    final whatsappNumber = data['whatsappNumber'] ?? '';
    final description = data['shortDescription'] ?? '';
    final categories = List<String>.from(data['categories'] ?? []);
    final storePhotos = List<String>.from(data['storePhotoUrls'] ?? []);
    final status = data['status'] ?? 'pending';
    final isVerified = data['isVerified'] == true;
    final isActive = data['isActive'] ?? true; // ✅ Correct field

    final locationData = data['location'] ?? data['locationModel'];
    final address = locationData?['address'] ?? '';
    final placeName = locationData?['placeName'] ?? '';
    final latitude = locationData?['latitude'];
    final longitude = locationData?['longitude'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          storeName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMerchant,
        color: const Color(0xFF2563EB),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅✅✅ STATUS CARD (Button 1: Status)
              _buildStatusCard(status),

              const SizedBox(height: 12),

              // ✅✅✅ VERIFIED BADGE CARD (Button 2: isVerified)
              _buildVerifiedBadgeCard(isVerified),

              const SizedBox(height: 12),

              // ✅ ACTIVE TOGGLE CARD
              _buildActiveToggleCard(isActive),

              const SizedBox(height: 16),

              // ✅ STORE IMAGES CAROUSEL
              if (storePhotos.isNotEmpty) _buildImageCarousel(storePhotos),
              if (storePhotos.isNotEmpty) const SizedBox(height: 16),

              // ✅ STORE INFO
              _buildStoreInfoCard(
                storeName: storeName,
                ownerName: ownerName,
                status: status,
                isVerified: isVerified,
              ),
              const SizedBox(height: 16),

              // ✅ CONTACT INFO
              if (contactNumber.isNotEmpty || whatsappNumber.isNotEmpty)
                _buildContactCard(
                  contactNumber: contactNumber,
                  whatsappNumber: whatsappNumber,
                  onCall: () => _makePhoneCall(contactNumber),
                  onWhatsApp: () => _openWhatsApp(
                    whatsappNumber.isNotEmpty ? whatsappNumber : contactNumber,
                  ),
                ),
              if (contactNumber.isNotEmpty || whatsappNumber.isNotEmpty)
                const SizedBox(height: 16),

              // ✅ ABOUT
              if (description.isNotEmpty)
                _buildInfoCard(
                  icon: Icons.description,
                  title: 'About Store',
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              if (description.isNotEmpty) const SizedBox(height: 16),

              // ✅ CATEGORIES
              if (categories.isNotEmpty)
                _buildInfoCard(
                  icon: Icons.category,
                  title: 'Categories (${categories.length})',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42D7D7).withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF42D7D7).withAlpha(80),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF42D7D7),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (categories.isNotEmpty) const SizedBox(height: 16),

              // ✅ LOCATION
              if (address.isNotEmpty)
                _buildLocationCard(
                  address: address,
                  placeName: placeName,
                  latitude: latitude,
                  longitude: longitude,
                ),
              if (address.isNotEmpty) const SizedBox(height: 16),

              // ✅ ALL STORE PHOTOS
              if (storePhotos.isNotEmpty) _buildAllPhotosCard(storePhotos),
              if (storePhotos.isNotEmpty) const SizedBox(height: 16),

              // ✅ FIREBASE DETAILS
              _buildFirebaseInfoCard(data),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅✅✅ STATUS CARD - BUTTON 1
  // ═══════════════════════════════════════════════════════
  Widget _buildStatusCard(String status) {
    final isVerifiedStatus = status == 'verified';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVerifiedStatus
              ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
              : [Colors.orange.shade700, Colors.orange.shade900],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isVerifiedStatus ? Colors.blue : Colors.orange)
                .withAlpha(100),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerifiedStatus ? Icons.verified_user : Icons.pending_actions,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVerifiedStatus ? 'Verified ✅' : 'Waiting ⏳',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current: $status',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ STATUS UPDATE BUTTON
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _updateStatus,
              icon: _isUpdating
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(
                isVerifiedStatus
                    ? Icons.refresh
                    : Icons.check_circle_outline,
                color: Colors.white,
                size: 22,
              ),
              label: Text(
                _isUpdating
                    ? 'Updating...'
                    : isVerifiedStatus
                    ? 'RESET TO WAITING'
                    : 'SET STATUS VERIFIED',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Text(
            isVerifiedStatus
                ? '📌 Only "status" field will change'
                : '📌 Updates ONLY "status" field to "verified"',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withAlpha(180),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅✅✅ VERIFIED BADGE CARD - BUTTON 2
  // ═══════════════════════════════════════════════════════
  Widget _buildVerifiedBadgeCard(bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVerified
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : [Colors.grey.shade600, Colors.grey.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isVerified ? Colors.green : Colors.grey).withAlpha(100),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isVerified ? Icons.verified : Icons.verified_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VERIFIED BADGE (TAG)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVerified ? 'Badge Visible ✅' : 'Badge Hidden ❌',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'isVerified: $isVerified',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ✅ isVerified UPDATE BUTTON
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _updateIsVerified,
              icon: _isUpdating
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(
                isVerified ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
                size: 22,
              ),
              label: Text(
                _isUpdating
                    ? 'Updating...'
                    : isVerified
                    ? 'HIDE VERIFIED BADGE'
                    : 'SHOW VERIFIED BADGE',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Text(
            isVerified
                ? '📌 Only "isVerified" field will change to false'
                : '📌 Updates ONLY "isVerified" to true (shows badge in StoreScreen)',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withAlpha(180),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ✅ ACTIVE TOGGLE CARD
  Widget _buildActiveToggleCard(bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withAlpha(30)
                  : Colors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive ? Icons.check_circle : Icons.block,
              color: isActive ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Merchant is Active' : 'Merchant is Inactive',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Store is visible to technicians'
                      : 'Store is hidden from technicians',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'isActive: $isActive',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: _isUpdating ? null : _toggleActive,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.red,
          ),
        ],
      ),
    );
  }

  // ✅ IMAGE CAROUSEL
  Widget _buildImageCarousel(List<String> photos) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() => _currentImageIndex = index);
              },
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _openImage(photos, index),
                  child: Image.network(
                    photos[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.store,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Counter
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${photos.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Dots
            if (photos.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    photos.length,
                        (i) => Container(
                      width: _currentImageIndex == i ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _currentImageIndex == i
                            ? Colors.white
                            : Colors.white.withAlpha(128),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

            // Full screen hint
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ STORE INFO CARD
  Widget _buildStoreInfoCard({
    required String storeName,
    required String ownerName,
    required String status,
    required bool isVerified,
  }) {
    return _buildInfoCard(
      icon: Icons.store,
      title: 'Store Information',
      child: Column(
        children: [
          _buildInfoRow('Store Name', storeName),
          if (ownerName.isNotEmpty) _buildInfoRow('Owner Name', ownerName),
          _buildInfoRow('Merchant ID', widget.merchantId),
          _buildInfoRow('Status', status),
          _buildInfoRow('Verified Badge', isVerified ? 'Yes ✅' : 'No ❌'),
        ],
      ),
    );
  }

  // ✅ CONTACT CARD
  Widget _buildContactCard({
    required String contactNumber,
    required String whatsappNumber,
    required VoidCallback onCall,
    required VoidCallback onWhatsApp,
  }) {
    return _buildInfoCard(
      icon: Icons.contact_phone,
      title: 'Contact Information',
      child: Column(
        children: [
          if (contactNumber.isNotEmpty)
            _buildActionRow(
              icon: Icons.phone,
              label: 'Phone',
              value: contactNumber,
              color: Colors.green,
              onTap: onCall,
            ),
          if (whatsappNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildActionRow(
              icon: Icons.chat,
              label: 'WhatsApp',
              value: whatsappNumber,
              color: const Color(0xFF25D366),
              onTap: onWhatsApp,
            ),
          ],
        ],
      ),
    );
  }

  // ✅ LOCATION CARD
  Widget _buildLocationCard({
    required String address,
    required String placeName,
    required dynamic latitude,
    required dynamic longitude,
  }) {
    return _buildInfoCard(
      icon: Icons.location_on,
      title: 'Store Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (placeName.isNotEmpty)
            Text(
              placeName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C1B4D),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            address,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ ALL PHOTOS CARD
  Widget _buildAllPhotosCard(List<String> photos) {
    return _buildInfoCard(
      icon: Icons.photo_library,
      title: 'All Store Photos (${photos.length})',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openImage(photos, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    photos[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ FIREBASE INFO CARD
  Widget _buildFirebaseInfoCard(Map<String, dynamic> data) {
    return _buildInfoCard(
      icon: Icons.info_outline,
      title: 'System Information',
      child: Column(
        children: [
          _buildInfoRow('Document ID', widget.merchantId),
          _buildInfoRow('Created At', _formatTimestamp(data['createdAt'])),
          _buildInfoRow('Last Updated', _formatTimestamp(data['updatedAt'])),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime dt;
      if (timestamp is Timestamp) {
        dt = timestamp.toDate();
      } else if (timestamp is String) {
        dt = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  // ✅ INFO CARD WRAPPER
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
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
              Icon(icon, size: 18, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C1B4D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ✅ INFO ROW
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0C1B4D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ACTION ROW
  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0C1B4D),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ FULL SCREEN IMAGE VIEWER
class _ImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 16),
        ),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}