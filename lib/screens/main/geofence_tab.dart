import 'dart:async';
import 'dart:convert';

import 'package:e_secret_tracker/config/mapbox_config.dart';
import 'package:e_secret_tracker/models/geofence_zone.dart';
import 'package:e_secret_tracker/services/user_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class GeofenceTab extends StatefulWidget {
  const GeofenceTab({super.key});

  @override
  State<GeofenceTab> createState() => _GeofenceTabState();
}

class _GeofenceTabState extends State<GeofenceTab> {
  final _userDataService = UserDataService();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _modalBackground =>
    _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFDFDFD);

  Color get _modalSurface =>
    _isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F4);

  Color get _modalBorder =>
    _isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);

  Color get _modalTextPrimary =>
    _isDark ? Colors.white : const Color(0xFF1A1A1A);

  Color get _modalTextSecondary =>
    _isDark ? const Color(0xFFB8B8B8) : const Color(0xFF666666);

  static final _fallbackCenter = Point(
    coordinates: Position(121.0437, 14.6760),
  );

  Future<List<_GeocodeResult>> _searchLocations(String query) async {
    final token = effectiveMapboxAccessToken;
    if (query.trim().isEmpty || token.isEmpty) {
      return const <_GeocodeResult>[];
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(query.trim())}.json',
      {'access_token': token, 'limit': '5', 'autocomplete': 'true'},
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return const <_GeocodeResult>[];
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      return const <_GeocodeResult>[];
    }

    final features = body['features'];
    if (features is! List) {
      return const <_GeocodeResult>[];
    }

    return features
        .whereType<Map<String, dynamic>>()
        .map((feature) {
          final center = feature['center'];
          if (center is! List || center.length < 2) {
            return null;
          }

          final lng = (center[0] as num?)?.toDouble();
          final lat = (center[1] as num?)?.toDouble();
          if (lat == null || lng == null) {
            return null;
          }

          final placeName = (feature['place_name'] as String?)?.trim() ?? '';
          if (placeName.isEmpty) {
            return null;
          }

          return _GeocodeResult(
            name: placeName,
            point: Point(coordinates: Position(lng, lat)),
          );
        })
        .whereType<_GeocodeResult>()
        .toList(growable: false);
  }

  static InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8E8E8E)),
      prefixIcon: Icon(icon, color: const Color(0xFF8E8E8E)),
      filled: true,
      fillColor: const Color(0xFF262626),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF8A2A)),
      ),
    );
  }

  Future<void> _deleteZone(String zoneId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await _userDataService.deleteGeofenceZone(uid: user.uid, zoneId: zoneId);
  }

  Future<Point> _resolveCurrentLocationPoint() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _fallbackCenter;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return _fallbackCenter;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      return Point(
        coordinates: Position(position.longitude, position.latitude),
      );
    } catch (_) {
      return _fallbackCenter;
    }
  }

  Future<void> _openAddZoneSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: _modalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddGeofenceZoneSheet(
        backgroundColor: _modalBackground,
        surfaceColor: _modalSurface,
        borderColor: _modalBorder,
        primaryTextColor: _modalTextPrimary,
        secondaryTextColor: _modalTextSecondary,
      ),
    );
  }

  Widget _buildCard(GeofenceZone zone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final border = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryText = isDark
        ? const Color(0xFF8E8E8E)
        : const Color(0xFF666666);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A2A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B231A),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFFFF8A2A),
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            zone.address,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF8E8E8E),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Radius: ${zone.radius}',
                      style: TextStyle(color: secondaryText, fontSize: 16),
                    ),
                    const Spacer(),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A2323),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: () => _deleteZone(zone.id),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFFF4D3D),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                if (zone.centerLatitude != null && zone.centerLongitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Center: ${zone.centerLatitude!.toStringAsFixed(6)}, ${zone.centerLongitude!.toStringAsFixed(6)}',
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<GeofenceZone> zones) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryText = isDark
        ? const Color(0xFF8E8E8E)
        : const Color(0xFF666666);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Text(
            'Geofence Zones',
            style: TextStyle(
              color: primaryText,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: zones.isEmpty
                ? Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            'No geofence zones yet. Add one to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _openAddZoneSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 30,
                          ),
                          label: const Text(
                            'Add New Zone',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: zones.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == zones.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton.icon(
                              onPressed: _openAddZoneSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8A2A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 30,
                              ),
                              label: const Text(
                                'Add New Zone',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return _buildCard(zones[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFF4F4F4);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: user == null
            ? const Center(
                child: Text(
                  'Sign in to manage your geofence zones.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : StreamBuilder<List<GeofenceZone>>(
                stream: _userDataService.watchGeofenceZones(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF8A2A),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load your zones.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return _buildContent(snapshot.data ?? const <GeofenceZone>[]);
                },
              ),
      ),
    );
  }
}

class _GeocodeResult {
  const _GeocodeResult({required this.name, required this.point});

  final String name;
  final Point point;
}

Future<Point> _resolveGeofenceLocationPoint() async {
  try {
    final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _GeofenceTabState._fallbackCenter;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return _GeofenceTabState._fallbackCenter;
    }

    final position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    return Point(coordinates: Position(position.longitude, position.latitude));
  } catch (_) {
    return _GeofenceTabState._fallbackCenter;
  }
}

Future<List<_GeocodeResult>> _searchGeofenceLocations(String query) async {
  final token = effectiveMapboxAccessToken;
  if (query.trim().isEmpty || token.isEmpty) {
    return const <_GeocodeResult>[];
  }

  final uri = Uri.https(
    'api.mapbox.com',
    '/geocoding/v5/mapbox.places/${Uri.encodeComponent(query.trim())}.json',
    {'access_token': token, 'limit': '5', 'autocomplete': 'true'},
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    return const <_GeocodeResult>[];
  }

  final body = jsonDecode(response.body);
  if (body is! Map<String, dynamic>) {
    return const <_GeocodeResult>[];
  }

  final features = body['features'];
  if (features is! List) {
    return const <_GeocodeResult>[];
  }

  return features
      .whereType<Map<String, dynamic>>()
      .map((feature) {
        final center = feature['center'];
        if (center is! List || center.length < 2) {
          return null;
        }

        final lng = (center[0] as num?)?.toDouble();
        final lat = (center[1] as num?)?.toDouble();
        if (lat == null || lng == null) {
          return null;
        }

        final placeName = (feature['place_name'] as String?)?.trim() ?? '';
        if (placeName.isEmpty) {
          return null;
        }

        return _GeocodeResult(
          name: placeName,
          point: Point(coordinates: Position(lng, lat)),
        );
      })
      .whereType<_GeocodeResult>()
      .toList(growable: false);
}

class _AddGeofenceZoneSheet extends StatefulWidget {
  const _AddGeofenceZoneSheet({
    required this.backgroundColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  @override
  State<_AddGeofenceZoneSheet> createState() => _AddGeofenceZoneSheetState();
}

class _AddGeofenceZoneSheetState extends State<_AddGeofenceZoneSheet> {
  final _userDataService = UserDataService();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _radiusController = TextEditingController();
  final _searchController = TextEditingController();

  Timer? _searchDebounce;
  int _searchRequestSerial = 0;
  bool _alertEnabled = true;
  bool _isSearching = false;
  bool _isLoadingLocation = true;
  List<_GeocodeResult> _searchResults = const <_GeocodeResult>[];
  Point _selectedPoint = _GeofenceTabState._fallbackCenter;
  MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
    _loadInitialPoint();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPoint() async {
    final point = await _resolveGeofenceLocationPoint();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPoint = point;
      _isLoadingLocation = false;
    });

    _flyMapToSelectedPoint();
  }

  void _flyMapToSelectedPoint() {
    _mapboxMap?.flyTo(
      CameraOptions(center: _selectedPoint, zoom: 15),
      MapAnimationOptions(duration: 350),
    );
  }

  Future<void> _triggerSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchResults = const <_GeocodeResult>[];
      });
      return;
    }

    final requestId = ++_searchRequestSerial;
    setState(() {
      _isSearching = true;
    });

    final results = await _searchGeofenceLocations(trimmedQuery);
    if (!mounted || requestId != _searchRequestSerial) {
      return;
    }

    setState(() {
      _isSearching = false;
      _searchResults = results;
    });
  }

  Future<void> _saveZone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final radiusText = _radiusController.text.trim();
    final radiusMeters = double.tryParse(radiusText);

    if (name.isEmpty || radiusMeters == null || radiusMeters <= 0) {
      return;
    }

    await _userDataService.addGeofenceZone(
      uid: user.uid,
      zone: GeofenceZone(
        id: '',
        name: name,
        address: address.isEmpty ? 'Pinned map location' : address,
        radius: '${radiusMeters.toStringAsFixed(0)} m',
        centerLatitude: _selectedPoint.coordinates.lat.toDouble(),
        centerLongitude: _selectedPoint.coordinates.lng.toDouble(),
        alertEnabled: _alertEnabled,
        createdAt: null,
      ),
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.borderColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add New Zone',
              style: TextStyle(
                color: widget.primaryTextColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MapWidget(
                      key: const ValueKey('geofence-map-picker'),
                      styleUri: MapboxStyles.STANDARD,
                      cameraOptions: CameraOptions(
                        center: _selectedPoint,
                        zoom: 15,
                      ),
                      onMapCreated: (controller) {
                        _mapboxMap = controller;
                        if (!_isLoadingLocation) {
                          _flyMapToSelectedPoint();
                        }
                      },
                      onCameraChangeListener: (eventData) {
                        _selectedPoint = eventData.cameraState.center;
                      },
                      onMapIdleListener: (_) {
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF3A3A3A),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: widget.primaryTextColor),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search location',
                                hintStyle: TextStyle(
                                  color: widget.secondaryTextColor,
                                ),
                                filled: true,
                                fillColor: widget.surfaceColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: widget.borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: widget.borderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF8A2A),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFFF8A2A),
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.search,
                                          color: Color(0xFFFF8A2A),
                                        ),
                                        onPressed: () async {
                                          await _triggerSearch(
                                            _searchController.text,
                                          );
                                        },
                                      ),
                              ),
                              onChanged: (value) {
                                _searchDebounce?.cancel();
                                _searchDebounce = Timer(
                                  const Duration(milliseconds: 450),
                                  () {
                                    _triggerSearch(value);
                                  },
                                );
                              },
                              onSubmitted: (_) async {
                                await _triggerSearch(_searchController.text);
                              },
                            ),
                          ),
                          if (_searchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: widget.surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: widget.borderColor),
                              ),
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFF2C2C2C),
                                ),
                                itemBuilder: (context, index) {
                                  final result = _searchResults[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      result.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: widget.primaryTextColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedPoint = result.point;
                                        _addressController.text = result.name;
                                        _searchResults =
                                            const <_GeocodeResult>[];
                                      });
                                      _flyMapToSelectedPoint();
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Align(
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.place,
                        color: Color(0xFFFF4D3D),
                        size: 34,
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.backgroundColor.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isLoadingLocation
                              ? 'Finding current location...'
                              : 'Drag map to place pin at center\nLat: ${_selectedPoint.coordinates.lat.toStringAsFixed(6)}  Lng: ${_selectedPoint.coordinates.lng.toStringAsFixed(6)}',
                          style: TextStyle(
                            color: widget.primaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              style: TextStyle(color: widget.primaryTextColor),
              decoration: _GeofenceTabState._inputDecoration(
                'Zone name',
                Icons.home_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _addressController,
              style: TextStyle(color: widget.primaryTextColor),
              decoration: _GeofenceTabState._inputDecoration(
                'Address',
                Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _radiusController,
              style: TextStyle(color: widget.primaryTextColor),
              keyboardType: TextInputType.number,
              decoration: _GeofenceTabState._inputDecoration(
                'Radius in meters (e.g. 100)',
                Icons.tune,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.borderColor),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Enable alerts',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  Switch(
                    value: _alertEnabled,
                    activeColor: const Color(0xFFFF8A2A),
                    onChanged: (value) {
                      setState(() {
                        _alertEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveZone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add Zone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
