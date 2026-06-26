import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dispatch_app/core/models/driver.dart';
import 'package:dispatch_app/core/models/task.dart';
import 'package:dispatch_app/features/tasks/services/task_service.dart';
import 'package:dispatch_app/features/drivers/services/driver_service.dart';
import 'package:dispatch_app/features/notifications/services/notification_service.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final addressController = TextEditingController();
  final clientController = TextEditingController();
  final phoneController = TextEditingController();
  final notesController = TextEditingController();
  String? _selectedDriverId;
  LatLng _marker = const LatLng(54.6872, 25.2797);

  @override
  void dispose() {
    addressController.dispose();
    clientController.dispose();
    phoneController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: StreamBuilder<QuerySnapshot>(
        stream: DriverService.getAllDrivers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load drivers'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final drivers = snapshot.data!.docs
              .map((doc) => Driver.fromDocument(doc))
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Vilniaus St. 10',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Customer Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: clientController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Jonas',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Phone Number',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '+370...',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Notes',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Call before arrival',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Driver',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDriverId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: drivers
                      .map(
                        (driver) => DropdownMenuItem(
                          value: driver.id,
                          child: Text(driver.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedDriverId = value),
                  hint: const Text('Select a driver'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tap on the map to place the task',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 280,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _marker,
                      zoom: 14,
                    ),
                    onTap: (position) => setState(() => _marker = position),
                    markers: {
                      Marker(
                        markerId: const MarkerId('taskMarker'),
                        position: _marker,
                        draggable: true,
                        onDragEnd: (position) =>
                            setState(() => _marker = position),
                      ),
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Selected coordinates: ${_marker.latitude.toStringAsFixed(6)}, ${_marker.longitude.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveTask,
                    child: const Text('Create Task'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveTask() async {
    final address = addressController.text.trim();
    final client = clientController.text.trim();
    final phone = phoneController.text.trim();
    final notes = notesController.text.trim();
    if (address.isEmpty ||
        client.isEmpty ||
        phone.isEmpty ||
        _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    final newTask = await TaskService.createTask(
      address: address,
      client: client,
      phone: phone,
      notes: notes,
      lat: _marker.latitude,
      lng: _marker.longitude,
      driverId: _selectedDriverId!,
    );

    final snapshot = await newTask.get();
    final task = Task.fromDocument(snapshot);
    if (mounted) {
      NotificationService.instance.showTaskNotification(task);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully.')),
      );
      Navigator.of(context).pop();
    }
  }
}
