import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  Driver({
    required this.id,
    required this.name,
    required this.online,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final bool online;
  final Timestamp? lastSeen;

  factory Driver.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Driver(
      id: doc.id,
      name: data['name']?.toString() ?? doc.id,
      online: data['online'] as bool? ?? false,
      lastSeen: data['lastSeen'] as Timestamp?,
    );
  }
}
