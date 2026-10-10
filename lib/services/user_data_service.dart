import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_secret_tracker/models/ebike.dart';
import 'package:e_secret_tracker/models/geofence_zone.dart';
import 'package:e_secret_tracker/models/tracked_location.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDataService {
  UserDataService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _geofenceCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('geofence_zones');
  }

  CollectionReference<Map<String, dynamic>> _ebikeCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('ebikes');
  }

  CollectionReference<Map<String, dynamic>> _trackedLocationCollection(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).collection('tracked_locations');
  }

  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String email,
    String? photoBase64,
  }) {
    return _userDocument(uid).set({
      'fullName': fullName,
      'email': email,
      ...(photoBase64 == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'photoBase64': photoBase64}),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    required String email,
    String? photoBase64,
  }) {
    return _userDocument(uid).set({
      'fullName': fullName,
      'email': email,
      ...(photoBase64 == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'photoBase64': photoBase64}),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    return _userDocument(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<void> addGeofenceZone({
    required String uid,
    required GeofenceZone zone,
  }) {
    return _geofenceCollection(uid).add(zone.toFirestore());
  }

  Future<void> deleteGeofenceZone({
    required String uid,
    required String zoneId,
  }) {
    return _geofenceCollection(uid).doc(zoneId).delete();
  }

  Stream<List<GeofenceZone>> watchGeofenceZones(String uid) {
    return _geofenceCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(GeofenceZone.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> addEbike({
    required String uid,
    required Ebike ebike,
  }) {
    return _ebikeCollection(uid).add(ebike.toFirestore());
  }

  Future<void> deleteEbike({
    required String uid,
    required String ebikeId,
  }) {
    return _ebikeCollection(uid).doc(ebikeId).delete();
  }

  Future<void> setEbikeKillSwitchState({
    required String uid,
    required String ebikeId,
    required bool isTurnedOff,
  }) {
    return _ebikeCollection(uid).doc(ebikeId).set({
      'isTurnedOff': isTurnedOff,
      'turnedOffAt': isTurnedOff ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
  }

  Stream<List<Ebike>> watchEbikes(String uid) {
    return _ebikeCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Ebike.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> addTrackedLocation({
    required String uid,
    required TrackedLocation location,
  }) {
    return _trackedLocationCollection(uid).add(location.toFirestore());
  }

  Stream<List<TrackedLocation>> watchTrackedLocations({
    required String uid,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? ebikeId,
  }) {
    Query<Map<String, dynamic>> query = _trackedLocationCollection(uid)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(rangeEnd));

    if (ebikeId != null && ebikeId.isNotEmpty) {
      query = query.where('ebikeId', isEqualTo: ebikeId);
    }

    return query
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(TrackedLocation.fromFirestore)
              .toList(growable: false),
        );
  }
}
