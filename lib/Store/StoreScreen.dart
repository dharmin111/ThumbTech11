// lib/presentation/TechnicianScreen/StoreScreen.dart

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../model/LocationModel.dart';
import 'StoreDetailScreen.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  // ═══════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════
  bool _isLoading = true;
  bool _isFetchingLocation = false;
  String? _selectedCategory;
  LocationModel? _currentLocation;

  // ✅ Original list — Firestore se aayi hui, kabhi change nahi hoti
  List<Map<String, dynamic>> _originalMerchants = [];

  // ✅ Distance + verified filter ke baad wali list (category ke bina)
  List<Map<String, dynamic>> _allMerchants = [];

  // ✅ Category filter ke baad final list jo UI pe dikhti hai
  List<Map<String, dynamic>> _filteredMerchants = [];

  // ✅ Radius
  double _radiusInKm = 10.0;

  final List<String> _categories = [
    'AC Parts',
    'Washing Machine Parts',
    'Water Purifier Parts',
    'Plumbing Parts',
    'Electrical Parts',
    'Carpentry Tools',
    'Painting Supplies',
    'Cleaning Equipment',
    'Refrigerator Parts',
    'TV Parts',
    'Hardware Tools',
    'Home Appliance Parts',
    'CCTV Parts',
    'Geyser Parts',
    'Chimney Parts',
    'Furniture Hardware',
    'Automotive Parts',
  ];

  // ═══════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _selectedCategory = 'AC Parts';
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadMerchants();
    if (mounted && _currentLocation == null) {
      await _autoFetchLocation();
    }
  }

  // ═══════════════════════════════════════════════════════
  // AUTO LOCATION
  // ═══════════════════════════════════════════════════════
  Future<void> _autoFetchLocation() async {
    print('═══════════════════════════════════════════');
    print('🔄 Auto-fetching location on screen load...');

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('⚠️ Location permission denied');
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        print('📍 Auto location: ${position.latitude}, ${position.longitude}');

        if (mounted) {
          setState(() {
            _currentLocation = LocationModel(
              latitude: position.latitude,
              longitude: position.longitude,
              address: 'Current Location',
              placeName: 'Current Location',
            );
          });

          _filterMerchantsByDistance();
          print('✅ Auto location fetched');
        }
      }
    } catch (e) {
      print('⚠️ Auto-fetch failed (silent): $e');
    }
    print('═══════════════════════════════════════════');
  }

  // ═══════════════════════════════════════════════════════
  // LOAD MERCHANTS FROM FIRESTORE
  // ═══════════════════════════════════════════════════════
  Future<void> _loadMerchants() async {
    setState(() => _isLoading = true);

    try {
      print('═══════════════════════════════════════════');
      print('📥 Loading merchants...');

      // ✅ Sirf isActive + status filter — isVerified filter HATA diya
      // (taake non-verified bhi load hon, distance filter baad mein lagega)
      final snapshot = await FirebaseFirestore.instance
          .collection('merchants')
         // .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: 'verified')
          .get();

      print('📥 Found ${snapshot.docs.length} active merchants');

      List<Map<String, dynamic>> merchants = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        final loc = data['location'] ?? data['locationModel'];
        print('🏪 ${data['storeName']}');
        print('   ✅ isVerified: ${data['isVerified'] ?? false}');
        print('   📍 location: ${loc != null ? "✅" : "❌"}');

        merchants.add(data);
      }

      // ✅ Original list preserve karein
      setState(() {
        _originalMerchants = List.from(merchants);
        _allMerchants = List.from(merchants);
      });

      // Agar location available hai to distance filter lagayein
      if (_currentLocation != null) {
        _filterMerchantsByDistance();
      } else {
        setState(() {
          _filteredMerchants = merchants;
        });
      }

      print('═══════════════════════════════════════════');
    } catch (e) {
      print('❌ Error loading merchants: $e');
      _showSnackBar('Error loading stores: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // MANUAL LOCATION (with notifications)
  // ═══════════════════════════════════════════════════════
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission denied', Colors.red);
        setState(() => _isFetchingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 Manual location: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentLocation = LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          address: 'Current Location',
          placeName: 'Current Location',
        );
      });

      _filterMerchantsByDistance();
      _showSnackBar('📍 Location updated!', Colors.green);
    } catch (e) {
      print('❌ Error getting location: $e');
      _showSnackBar('Error getting location: $e', Colors.red);
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MAIN FILTER: DISTANCE (10 km) + VERIFIED PRIORITY
  // ═══════════════════════════════════════════════════════
  //
  // Logic:
  //   1. Har merchant ka distance calculate karo
  //   2. Agar distance > 10 km  → SKIP (chahe verified ho ya non-verified)
  //   3. Verified merchants  → verifiedMerchants list mein
  //   4. Non-verified        → nonVerifiedMerchants list mein
  //   5. Dono ko distance se sort karo (paas wale pehle)
  //   6. Final: [Verified (sorted), Non-Verified (sorted)]
  //
  // Result:
  //   ┌──────────────────────────────┐
  //   │ ✅ Verified (0-10 km)         │  ← top pe
  //   │ 📍 Non-Verified (0-10 km)     │  ← neeche
  //   │ ❌ 10 km se door (dono)       │  ← HIDDEN
  //   └──────────────────────────────┘
  //
  void _filterMerchantsByDistance() {
    if (_currentLocation == null) {
      _filterByCategory();
      return;
    }

    List<Map<String, dynamic>> verifiedMerchants = [];
    List<Map<String, dynamic>> nonVerifiedMerchants = [];

    // ✅ ORIGINAL list par loop karein (shrink nahi hogi)
    for (var original in _originalMerchants) {
      // ✅ Copy banayein taake original mutate na ho
      final merchant = Map<String, dynamic>.from(original);

      final isVerified = merchant['isVerified'] == true;
      final locationData = merchant['location'] ?? merchant['locationModel'];

      // ⚠️ Location nahi hai to skip
      if (locationData == null) continue;

      final merchantLat = locationData['latitude'];
      final merchantLng = locationData['longitude'];

      if (merchantLat == null || merchantLng == null) continue;

      // ✅ Distance calculate karein
      final distance = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        merchantLat,
        merchantLng,
      );

      merchant['distance'] = distance;
      merchant['distanceFormatted'] = _formatDistance(distance);

      // ✅ 10 km se door wale SKIP (verified aur non-verified dono)
      if (distance > _radiusInKm) continue;

      // ✅ 10 km ke andar wale — verified/non-verified mein baant dein
      if (isVerified) {
        verifiedMerchants.add(merchant);
      } else {
        nonVerifiedMerchants.add(merchant);
      }
    }

    // ✅ Verified ko distance se sort karein (paas wale pehle)
    verifiedMerchants.sort((a, b) {
      final distA = a['distance'] as double? ?? 999999;
      final distB = b['distance'] as double? ?? 999999;
      return distA.compareTo(distB);
    });

    // ✅ Non-verified ko bhi distance se sort karein
    nonVerifiedMerchants.sort((a, b) {
      final distA = a['distance'] as double? ?? 999999;
      final distB = b['distance'] as double? ?? 999999;
      return distA.compareTo(distB);
    });

    // ✅ FINAL ORDER: Verified pehle, phir non-verified
    final combined = [...verifiedMerchants, ...nonVerifiedMerchants];

    print('═══════════════════════════════════════════');
    print('✅ Verified within ${_radiusInKm}km: ${verifiedMerchants.length}');
    print('📍 Non-verified within ${_radiusInKm}km: ${nonVerifiedMerchants.length}');
    print('❌ Hidden (over ${_radiusInKm}km): ${_originalMerchants.length - combined.length}');
    print('📊 Total shown: ${combined.length}');
    print('═══════════════════════════════════════════');

    setState(() {
      _allMerchants = combined;
    });

    _filterByCategory();
  }

  // ═══════════════════════════════════════════════════════
  // CATEGORY FILTER
  // ═══════════════════════════════════════════════════════
  void _filterByCategory() {
    if (_selectedCategory == null) {
      setState(() {
        _filteredMerchants = List.from(_allMerchants);
      });
      return;
    }

    List<Map<String, dynamic>> filtered = [];

    for (var merchant in _allMerchants) {
      final categories = merchant['categories'];
      if (categories == null) continue;

      List<String> merchantCategories = List<String>.from(categories);

      if (merchantCategories.contains(_selectedCategory)) {
        filtered.add(merchant);
      }
    }

    // ✅ Verified pehle, phir distance se sort
    filtered.sort((a, b) {
      final isVerifiedA = a['isVerified'] == true ? 0 : 1;
      final isVerifiedB = b['isVerified'] == true ? 0 : 1;

      if (isVerifiedA == isVerifiedB) {
        final distA = a['distance'] as double? ?? 999999;
        final distB = b['distance'] as double? ?? 999999;
        return distA.compareTo(distB);
      }

      return isVerifiedA.compareTo(isVerifiedB);
    });

    setState(() {
      _filteredMerchants = filtered;
    });
  }

  // ═══════════════════════════════════════════════════════
  // DISTANCE HELPERS
  // ═══════════════════════════════════════════════════════
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = pow(sin(dLat / 2), 2) +
        pow(sin(dLon / 2), 2) *
            cos(_toRadians(lat1)) *
            cos(_toRadians(lat2));

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  // ═══════════════════════════════════════════════════════
  // ACTIONS: CALL, VIEW, DIRECTIONS
  // ═══════════════════════════════════════════════════════
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri url = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showSnackBar('Cannot make call', Colors.red);
      }
    } catch (e) {
      print('❌ Error: $e');
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _viewLocation(double lat, double lng) async {
    try {
      final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Cannot open Google Maps', Colors.red);
      }
    } catch (e) {
      print('❌ Error: $e');
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _getDirections(double lat, double lng) async {
    try {
      final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Cannot open Google Maps', Colors.red);
      }
    } catch (e) {
      print('❌ Error: $e');
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _openStoreDetail(Map<String, dynamic> merchant) {
    final locationData = merchant['location'] ?? merchant['locationModel'];
    final latitude = locationData?['latitude'];
    final longitude = locationData?['longitude'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreDetailScreen(
          merchantId: merchant['id'] ?? '',
          merchantData: merchant,
          latitude: latitude?.toDouble(),
          longitude: longitude?.toDouble(),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Nearby Stores',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: darkBlue,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryCyan),
            onPressed: _loadMerchants,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationBar(),
          _buildCategoryFilter(),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: primaryCyan),
            )
                : _filteredMerchants.isEmpty
                ? _buildEmptyState()
                : _buildMerchantsList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // LOCATION BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildLocationBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(
            Icons.location_on,
            color: Color(0xFF3B82F6),
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _currentLocation != null
                  ? 'Near: Current Location (${_radiusInKm.toInt()} km)'
                  : 'Near: Select Location',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: darkBlue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _isFetchingLocation ? null : _getCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: primaryCyan,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isFetchingLocation)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryCyan,
                      ),
                    )
                  else
                    const Icon(
                      Icons.my_location,
                      size: 14,
                      color: primaryCyan,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _isFetchingLocation
                        ? '...'
                        : _currentLocation != null
                        ? 'Update'
                        : 'Locate',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryCyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // CATEGORY CHIPS
  // ═══════════════════════════════════════════════════════
  Widget _buildCategoryFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                _filterByCategory();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryCyan.withOpacity(0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? primaryCyan : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? primaryCyan : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _currentLocation == null
                  ? Icons.location_off
                  : Icons.store_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _currentLocation == null
                  ? 'Location Required'
                  : 'No Stores Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentLocation == null
                  ? 'Tap "Locate" button to find nearby stores'
                  : 'No stores with "$_selectedCategory" category within ${_radiusInKm.toInt()} km',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_currentLocation == null)
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Get My Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // MERCHANTS LIST
  // ═══════════════════════════════════════════════════════
  Widget _buildMerchantsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _filteredMerchants.length + 1,
      itemBuilder: (context, index) {
        if (index == _filteredMerchants.length) {
          return _buildFooterMessage();
        }

        final merchant = _filteredMerchants[index];
        return _buildStoreCard(merchant);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // STORE CARD
  // ═══════════════════════════════════════════════════════
  Widget _buildStoreCard(Map<String, dynamic> merchant) {
    final storeName = merchant['storeName'] ?? 'Unknown Store';
    final description = merchant['shortDescription'] ?? '';
    final contactNumber = merchant['contactNumber'] ?? '';
    final categories = List<String>.from(merchant['categories'] ?? []);
    final storePhotoUrls = List<String>.from(merchant['storePhotoUrls'] ?? []);
    final distanceFormatted = merchant['distanceFormatted'] as String?;

    final isVerified = merchant['isVerified'] == true;

    final locationData = merchant['location'] ?? merchant['locationModel'];
    final latitude = locationData?['latitude']?.toDouble();
    final longitude = locationData?['longitude']?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── TOP ROW ───
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openStoreDetail(merchant),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: storePhotoUrls.isNotEmpty
                      ? Image.network(
                    storePhotoUrls[0],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImagePlaceholder();
                    },
                  )
                      : _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store name + Verified badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            storeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 80,
                            height: 22,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(11),
                              color: Colors.transparent,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/Step/techMember.PNG',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        size: 12,
                                        color: Color(0xFF2E7D32),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (categories.isNotEmpty)
                      Text(
                        categories.take(3).join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryCyan,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),

                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── PHONE + DISTANCE + CALL ───
          Row(
            children: [
              const Icon(
                Icons.phone,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  contactNumber,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              if (distanceFormatted != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 10,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        distanceFormatted,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              GestureDetector(
                onTap: () => _makePhoneCall(contactNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF2E7D32),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.call,
                        size: 12,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Call',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── VIEW LOCATION + DIRECTIONS ───
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: latitude != null && longitude != null
                      ? () => _viewLocation(latitude, longitude)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: latitude != null && longitude != null
                            ? primaryCyan
                            : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: latitude != null && longitude != null
                              ? primaryCyan
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: latitude != null && longitude != null
                                ? primaryCyan
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: latitude != null && longitude != null
                      ? () => _getDirections(latitude, longitude)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: latitude != null && longitude != null
                            ? primaryCyan
                            : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.navigation_outlined,
                          size: 14,
                          color: latitude != null && longitude != null
                              ? primaryCyan
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Get Directions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: latitude != null && longitude != null
                                ? primaryCyan
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.store,
        size: 40,
        color: Colors.grey.shade400,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════
  Widget _buildFooterMessage() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: primaryCyan,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only stores within ${_radiusInKm.toInt()} km are shown. '
                  'Verified stores appear first, then non-verified.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}