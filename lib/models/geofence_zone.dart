import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceZone {
  const GeofenceZone({
    required this.id,
    required this.name,
    required this.address,
    required this.radius,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.alertEnabled,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final String radius;
  final double? centerLatitude;
  final double? centerLongitude;
  final bool alertEnabled;
  final DateTime? createdAt;

  factory GeofenceZone.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return GeofenceZone(
      id: snapshot.id,
      name: (data['name'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      radius: (data['radius'] as String?) ?? '',
      centerLatitude: (data['centerLatitude'] as num?)?.toDouble(),
      centerLongitude: (data['centerLongitude'] as num?)?.toDouble(),
      alertEnabled: (data['alertEnabled'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'radius': radius,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'alertEnabled': alertEnabled,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
