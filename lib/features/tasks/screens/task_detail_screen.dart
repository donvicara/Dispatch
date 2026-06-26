import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dispatch_app/core/models/task.dart';
import 'package:dispatch_app/shared/constants/status.dart';
import 'package:dispatch_app/features/tasks/services/task_service.dart';
import 'package:dispatch_app/features/map/services/map_launcher.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.currentDriverId,
  });

  final String taskId;
  final String? currentDriverId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: TaskService.getTaskById(taskId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load task details.'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final task = Task.fromDocument(snapshot.data!);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.address,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Customer: ${task.client}'),
                Text('Phone: ${task.phone}'),
                const SizedBox(height: 8),
                Text('Status: ${statusLabels[task.status] ?? task.status}'),
                const SizedBox(height: 8),
                Text('Assigned driver: ${task.driverId}'),
                const SizedBox(height: 12),
                Text(task.notes.isEmpty ? 'No notes' : task.notes),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                      onPressed: () => _launchNavigation(task.lat, task.lng),
                    ),
                    const SizedBox(width: 12),
                    if (currentDriverId == task.driverId)
                      ElevatedButton(
                        onPressed: () => _changeStatus(context, task),
                        child: Text(_detailActionLabel(task.status)),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _detailActionLabel(String status) {
    switch (status) {
      case 'new':
        return 'Accept';
      case 'accepted':
        return 'Arrived';
      case 'arrived':
        return 'Completed';
      default:
        return 'Done';
    }
  }

  Future<void> _changeStatus(BuildContext context, Task task) async {
    final nextStatus = {
      'new': 'accepted',
      'accepted': 'arrived',
      'arrived': 'completed',
    }[task.status];
    if (nextStatus == null) return;
    await TaskService.updateTaskStatus(task.id, nextStatus);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task status updated.')));
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    await MapLauncher.launchNavigation(lat, lng);
  }
}
