import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:dispatch_app/features/tasks/services/task_service.dart';

class FirestoreTestScreen extends StatefulWidget {
  const FirestoreTestScreen({super.key});

  @override
  State<FirestoreTestScreen> createState() => _FirestoreTestScreenState();
}

class _FirestoreTestScreenState extends State<FirestoreTestScreen> {
  String _status =
      'Tap the button to run the Android Firebase MVP flow (create → read → update statuses).';
  bool _running = false;

  Future<void> _runTaskServiceFirestoreTest() async {
    setState(() {
      _running = true;
      _status = 'Initializing Firebase and Firestore...';
    });

    try {
      await Firebase.initializeApp();

      final createdDoc = await TaskService.createTask(
        address: 'Firestore MVP test address',
        client: 'Android probe',
        phone: '0000000000',
        notes: 'Created from the Android Firebase MVP test flow',
        lat: 0.0,
        lng: 0.0,
        driverId: 'driver1',
      );

      setState(() {
        _status = 'Task created. Checking dispatcher and driver streams...';
      });

      final directRead = await TaskService.getTaskById(createdDoc.id).first;
      final dispatcherSnapshot = await TaskService.getAllTasks().first;
      final driverSnapshot = await TaskService.getTasksByDriver(
        'driver1',
      ).first;

      if (!directRead.exists) {
        throw StateError('Created task was not found on direct read.');
      }

      final dispatcherContainsTask = dispatcherSnapshot.docs.any(
        (doc) => doc.id == createdDoc.id,
      );
      final driverContainsTask = driverSnapshot.docs.any(
        (doc) => doc.id == createdDoc.id,
      );

      if (!dispatcherContainsTask || !driverContainsTask) {
        throw StateError(
          'Task was not visible in both dispatcher and driver streams.',
        );
      }

      await TaskService.updateTaskStatus(createdDoc.id, 'accepted');
      await TaskService.updateTaskStatus(createdDoc.id, 'arrived');
      await TaskService.updateTaskStatus(createdDoc.id, 'completed');

      final finalSnapshot = await TaskService.getTaskById(createdDoc.id).first;
      final finalStatus =
          (finalSnapshot.data() as Map<String, dynamic>?)?['status']
              ?.toString() ??
          'unknown';

      setState(() {
        _status =
            'Firebase MVP flow succeeded.\nTask id: ${createdDoc.id}\nFinal status: $finalStatus\nDispatcher + driver streams both saw the task.';
      });
    } on FirebaseException catch (e) {
      setState(() {
        _status = 'Firestore error: ${e.code}: ${e.message ?? 'No details'}';
      });
    } catch (e) {
      setState(() {
        _status = 'Unexpected error: $e';
      });
    } finally {
      setState(() {
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firestore test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This screen runs the Android Firebase MVP flow through TaskService.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _running ? null : _runTaskServiceFirestoreTest,
                child: Text(_running ? 'Testing...' : 'Run Firestore test'),
              ),
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
