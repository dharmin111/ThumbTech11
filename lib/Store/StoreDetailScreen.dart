// lib/presentation/TechnicianScreen/StoreDetailScreen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);

class StoreDetailScreen extends StatefulWidget {
  final String merchantId;
  final Map<String, dynamic>? merchantData;
  final double? latitude;  // ✅ Added
  final double? longitude; // ✅ Added

  const StoreDetailScreen({
    super.key,
    required this.merchantId,
    this.merchantData,
    this.latitude,   // ✅ Added
    this.longitude,  // ✅ Added
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _storeData;

  GoogleMapController? _mapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.merchantData != null) {
      _storeData = widget.merchantData;
      _isLoading = false;
    } else {
      _loadStoreData();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.merchantId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        data?['id'] = doc.id;
        setState(() => _storeData = data);
      }
    } catch (e) {
      print('❌ Error loading store: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri url = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    try {
      String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (!cleanNumber.startsWith('91') && cleanNumber.length == 10) {
        cleanNumber = '91$cleanNumber';
      }
      final Uri url = Uri.parse('https://wa.me/$cleanNumber');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ✅ View Location - Opens Google Maps (Location)
  Future<void> _openGoogleMaps(double lat, double lng) async {
    try {
      final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  // ✅ Get Directions - Opens Google Maps Navigation
  Future<void> _openGoogleMapsDirections(double lat, double lng) async {
    try {
      final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  void _showFullScreenImage(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openFullScreenMap(double lat, double lng, String storeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenMapView(
          latitude: lat,
          longitude: lng,
          storeName: storeName,
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
          child: CircularProgressIndicator(color: primaryCyan),
        ),
      );
    }

    if (_storeData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Store Details'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('Store not found')),
      );
    }

    final data = _storeData!;
    final storeName = data['storeName'] ?? 'Store';
    final ownerName = data['ownerName'] ?? '';
    final contactNumber = data['contactNumber'] ?? '';
    final whatsappNumber = data['whatsappNumber'] ?? '';
    final description = data['shortDescription'] ?? '';
    final categories = List<String>.from(data['categories'] ?? []);
    final storePhotos = List<String>.from(data['storePhotoUrls'] ?? []);
    final isVerified = data['isVerified'] ?? false;

    // ✅ LOCATION: Prefer explicit params, fallback to nested data
    final locationData = data['location'] ?? data['locationModel'];
    final address = locationData?['address'] ?? '';
    final placeName = locationData?['placeName'] ?? '';

    // ✅ Priority: widget param > location map
    final latitude = widget.latitude ??
        (locationData?['latitude']?.toDouble());
    final longitude = widget.longitude ??
        (locationData?['longitude']?.toDouble());

    // ✅ Debug
    print('═══════════════════════════════════════════');
    print('🟢 StoreDetail BUILD');
    print('📍 widget.latitude: ${widget.latitude}');
    print('📍 widget.longitude: ${widget.longitude}');
    print('📍 data[location]: $locationData');
    print('📍 Final lat: $latitude, lng: $longitude');
    print('═══════════════════════════════════════════');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          storeName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: darkBlue,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: darkBlue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1️⃣ STORE HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: primaryCyan,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: primaryCyan.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
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
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: darkBlue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (ownerName.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ownerName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: Colors.grey.shade200),

                // 2️⃣ ABOUT STORE
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description,
                              size: 18,
                              color: primaryCyan,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'About Store',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (description.isNotEmpty)
                  Divider(height: 1, color: Colors.grey.shade200),

                // 3️⃣ CATEGORIES
                if (categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.category,
                              size: 18,
                              color: primaryCyan,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((cat) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryCyan.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryCyan,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                if (categories.isNotEmpty)
                  Divider(height: 1, color: Colors.grey.shade200),

                // 4️⃣ CONTACT INFORMATION
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.contact_phone,
                            size: 18,
                            color: primaryCyan,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Contact Information',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (contactNumber.isNotEmpty)
                        _buildContactRow(
                          icon: Icons.phone,
                          label: 'Phone',
                          value: contactNumber,
                          onTap: () => _makePhoneCall(contactNumber),
                          color: Colors.green,
                        ),

                      if (whatsappNumber.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildContactRow(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          value: whatsappNumber,
                          onTap: () => _openWhatsApp(whatsappNumber),
                          color: const Color(0xFF25D366),
                        ),
                      ],

                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildContactRow(
                          icon: Icons.location_on,
                          label: 'Address',
                          value: address,
                          onTap: null,
                          color: primaryCyan,
                        ),
                      ],
                    ],
                  ),
                ),

                Divider(height: 1, color: Colors.grey.shade200),

                // 5️⃣ STORE LOCATION WITH MAP
                if (latitude != null && longitude != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: primaryCyan,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Store Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅ MAP VIEW
                        GestureDetector(
                          onTap: () => _openFullScreenMap(
                            latitude,
                            longitude,
                            storeName,
                          ),
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryCyan.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(latitude, longitude),
                                      zoom: 15,
                                    ),
                                    onMapCreated: (controller) {
                                      _mapController = controller;
                                      setState(() => _isMapReady = true);
                                    },
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId('store'),
                                        position:
                                        LatLng(latitude, longitude),
                                        infoWindow: InfoWindow(
                                          title: storeName,
                                          snippet: address,
                                        ),
                                      ),
                                    },
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    mapToolbarEnabled: false,
                                    compassEnabled: true,
                                  ),
                                  if (!_isMapReady)
                                    Container(
                                      color: Colors.grey.shade100,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: primaryCyan,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ✅ Location Details
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryCyan.withOpacity(0.1),
                                Colors.teal.shade50,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryCyan.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryCyan,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      placeName.isNotEmpty
                                          ? placeName
                                          : 'Store Location',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: darkBlue,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      address,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ✅ 2 BUTTONS: View Location + Get Directions
                        Row(
                          children: [
                            // ✅ View Location (Google Maps)
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openGoogleMaps(
                                    latitude,
                                    longitude,
                                  ),
                                  icon: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'View Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: darkBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // ✅ Get Directions (Navigation)
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openGoogleMapsDirections(
                                    latitude,
                                    longitude,
                                  ),
                                  icon: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Directions',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryCyan,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                if (latitude != null && longitude != null)
                  Divider(height: 1, color: Colors.grey.shade200),

                // 6️⃣ STORE IMAGES
                if (storePhotos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.photo_library,
                              size: 18,
                              color: primaryCyan,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Store Images',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildImageGallery(storePhotos),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Image Gallery
  Widget _buildImageGallery(List<String> photos) {
    final displayPhotos = photos.take(2).toList();
    final hasMore = photos.length > 2;

    if (displayPhotos.length == 1) {
      return GestureDetector(
        onTap: () => _showFullScreenImage(photos, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                displayPhotos[0],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: primaryCyan.withOpacity(0.1),
                    child: const Icon(
                      Icons.store,
                      size: 60,
                      color: primaryCyan,
                    ),
                  );
                },
              ),
              if (hasMore)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullScreenImage(photos, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                displayPhotos[0],
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 160,
                    color: primaryCyan.withOpacity(0.1),
                    child: const Icon(
                      Icons.store,
                      size: 40,
                      color: primaryCyan,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _showFullScreenImage(photos, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    displayPhotos[1],
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 160,
                        color: primaryCyan.withOpacity(0.1),
                        child: const Icon(
                          Icons.store,
                          size: 40,
                          color: primaryCyan,
                        ),
                      );
                    },
                  ),
                  if (hasMore)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '+${photos.length - 2}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Contact Row
  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
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
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkBlue,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
        ],
      ),
    );
  }
}

// ✅ Full Screen Map View
class _FullScreenMapView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String storeName;

  const _FullScreenMapView({
    required this.latitude,
    required this.longitude,
    required this.storeName,
  });

  @override
  State<_FullScreenMapView> createState() => _FullScreenMapViewState();
}

class _FullScreenMapViewState extends State<_FullScreenMapView> {
  late GoogleMapController _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.storeName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: darkBlue,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: darkBlue,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.latitude, widget.longitude),
              zoom: 17,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: {
              Marker(
                markerId: const MarkerId('store'),
                position: LatLng(widget.latitude, widget.longitude),
                infoWindow: InfoWindow(
                  title: widget.storeName,
                  snippet: 'Store Location',
                ),
              ),
            },
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                _mapController.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(widget.latitude, widget.longitude),
                      zoom: 17,
                    ),
                  ),
                );
              },
              backgroundColor: primaryCyan,
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Full Screen Image Viewer
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                      size: 60,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}