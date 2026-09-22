// lib/screens/location_picker_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../Services/firestore_location_service.dart';
import '../../Services/location_service.dart';
import '../../Services/places_service.dart';
import '../../model/LocationModel.dart';

class LocationPickerScreen extends StatefulWidget {
  final String userId;
  final String? purpose;
  final LocationModel? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.userId,
    this.purpose,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // ═══════════════════════════════════════════════════════
  // SERVICES
  // ═══════════════════════════════════════════════════════
  final FirestoreLocationService _firestoreService = FirestoreLocationService();
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService();

  // ✅ Geocoding 5.x uses an instance
  final Geocoding _geocoding = Geocoding();

  // ═══════════════════════════════════════════════════════
  // CONTROLLERS
  // ═══════════════════════════════════════════════════════
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();
  GoogleMapController? _mapController;

  // ═══════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════
  LatLng? _selectedLatLng;
  LatLng _cameraCenter = const LatLng(30.3753, 69.3451);

  String _address = 'Tap on map to select location';
  String _placeName = '';

  bool _isLoadingLocation = true;
  bool _isSaving = false;
  bool _isSearching = false;
  bool _isGeocodingAddress = false;
  bool _showSearchResults = false;
  bool _hasInternet = true;

  List<LocationModel> _searchResults = [];

  // ═══════════════════════════════════════════════════════
  // MARKERS
  // ═══════════════════════════════════════════════════════
  final Set<Marker> _markers = {};

  Timer? _debounce;

  // ═══════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _initLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _sheetController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // INTERNET
  // ═══════════════════════════════════════════════════════
  Future<bool> _checkInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _hasInternet = result != ConnectivityResult.none;
      return _hasInternet;
    } catch (_) {
      _hasInternet = false;
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════
  // INIT LOCATION
  // ═══════════════════════════════════════════════════════
  Future<void> _initLocation() async {
    await _checkInternet();

    if (!_hasInternet) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _showSnack('No internet connection', Colors.red);
      return;
    }

    try {
      // ═══════════════════════════════════════════════════
      // INITIAL LOCATION PROVIDED
      // ═══════════════════════════════════════════════════
      if (widget.initialLocation != null) {
        final pos = LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );

        _selectedLatLng = pos;
        _cameraCenter = pos;
        _address = widget.initialLocation!.address ?? 'Selected location';
        _placeName = widget.initialLocation!.placeName ?? '';

        _addMarker(pos);

        if (!mounted) return;
        setState(() => _isLoadingLocation = false);
        return;
      }

      // ═══════════════════════════════════════════════════
      // GET CURRENT LOCATION
      // ═══════════════════════════════════════════════════
      final currentLoc = await _locationService.getCurrentLocation();

      if (currentLoc != null) {
        final pos = LatLng(currentLoc.latitude, currentLoc.longitude);
        _cameraCenter = pos;

        // Marker intentionally not added.
        // User must tap on map to select location.
        //
        // If you want current location selected by default,
        // uncomment these:
        //
        // _selectedLatLng = pos;
        // _address = currentLoc.address ?? 'Current location';
        // _placeName = currentLoc.placeName ?? '';
        // _addMarker(pos);
      }
    } catch (e) {
      debugPrint('❌ init error: $e');
    }

    if (!mounted) return;
    setState(() => _isLoadingLocation = false);
  }

  // ═══════════════════════════════════════════════════════
  // ADD MARKER
  // ═══════════════════════════════════════════════════════
  void _addMarker(LatLng position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: _placeName.isNotEmpty ? _placeName : 'Selected',
          snippet: _address,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════
  // MAP TAP
  // ═══════════════════════════════════════════════════════
  Future<void> _onMapTap(LatLng position) async {
    HapticFeedback.selectionClick();

    if (!mounted) return;

    setState(() {
      _selectedLatLng = position;
      _address = 'Finding address...';
      _placeName = '';
      _isGeocodingAddress = true;
    });

    // Marker immediately moves
    _addMarker(position);

    // Reverse geocode
    await _reverseGeocode(position);
  }

  // ═══════════════════════════════════════════════════════
  // REVERSE GEOCODING
  // ═══════════════════════════════════════════════════════
  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;

    setState(() => _isGeocodingAddress = true);

    try {
      // ✅ Geocoding 5.x API
      final placemarks = await _geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final parts = <String>[
          if (p.street != null && p.street!.trim().isNotEmpty)
            p.street!.trim(),
          if (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
            p.subLocality!.trim(),
          if (p.locality != null && p.locality!.trim().isNotEmpty)
            p.locality!.trim(),
          if (p.administrativeArea != null &&
              p.administrativeArea!.trim().isNotEmpty)
            p.administrativeArea!.trim(),
          if (p.country != null && p.country!.trim().isNotEmpty)
            p.country!.trim(),
        ];

        _address =
        parts.isNotEmpty ? parts.join(', ') : 'Selected location';

        _placeName = (p.locality != null && p.locality!.trim().isNotEmpty)
            ? p.locality!.trim()
            : (p.subLocality != null && p.subLocality!.trim().isNotEmpty)
            ? p.subLocality!.trim()
            : (_address.split(',').first.trim());
      } else {
        _address = 'Selected location';
        _placeName = '';
      }
    } catch (e) {
      debugPrint('❌ reverse geocode error: $e');
      _address = 'Selected location';
      _placeName = '';
    }

    if (!mounted) return;

    // Update marker info window
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: InfoWindow(
          title: _placeName.isNotEmpty ? _placeName : 'Selected',
          snippet: _address,
        ),
      ),
    );

    setState(() => _isGeocodingAddress = false);
  }

  // ═══════════════════════════════════════════════════════
  // SEARCH LISTENER
  // ═══════════════════════════════════════════════════════
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = _searchController.text.trim();

      if (q.length >= 2) {
        _searchLocation(q);
      } else {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // SEARCH LOCATION
  // ═══════════════════════════════════════════════════════
  Future<void> _searchLocation(String query) async {
    if (!await _checkInternet()) {
      _showSnack('No internet connection', Colors.red);
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final results = await _placesService.searchPlaces(query);

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('❌ search error: $e');

      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching = false;
      });

      _showSnack('Search failed. Try again.', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // SELECT SEARCH RESULT
  // ═══════════════════════════════════════════════════════
  void _selectSearchResult(LocationModel loc) {
    _searchFocusNode.unfocus();

    final pos = LatLng(loc.latitude, loc.longitude);

    setState(() {
      _showSearchResults = false;
      _searchController.clear();
      _searchResults = [];
      _selectedLatLng = pos;
      _address = loc.address ?? 'Selected';
      _placeName = loc.placeName ?? '';
    });

    _addMarker(pos);
    _moveCamera(pos);
  }

  // ═══════════════════════════════════════════════════════
  // MOVE CAMERA
  // ═══════════════════════════════════════════════════════
  void _moveCamera(LatLng pos) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // CURRENT LOCATION
  // ═══════════════════════════════════════════════════════
  Future<void> _goToCurrentLocation() async {
    if (!await _checkInternet()) {
      _showSnack('No internet connection', Colors.red);
      return;
    }

    try {
      HapticFeedback.mediumImpact();

      final loc = await _locationService.getCurrentLocation();

      if (loc != null) {
        final pos = LatLng(loc.latitude, loc.longitude);

        if (!mounted) return;

        setState(() {
          _selectedLatLng = pos;
          _address = loc.address ?? 'Current location';
          _placeName = loc.placeName ?? '';
        });

        _addMarker(pos);
        _moveCamera(pos);
      } else {
        _showSnack('Could not get current location', Colors.orange);
      }
    } catch (e) {
      debugPrint('❌ current loc error: $e');
      _showSnack('Error: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // SAVE LOCATION
  // ═══════════════════════════════════════════════════════
  Future<void> _confirmLocation() async {
    if (_selectedLatLng == null) {
      _showSnack('Please tap on map to select location', Colors.orange);
      return;
    }

    if (widget.userId.isEmpty) {
      _showSnack('User not logged in', Colors.red);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final location = LocationModel(
        latitude: _selectedLatLng!.latitude,
        longitude: _selectedLatLng!.longitude,
        address: _address,
        placeName: _placeName.isNotEmpty
            ? _placeName
            : _address.split(',').first.trim(),
        timestamp: DateTime.now(),
      );

      final ok = await _firestoreService.saveUserLocation(
        userId: widget.userId,
        location: location,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (ok) {
        _showSnack('✅ Location saved!', Colors.green);
        Navigator.pop(context, location);
      } else {
        _showSnack('❌ Failed to save', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('❌ Error: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════
  // SNACKBAR
  // ═══════════════════════════════════════════════════════
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final title = widget.purpose != null
        ? "Select ${widget.purpose!.replaceAll('_', ' ')}"
        : 'Select Location';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey.shade100,
      body: Stack(
        children: [
          // ═══════════════════════════════════════════════
          // MAP
          // ═══════════════════════════════════════════════
          _isLoadingLocation
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _cameraCenter,
              zoom: 16,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTap,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 140, bottom: 320),
          ),

          // ═══════════════════════════════════════════════
          // TOP SEARCH BAR
          // ═══════════════════════════════════════════════
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: _buildSearchBar(title),
          ),

          // ═══════════════════════════════════════════════
          // SEARCH RESULTS
          // ═══════════════════════════════════════════════
          if (_showSearchResults)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 12,
              right: 12,
              child: _buildSearchResults(),
            ),

          // ═══════════════════════════════════════════════
          // CURRENT LOCATION BUTTON
          // ═══════════════════════════════════════════════
          Positioned(
            right: 16,
            bottom: 340,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              elevation: 3,
              mini: true,
              child: const Icon(Icons.my_location),
            ),
          ),

          // ═══════════════════════════════════════════════
          // BOTTOM SHEET
          // ═══════════════════════════════════════════════
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.32,
            minChildSize: 0.20,
            maxChildSize: 0.75,
            snap: true,
            snapSizes: const [0.32, 0.55, 0.75],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDragHandle(),
                    _buildAddressCard(),
                    _buildActionButtons(),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildSearchBar(String title) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) _searchLocation(q.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search place, shop, city...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _showSearchResults = false;
                });
              },
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.search, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SEARCH RESULTS
  // ═══════════════════════════════════════════════════════
  Widget _buildSearchResults() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: _searchResults.isEmpty && !_isSearching
            ? const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.search_off, color: Colors.grey),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No results found. Try a different search.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        )
            : ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),
          itemBuilder: (_, i) {
            final loc = _searchResults[i];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
              ),
              title: Text(
                loc.placeName ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                loc.address ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _selectSearchResult(loc),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // DRAG HANDLE
  // ═══════════════════════════════════════════════════════
  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ADDRESS CARD
  // ═══════════════════════════════════════════════════════
  Widget _buildAddressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DELIVERING TO',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedLatLng != null
                      ? Colors.blue.shade50
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: _selectedLatLng != null
                      ? Colors.blue.shade700
                      : Colors.grey.shade500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _selectedLatLng == null
                    ? Text(
                  'Tap on map to select your location',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                )
                    : _isGeocodingAddress
                    ? Row(
                  children: [
                    const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Finding address...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _placeName.isNotEmpty
                          ? _placeName
                          : 'Selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_selectedLatLng!.latitude.toStringAsFixed(5)}, '
                          'Lng: ${_selectedLatLng!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ═══════════════════════════════════════════════════════
  Widget _buildActionButtons() {
    final enabled = _selectedLatLng != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                _showSnack(
                  'Tap anywhere on map to select location',
                  Colors.blue,
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.touch_app, size: 18),
              label: const Text('Adjust'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: (_isSaving || !enabled) ? null : _confirmLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled
                    ? Colors.blue.shade700
                    : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Confirm Location',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}