import 'package:cloud_firestore/cloud_firestore.dart';

class Ebike {
  const Ebike({
    required this.id,
    required this.name,
    required this.note,
    required this.isTurnedOff,
    required this.turnedOffAt,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String note;
  final bool isTurnedOff;
  final DateTime? turnedOffAt;
  final DateTime? createdAt;

  factory Ebike.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Ebike(
      id: snapshot.id,
      name: (data['name'] as String?) ?? '',
      note: (data['note'] as String?) ?? '',
      isTurnedOff: (data['isTurnedOff'] as bool?) ?? false,
      turnedOffAt: (data['turnedOffAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'note': note,
      'isTurnedOff': isTurnedOff,
      'turnedOffAt': turnedOffAt == null
          ? null
          : Timestamp.fromDate(turnedOffAt!),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
