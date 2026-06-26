import 'package:cloud_firestore/cloud_firestore.dart';

class TaskService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get tasksRef =>
      _firestore.collection('tasks');

  static Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await tasksRef.doc(taskId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<DocumentReference<Map<String, dynamic>>> createTask({
    required String address,
    required String client,
    required String phone,
    required String notes,
    required double lat,
    required double lng,
    required String driverId,
  }) async {
    return tasksRef.add({
      'address': address,
      'client': client,
      'phone': phone,
      'notes': notes,
      'lat': lat,
      'lng': lng,
      'driverId': driverId,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> getTasksByDriver(String driverId) {
    return tasksRef
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getAllTasks() {
    return tasksRef.orderBy('createdAt', descending: true).snapshots();
  }

  static Stream<DocumentSnapshot> getTaskById(String taskId) {
    return tasksRef.doc(taskId).snapshots();
  }
}
