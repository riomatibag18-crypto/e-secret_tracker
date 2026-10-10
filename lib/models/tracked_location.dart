import 'package:cloud_firestore/cloud_firestore.dart';

class TrackedLocation {
  const TrackedLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.ebikeId,
    required this.geofenceZoneId,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? ebikeId;
  final String? geofenceZoneId;

  factory TrackedLocation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final ts = data['timestamp'] as Timestamp?;
    return TrackedLocation(
      id: snapshot.id,
      latitude: ((data['latitude'] as num?) ?? 0).toDouble(),
      longitude: ((data['longitude'] as num?) ?? 0).toDouble(),
      timestamp: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      ebikeId: data['ebikeId'] as String?,
      geofenceZoneId: data['geofenceZoneId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'ebikeId': ebikeId,
      'geofenceZoneId': geofenceZoneId,
    };
  }
}
