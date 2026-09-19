// lib/widgets/location_picker_widget.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../Services/location_service.dart';
import '../../Services/places_service.dart'; // ✅ NEW
import '../../model/LocationModel.dart';

class LocationPickerWidget extends StatefulWidget {
  final Function(LocationModel) onLocationSelected;
  final LocationModel? initialLocation;
  final bool showCurrentLocationButton;

  const LocationPickerWidget({
    super.key,
    required this.onLocationSelected,
    this.initialLocation,
    this.showCurrentLocationButton = true,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  // ============= CONTROLLERS =============
  late GoogleMapController _mapController;
  final LocationService _locationService = LocationService();
  final PlacesService _placesService = PlacesService(); // ✅ NEW
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ============= STATE VARIABLES =============
  LatLng? _selectedLocation;
  LocationModel? _currentLocation;

  bool _isLoading = true;
  bool _isSelecting = false;
  bool _mapReady = false;
  bool _isSearching = false;
  bool _showSearchResults = false;
  bool _hasInternet = true;

  String _address = 'Loading address...';
  List<LocationModel> _searchResults = [];

  // ============= MAP MARKERS =============
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // ============= LIFECYCLE =============
  @override
  void initState() {
    super.initState();
    _checkInternetAndInitialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ============= INTERNET CHECK =============
  Future<bool> _checkInternetConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      _hasInternet = connectivityResult != ConnectivityResult.none;
      return _hasInternet;
    } catch (e) {
      print('❌ Internet check error: $e');
      _hasInternet = false;
      return false;
    }
  }

  Future<void> _checkInternetAndInitialize() async {
    await _checkInternetConnection();
    if (!_hasInternet) {
      setState(() => _isLoading = false);
      _showNoInternetDialog();
      return;
    }
    _initializeLocation();
  }

  // ============= INITIALIZATION =============
  Future<void> _initializeLocation() async {
    setState(() => _isLoading = true);

    try {
      if (widget.initialLocation != null) {
        _selectedLocation = LatLng(
          widget.initialLocation!.latitude,
          widget.initialLocation!.longitude,
        );
        _address = widget.initialLocation!.address ?? 'Selected location';
        _addMarker(_selectedLocation!);
      } else {
        LocationModel? location = await _locationService.getCurrentLocation();
        if (location != null) {
          _currentLocation = location;
          _selectedLocation = LatLng(location.latitude, location.longitude);
          _address = location.address ?? 'Current location';
          _addMarker(_selectedLocation!);
        } else {
          _selectedLocation = const LatLng(28.6139, 77.2090); // New Delhi
          _address = 'New Delhi, India';
          _addMarker(_selectedLocation!);
          _fetchAddressForDefaultLocation();
        }
      }
    } catch (e) {
      print('❌ Error initializing location: $e');
      _selectedLocation = const LatLng(30.3753, 69.3451);
      _address = 'Pakistan';
      _addMarker(_selectedLocation!);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchAddressForDefaultLocation() async {
    try {
      String address = await _locationService.getAddressFromCoordinates(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      if (address != 'Unknown location') {
        setState(() => _address = address);
      }
    } catch (e) {
      print('❌ Error fetching address: $e');
    }
  }

  // ============= MARKER FUNCTIONS =============
  void _addMarker(LatLng position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: 'Selected Location',
          snippet: _address,
        ),
      ),
    );

    _circles.clear();
    _circles.add(
      Circle(
        circleId: const CircleId('selected_circle'),
        center: position,
        radius: 50,
        fillColor: Colors.blue.withOpacity(0.1),
        strokeColor: Colors.blue.withOpacity(0.5),
        strokeWidth: 2,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅✅✅ SEARCH FUNCTION - UPDATED (Places API New)
  // ═══════════════════════════════════════════════════════
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    // ✅ Check internet
    bool hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      _showNoInternetSnackBar();
      setState(() => _isSearching = false);
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      print('🔍 Searching: "$query"');

      // ✅ Places API (New) se search
      List<LocationModel> results =
      await _placesService.searchPlaces(query);

      if (results.isEmpty) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        _showSnackBar(
          'No results for "$query". Try a different search.',
          Colors.orange,
        );
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      print('✅ ${results.length} results shown');
    } catch (e) {
      print('❌ Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });

      String message = _getErrorMessage(e);
      _showSnackBar(message, Colors.red);
    }
  }

  String _getErrorMessage(dynamic e) {
    String error = e.toString().toLowerCase();
    if (error.contains('timeout'))
      return 'Search timed out. Check your connection.';
    if (error.contains('api') || error.contains('denied'))
      return 'Places API not configured. Check Google Cloud Console.';
    if (error.contains('network') || error.contains('socket'))
      return 'Network error. Check your connection.';
    if (error.contains('quota') || error.contains('limit'))
      return 'API quota exceeded. Try again later.';
    if (error.contains('zero_results') || error.contains('no result'))
      return 'Location not found. Try a different name.';
    return 'Search failed. Please try again.';
  }

  // ============= SELECT FUNCTIONS =============
  void _selectSearchResult(LocationModel location) {
    LatLng position = LatLng(location.latitude, location.longitude);
    setState(() {
      _selectedLocation = position;
      _address = location.address ?? 'Selected location';
      _showSearchResults = false;
      _searchController.clear();
      _searchFocusNode.unfocus();
      _addMarker(position);
    });
    _animateCamera(position);
  }

  Future<void> _selectLocation(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _address = 'Loading address...';
      _addMarker(position);
    });

    try {
      String address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() => _address = address);
      _updateMarkerWithAddress(position, address);
    } catch (e) {
      print('❌ Error getting address: $e');
      _updateMarkerWithAddress(position, 'Address unavailable');
    }
  }

  void _updateMarkerWithAddress(LatLng position, String address) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: 'Selected Location',
          snippet: address,
        ),
      ),
    );
    _animateCamera(position);
  }

  void _animateCamera(LatLng position) {
    try {
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 14),
        ),
      );
    } catch (e) {
      print('❌ Error animating camera: $e');
    }
  }

  // ============= LOCATION FUNCTIONS =============
  Future<void> _goToCurrentLocation() async {
    setState(() => _isSelecting = true);

    try {
      bool hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        _showNoInternetSnackBar();
        setState(() => _isSelecting = false);
        return;
      }

      LocationModel? location = await _locationService.getCurrentLocation();
      if (location != null) {
        LatLng position = LatLng(location.latitude, location.longitude);
        await _selectLocation(position);
      } else {
        _showSnackBar('Could not get current location', Colors.orange);
      }
    } catch (e) {
      print('❌ Error getting current location: $e');
      _showSnackBar('Error getting location: $e', Colors.red);
    } finally {
      setState(() => _isSelecting = false);
    }
  }

  void _confirmLocation() {
    if (_selectedLocation == null) {
      _showSnackBar('Please select a location first', Colors.orange);
      return;
    }

    setState(() => _isSelecting = true);

    try {
      LocationModel location = LocationModel(
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        address: _address,
        placeName: _address.split(',').first.trim(),
        timestamp: DateTime.now(),
      );
      widget.onLocationSelected(location);
    } catch (e) {
      print('❌ Error confirming location: $e');
      _showSnackBar('Error: $e', Colors.red);
      setState(() => _isSelecting = false);
    }
  }

  // ============= UI HELPERS =============
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNoInternetSnackBar() {
    _showSnackBar(
      'No internet connection. Please check your network.',
      Colors.red,
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('No Internet'),
          ],
        ),
        content: const Text(
          'Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _checkInternetAndInitialize();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============= BUILD (SAME AS BEFORE) =============
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading map...'),
          ],
        ),
      );
    }

    if (!_hasInternet) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Please connect to the internet and try again',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkInternetAndInitialize,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_selectedLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Unable to load map',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkInternetAndInitialize,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedLocation!,
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            setState(() => _mapReady = true);
            print('✅ Map created');
          },
          onTap: _selectLocation,
          markers: _markers,
          circles: _circles,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          mapType: MapType.normal,
          compassEnabled: true,
          zoomControlsEnabled: false,
          padding: EdgeInsets.only(
            bottom: 120,
            top: kToolbarHeight + 80,
          ),
        ),

        // ===== SEARCH BAR =====
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildSearchBar(),
        ),

        // ===== SEARCH RESULTS =====
        if (_showSearchResults)
          Positioned(
            top: kToolbarHeight + 60,
            left: 8,
            right: 8,
            child: _buildSearchResults(),
          ),

        // ===== CENTER PIN =====
        Positioned(
          top: MediaQuery.of(context).size.height * 0.30,
          left: 0,
          right: 0,
          child: const IgnorePointer(
            child: Icon(
              Icons.location_pin,
              color: Colors.red,
              size: 50,
            ),
          ),
        ),

        // ===== BOTTOM SHEET =====
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomSheet(),
        ),
      ],
    );
  }

  // ============= UI COMPONENTS =============
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search any place, shop, city...', // ✅ Updated
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchResults = [];
                      _showSearchResults = false;
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (query) {
                if (query.length >= 2) {
                  _searchLocation(query);
                } else {
                  setState(() {
                    _searchResults = [];
                    _showSearchResults = false;
                  });
                }
              },
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  _searchFocusNode.unfocus();
                  _searchLocation(query);
                }
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isSearching) {
      return _buildNoResultsWidget();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final location = _searchResults[index];
          return Card(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: Colors.grey, width: 0.3),
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blue),
              title: Text(
                location.placeName ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                location.address ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
              onTap: () => _selectSearchResult(location),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'No locations found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            'Try searching for a different place',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedLocation != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.showCurrentLocationButton)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSelecting ? null : _goToCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Current'),
                  ),
                ),
              if (widget.showCurrentLocationButton) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSelecting ? null : _confirmLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSelecting
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
                      Icon(Icons.check, size: 18),
                      SizedBox(width: 4),
                      Text('Confirm Location'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Search, drag map or tap to select location',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}