import 'dart:async';

import 'package:e_secret_tracker/models/ebike.dart';
import 'package:e_secret_tracker/models/geofence_zone.dart';
import 'package:e_secret_tracker/models/tracked_location.dart';
import 'package:e_secret_tracker/screens/main/ebike_tab.dart';
import 'package:e_secret_tracker/screens/main/geofence_tab.dart';
import 'package:e_secret_tracker/screens/main/notification_tab.dart';
import 'package:e_secret_tracker/screens/main/settings_tab.dart';
import 'package:e_secret_tracker/services/user_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class HomeTab extends StatefulWidget {
	const HomeTab({super.key});

	@override
	State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
	int _selectedIndex = 0;

	late final List<Widget> _tabs = <Widget>[
		const _HomeContent(),
		const NotificationTab(),
		const GeofenceTab(),
		const EbikeTab(),
		const SettingsTab(),
	];

	@override
	Widget build(BuildContext context) {
		final isDark = Theme.of(context).brightness == Brightness.dark;
		final navBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
		final navUnselected = isDark ? const Color(0xFF7A7A7A) : const Color(0xFF6E6E6E);

		return Scaffold(
			body: IndexedStack(
				index: _selectedIndex,
				children: _tabs,
			),
			bottomNavigationBar: BottomNavigationBar(
				currentIndex: _selectedIndex,
				onTap: (index) {
					setState(() {
						_selectedIndex = index;
					});
				},
				type: BottomNavigationBarType.fixed,
				backgroundColor: navBg,
				selectedItemColor: const Color(0xFFFF8A2A),
				unselectedItemColor: navUnselected,
				showSelectedLabels: true,
				showUnselectedLabels: true,
				elevation: 0,
				items: const [
					BottomNavigationBarItem(
						icon: Icon(Icons.home_outlined),
						activeIcon: Icon(Icons.home),
						label: 'Home',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.notifications_none),
						activeIcon: Icon(Icons.notifications_active),
						label: 'Alerts',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.location_on_outlined),
						activeIcon: Icon(Icons.location_on),
						label: 'Geofence',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.electric_bike_outlined),
						activeIcon: Icon(Icons.electric_bike),
						label: 'E-bike',
					),
					BottomNavigationBarItem(
						icon: Icon(Icons.settings_outlined),
						activeIcon: Icon(Icons.settings),
						label: 'Settings',
					),
				],
			),
		);
	}
}

class _HomeContent extends StatefulWidget {
	const _HomeContent();

	@override
	State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
	final _userDataService = UserDataService();

	final _fallbackCamera = CameraOptions(
		center: Point(coordinates: Position(121.0437, 14.6760)),
		zoom: 13.5,
	);

	bool _isTracking = false;
	CameraOptions? _locationCamera;
	MapboxMap? _mapboxMap;
	CircleAnnotationManager? _circleAnnotationManager;
	PolylineAnnotationManager? _polylineAnnotationManager;
	StreamSubscription<geo.Position>? _trackingSubscription;

	String? _selectedGeofenceId;
	String? _selectedEbikeId;
	DateTime _selectedDate = DateTime.now();
	TimeOfDay _startTimeFilter = const TimeOfDay(hour: 0, minute: 0);
	TimeOfDay _endTimeFilter = const TimeOfDay(hour: 23, minute: 59);
	List<TrackedLocation> _currentTracks = const <TrackedLocation>[];
	List<TrackedLocation> _latestFetchedTracks = const <TrackedLocation>[];
	String _lastRenderedOverlayKey = '';

	@override
	void initState() {
		super.initState();
		_initializeCameraToCurrentLocation();
	}

	@override
	void dispose() {
		_trackingSubscription?.cancel();
		super.dispose();
	}

	String _formatDate(DateTime value) {
		final month = value.month.toString().padLeft(2, '0');
		final day = value.day.toString().padLeft(2, '0');
		return '${value.year}-$month-$day';
	}

	String _formatTime(TimeOfDay value) {
		final hour = value.hour.toString().padLeft(2, '0');
		final minute = value.minute.toString().padLeft(2, '0');
		return '$hour:$minute';
	}

	DateTime _dateWithTime(TimeOfDay value) {
		return DateTime(
			_selectedDate.year,
			_selectedDate.month,
			_selectedDate.day,
			value.hour,
			value.minute,
		);
	}

	DateTime get _rangeStart => _dateWithTime(_startTimeFilter);

	DateTime get _rangeEnd {
		final end = _dateWithTime(_endTimeFilter);
		if (!end.isAfter(_rangeStart)) {
			return _rangeStart.add(const Duration(minutes: 1));
		}
		return end;
	}

	void _ensureValidSelections(
		List<GeofenceZone> zones,
		List<Ebike> ebikes,
	) {
		String? nextGeofenceId = _selectedGeofenceId;
		if (nextGeofenceId != null && !zones.any((z) => z.id == nextGeofenceId)) {
			nextGeofenceId = null;
		}

		String? nextEbikeId = _selectedEbikeId;
		if (nextEbikeId != null && !ebikes.any((e) => e.id == nextEbikeId)) {
			nextEbikeId = null;
		}

		if (nextGeofenceId != _selectedGeofenceId ||
			nextEbikeId != _selectedEbikeId) {
			WidgetsBinding.instance.addPostFrameCallback((_) {
				if (!mounted) {
					return;
				}
				setState(() {
					_selectedGeofenceId = nextGeofenceId;
					_selectedEbikeId = nextEbikeId;
				});
			});
		}
	}

	Future<void> _initializeCameraToCurrentLocation() async {
		try {
			final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
			if (!serviceEnabled) {
				return;
			}

			var permission = await geo.Geolocator.checkPermission();
			if (permission == geo.LocationPermission.denied) {
				permission = await geo.Geolocator.requestPermission();
			}

			if (permission == geo.LocationPermission.denied ||
				permission == geo.LocationPermission.deniedForever) {
				return;
			}

			final position = await geo.Geolocator.getCurrentPosition(
				desiredAccuracy: geo.LocationAccuracy.high,
			);
			if (!mounted) {
				return;
			}

			setState(() {
				_locationCamera = CameraOptions(
					center: Point(
						coordinates: Position(position.longitude, position.latitude),
					),
					zoom: 15.5,
				);
			});

			final targetCamera = _locationCamera;
			if (targetCamera != null) {
				_mapboxMap?.flyTo(
					targetCamera,
				MapAnimationOptions(duration: 400),
				);
			}
		} catch (_) {
			// Keep fallback camera if location acquisition fails.
		}
	}

	Future<void> _centerToCurrentLocation() async {
		await _initializeCameraToCurrentLocation();
	}

	Future<void> _recenterToTrack() async {
		if (_mapboxMap == null) {
			return;
		}

		if (_currentTracks.isNotEmpty) {
			final last = _currentTracks.last;
			await _mapboxMap!.flyTo(
				CameraOptions(
					center: Point(
						coordinates: Position(last.longitude, last.latitude),
					),
					zoom: 15.5,
				),
				MapAnimationOptions(duration: 400),
			);
			return;
		}

		await _centerToCurrentLocation();
	}

	Future<void> _centerToSelectedGeofence(List<GeofenceZone> zones) async {
		if (_mapboxMap == null) {
			return;
		}

		if (_selectedGeofenceId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Select a geofence first.')),
			);
			return;
		}

		GeofenceZone? zone;
		for (final item in zones) {
			if (item.id == _selectedGeofenceId) {
				zone = item;
				break;
			}
		}
		if (zone == null || zone.centerLatitude == null || zone.centerLongitude == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Selected geofence has no center coordinates.')),
			);
			return;
		}

		await _mapboxMap!.flyTo(
			CameraOptions(
				center: Point(
					coordinates: Position(zone.centerLongitude!, zone.centerLatitude!),
				),
				zoom: 16,
			),
			MapAnimationOptions(duration: 400),
		);
	}

	Future<void> _centerToSelectedEbike() async {
		if (_mapboxMap == null) {
			return;
		}

		if (_selectedEbikeId == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Select an e-bike first.')),
			);
			return;
		}

		final pointsForEbike = _latestFetchedTracks
			.where((track) => track.ebikeId == _selectedEbikeId)
			.toList(growable: false);
		if (pointsForEbike.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No tracked points found for selected e-bike in this time range.')),
			);
			return;
		}

		final latest = pointsForEbike.last;
		await _mapboxMap!.flyTo(
			CameraOptions(
				center: Point(
					coordinates: Position(latest.longitude, latest.latitude),
				),
				zoom: 16,
			),
			MapAnimationOptions(duration: 400),
		);
	}

	Future<void> _ensureAnnotationManagers() async {
		if (_mapboxMap == null) {
			return;
		}

		_circleAnnotationManager ??=
			await _mapboxMap!.annotations.createCircleAnnotationManager();
		_polylineAnnotationManager ??=
			await _mapboxMap!.annotations.createPolylineAnnotationManager();
	}

	String _buildOverlayKey(List<TrackedLocation> tracks) {
		if (tracks.isEmpty) {
			return '${_formatDate(_selectedDate)}-${_formatTime(_startTimeFilter)}-${_formatTime(_endTimeFilter)}-${_selectedGeofenceId ?? 'all-zones'}-${_selectedEbikeId ?? 'all-ebikes'}-0';
		}

		final first = tracks.first.timestamp.millisecondsSinceEpoch;
		final last = tracks.last.timestamp.millisecondsSinceEpoch;
		return '${_formatDate(_selectedDate)}-${_formatTime(_startTimeFilter)}-${_formatTime(_endTimeFilter)}-${_selectedGeofenceId ?? 'all-zones'}-${_selectedEbikeId ?? 'all-ebikes'}-${tracks.length}-$first-$last';
	}

	void _scheduleTrackOverlayRender(List<TrackedLocation> tracks) {
		final key = _buildOverlayKey(tracks);
		if (_lastRenderedOverlayKey == key) {
			return;
		}

		_lastRenderedOverlayKey = key;
		WidgetsBinding.instance.addPostFrameCallback((_) {
			_renderTrackOverlay(tracks);
		});
	}

	Future<void> _renderTrackOverlay(List<TrackedLocation> tracks) async {
		await _ensureAnnotationManagers();
		if (_circleAnnotationManager == null || _polylineAnnotationManager == null) {
			return;
		}

		await _circleAnnotationManager!.deleteAll();
		await _polylineAnnotationManager!.deleteAll();

		if (tracks.isEmpty) {
			return;
		}

		if (tracks.length > 1) {
			final polylineGeometry = LineString(
				coordinates: tracks
					.map((p) => Position(p.longitude, p.latitude))
					.toList(growable: false),
			);

			await _polylineAnnotationManager!.create(
				PolylineAnnotationOptions(
					geometry: polylineGeometry,
					lineColor: 0xFFFF8A2A,
					lineWidth: 4,
				),
			);
		}

		final step = tracks.length > 150 ? (tracks.length / 150).ceil() : 1;
		final circleOptions = <CircleAnnotationOptions>[];
		for (var i = 0; i < tracks.length; i += step) {
			final track = tracks[i];
			circleOptions.add(
				CircleAnnotationOptions(
					geometry: Point(
						coordinates: Position(track.longitude, track.latitude),
					),
					circleRadius: 4,
					circleColor: 0xFFFF8A2A,
					circleStrokeColor: 0xFFFFFFFF,
					circleStrokeWidth: 1,
				),
			);
		}

		if (circleOptions.isNotEmpty) {
			await _circleAnnotationManager!.createMulti(circleOptions);
		}
	}

	Future<void> _showDatePickerDialog() async {
		final selected = await showDatePicker(
			context: context,
			initialDate: _selectedDate,
			firstDate: DateTime(2020),
			lastDate: DateTime.now().add(const Duration(days: 1)),
		);

		if (selected == null || !mounted) {
			return;
		}

		setState(() {
			_selectedDate = selected;
			_lastRenderedOverlayKey = '';
		});
	}

	Future<void> _showTimePickerDialog({required bool isStart}) async {
		final selected = await showTimePicker(
			context: context,
			initialTime: isStart ? _startTimeFilter : _endTimeFilter,
		);

		if (selected == null || !mounted) {
			return;
		}

		setState(() {
			if (isStart) {
				_startTimeFilter = selected;
			} else {
				_endTimeFilter = selected;
			}
			_lastRenderedOverlayKey = '';
		});
	}

	Future<void> _startTracking(String uid) async {
		_trackingSubscription?.cancel();

		final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
		if (!serviceEnabled) {
			return;
		}

		var permission = await geo.Geolocator.checkPermission();
		if (permission == geo.LocationPermission.denied) {
			permission = await geo.Geolocator.requestPermission();
		}

		if (permission == geo.LocationPermission.denied ||
			permission == geo.LocationPermission.deniedForever) {
			return;
		}

		_trackingSubscription = geo.Geolocator.getPositionStream(
			locationSettings: const geo.LocationSettings(
				accuracy: geo.LocationAccuracy.high,
				distanceFilter: 8,
			),
		).listen((position) {
			_userDataService.addTrackedLocation(
				uid: uid,
				location: TrackedLocation(
					id: '',
					latitude: position.latitude,
					longitude: position.longitude,
					timestamp: DateTime.now(),
					ebikeId: _selectedEbikeId,
					geofenceZoneId: _selectedGeofenceId,
				),
			);
		});
	}

	Future<void> _stopTracking() async {
		await _trackingSubscription?.cancel();
		_trackingSubscription = null;
	}

	Future<void> _handleTrackingPressed(String uid) async {
		if (_isTracking) {
			await _stopTracking();
		} else {
			await _startTracking(uid);
		}

		if (!mounted) {
			return;
		}

		setState(() {
			_isTracking = !_isTracking;
		});

		final label = _isTracking ? 'Tracking started' : 'Tracking stopped';
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(label),
				duration: const Duration(seconds: 2),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final isDark = Theme.of(context).brightness == Brightness.dark;
		final bg = isDark ? const Color(0xFF111111) : const Color(0xFFF4F4F4);
		final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
		final border = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);
		final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
		final secondaryText = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF666666);

		final user = FirebaseAuth.instance.currentUser;

		if (user == null) {
			return const Scaffold(
				backgroundColor: Color(0xFF111111),
				body: SafeArea(
					child: Center(
						child: Text(
							'Sign in to view dashboard map.',
							style: TextStyle(color: Colors.white),
						),
					),
				),
			);
		}

		return Scaffold(
			backgroundColor: bg,
			body: SafeArea(
				child: StreamBuilder<List<GeofenceZone>>(
					stream: _userDataService.watchGeofenceZones(user.uid),
					builder: (context, zonesSnapshot) {
						final zones = zonesSnapshot.data ?? const <GeofenceZone>[];
						return StreamBuilder<List<Ebike>>(
							stream: _userDataService.watchEbikes(user.uid),
							builder: (context, ebikesSnapshot) {
								final ebikes = ebikesSnapshot.data ?? const <Ebike>[];
								_ensureValidSelections(zones, ebikes);

								return StreamBuilder<List<TrackedLocation>>(
									stream: _userDataService.watchTrackedLocations(
										uid: user.uid,
										rangeStart: _rangeStart,
										rangeEnd: _rangeEnd,
										ebikeId: _selectedEbikeId,
									),
									builder: (context, tracksSnapshot) {
										final fetchedTracks =
											tracksSnapshot.data ?? const <TrackedLocation>[];
										_latestFetchedTracks = fetchedTracks;
										if (_selectedGeofenceId == null) {
											_currentTracks = fetchedTracks;
										} else {
											_currentTracks = fetchedTracks
												.where(
													(track) =>
														track.geofenceZoneId == _selectedGeofenceId,
												)
												.toList(growable: false);
										}
										_scheduleTrackOverlayRender(_currentTracks);

										return Padding(
											padding: const EdgeInsets.all(20),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text(
														'Home',
														style: TextStyle(
															color: primaryText,
															fontSize: 28,
															fontWeight: FontWeight.w500,
														),
													),
													const SizedBox(height: 12),
													Container(
														width: double.infinity,
														padding: const EdgeInsets.all(16),
														decoration: BoxDecoration(
															color: cardBg,
															borderRadius: BorderRadius.circular(18),
															border: Border.all(color: border),
														),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																DropdownButtonFormField<String?>(
																	value: _selectedGeofenceId,
																	isExpanded: true,
																	decoration: InputDecoration(
																		labelText: 'Geofence Filter',
																		labelStyle: TextStyle(color: secondaryText),
																		filled: true,
																		fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8F8F8),
																		border: OutlineInputBorder(
																			borderRadius: BorderRadius.circular(12),
																		),
																	),
																	items: [
																		const DropdownMenuItem<String?>(
																			value: null,
																			child: Text('All Geofences'),
																		),
																		...zones.map(
																			(zone) => DropdownMenuItem<String?>(
																				value: zone.id,
																				child: Text(zone.name),
																			),
																		),
																	],
																	onChanged: (value) {
																		setState(() {
																			_selectedGeofenceId = value;
																			_lastRenderedOverlayKey = '';
																		});
																	},
																),
																const SizedBox(height: 10),
																DropdownButtonFormField<String?>(
																	value: _selectedEbikeId,
																	isExpanded: true,
																	decoration: InputDecoration(
																		labelText: 'E-bike Filter',
																		labelStyle: TextStyle(color: secondaryText),
																		filled: true,
																		fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF8F8F8),
																		border: OutlineInputBorder(
																			borderRadius: BorderRadius.circular(12),
																		),
																	),
																	items: [
																		const DropdownMenuItem<String?>(
																			value: null,
																			child: Text('All E-bikes'),
																		),
																		...ebikes.map(
																			(ebike) => DropdownMenuItem<String?>(
																				value: ebike.id,
																				child: Text(ebike.name),
																			),
																		),
																	],
																	onChanged: (value) {
																		setState(() {
																			_selectedEbikeId = value;
																			_lastRenderedOverlayKey = '';
																		});
																	},
																),
																const SizedBox(height: 10),
																SizedBox(
																	width: double.infinity,
																	child: OutlinedButton.icon(
																		onPressed: _showDatePickerDialog,
																		icon: const Icon(Icons.calendar_today),
																		label: Text('Date: ${_formatDate(_selectedDate)}'),
																		style: OutlinedButton.styleFrom(
																			foregroundColor: primaryText,
																			side: BorderSide(color: border),
																		),
																	),
																),
																const SizedBox(height: 8),
																Row(
																	children: [
																		Expanded(
																			child: OutlinedButton.icon(
																				onPressed: () =>
																					_showTimePickerDialog(isStart: true),
																				icon: const Icon(Icons.schedule),
																				label: Text('From ${_formatTime(_startTimeFilter)}'),
																				style: OutlinedButton.styleFrom(
																					foregroundColor: primaryText,
																					side: BorderSide(color: border),
																				),
																			),
																		),
																		const SizedBox(width: 8),
																		Expanded(
																			child: OutlinedButton.icon(
																				onPressed: () =>
																					_showTimePickerDialog(isStart: false),
																				icon: const Icon(Icons.schedule),
																				label: Text('To ${_formatTime(_endTimeFilter)}'),
																				style: OutlinedButton.styleFrom(
																					foregroundColor: primaryText,
																					side: BorderSide(color: border),
																				),
																			),
																		),
																	],
																),
																const SizedBox(height: 6),
																Text(
																	'Track points for selected date/time: ${_currentTracks.length}',
																	style: TextStyle(
																		color: secondaryText,
																		fontSize: 12,
																	),
																),
															],
														),
													),
													const SizedBox(height: 14),
													Expanded(
														child: ClipRRect(
															borderRadius: BorderRadius.circular(22),
															child: Stack(
																fit: StackFit.expand,
																children: [
																	MapWidget(
																		key: const ValueKey('dashboard-mapbox-map'),
																		cameraOptions: _locationCamera ?? _fallbackCamera,
																		styleUri: MapboxStyles.STANDARD,
																		onMapCreated: (map) {
																			_mapboxMap = map;
																			_scheduleTrackOverlayRender(_currentTracks);
																		},
																	),
																	Positioned(
																		top: 14,
																		right: 14,
																		child: Column(
																			children: [
																				FloatingActionButton.small(
																					heroTag: 'home-current-location-btn',
																					backgroundColor: cardBg,
																					onPressed: _centerToCurrentLocation,
																					child: const Icon(Icons.my_location),
																				),
																				const SizedBox(height: 10),
																				FloatingActionButton.small(
																					heroTag: 'home-recenter-track-btn',
																					backgroundColor: cardBg,
																					onPressed: _recenterToTrack,
																					child: const Icon(Icons.center_focus_strong),
																				),
																				const SizedBox(height: 10),
																				FloatingActionButton.small(
																					heroTag: 'home-center-geofence-btn',
																					backgroundColor: cardBg,
																					onPressed: () => _centerToSelectedGeofence(zones),
																					child: const Icon(Icons.location_searching),
																				),
																				const SizedBox(height: 10),
																				FloatingActionButton.small(
																					heroTag: 'home-center-ebike-btn',
																					backgroundColor: cardBg,
																					onPressed: _centerToSelectedEbike,
																					child: const Icon(Icons.electric_bike),
																				),
																			],
																		),
																	),
																	Positioned(
																		left: 14,
																		right: 14,
																		bottom: 14,
																		child: FilledButton.icon(
																			onPressed: () => _handleTrackingPressed(user.uid),
																			style: FilledButton.styleFrom(
																				backgroundColor: _isTracking
																					? const Color(0xFF444444)
																					: const Color(0xFFFF8A2A),
																				foregroundColor: Colors.white,
																				padding: const EdgeInsets.symmetric(vertical: 14),
																				shape: RoundedRectangleBorder(
																					borderRadius: BorderRadius.circular(14),
																				),
																			),
																			icon: Icon(
																				_isTracking ? Icons.pause_circle : Icons.play_arrow,
																			),
																			label: Text(
																				_isTracking ? 'Stop Tracking' : 'Start Tracking',
																			),
																		),
																	),
																],
															),
														),
													),
												],
											),
										);
									},
								);
							},
						);
					},
				),
			),
		);
	}
}
