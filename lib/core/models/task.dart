import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  Task({
    required this.id,
    required this.address,
    required this.client,
    required this.phone,
    required this.notes,
    required this.lat,
    required this.lng,
    required this.driverId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String address;
  final String client;
  final String phone;
  final String notes;
  final double lat;
  final double lng;
  final String driverId;
  final String status;
  final Timestamp? createdAt;

  factory Task.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      address: data['address']?.toString() ?? '',
      client: data['client']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      driverId: data['driverId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'new',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
