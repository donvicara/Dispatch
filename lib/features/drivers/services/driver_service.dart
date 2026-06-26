import 'package:cloud_firestore/cloud_firestore.dart';

class DriverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get driversRef =>
      _firestore.collection('drivers');

  static Future<void> ensureDrivers() async {
    final driverDefinitions = [
      {'id': 'driver1', 'name': 'Driver 1'},
      {'id': 'driver2', 'name': 'Driver 2'},
      {'id': 'driver3', 'name': 'Driver 3'},
    ];
    for (final driver in driverDefinitions) {
      final doc = driversRef.doc(driver['id']);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        await doc.set({
          'name': driver['name'],
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static Future<void> setDriverPresence(
    String driverId,
    String driverName,
  ) async {
    final driverDoc = driversRef.doc(driverId);
    await driverDoc.set({
      'name': driverName,
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateDriverPresence(String driverId) async {
    await driversRef.doc(driverId).update({
      'lastSeen': FieldValue.serverTimestamp(),
      'online': true,
    });
  }

  static Stream<QuerySnapshot> getAllDrivers() {
    return driversRef.orderBy('name').snapshots();
  }
}
