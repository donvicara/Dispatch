import 'package:flutter/material.dart';
import 'package:dispatch_app/core/models/task.dart';
import 'package:dispatch_app/shared/constants/status.dart';
import 'package:dispatch_app/shared/models/task_action.dart';
import 'package:dispatch_app/features/map/services/map_launcher.dart';

class DriverTaskCard extends StatelessWidget {
  const DriverTaskCard({
    super.key,
    required this.task,
    required this.onStatusChanged,
  });

  final Task task;
  final Future<void> Function(Task task, String nextStatus) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final status = task.status;
    final nextAction = _nextAction(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusLabels[status] ?? status,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Chip(label: Text(task.driverId)),
              ],
            ),
            const SizedBox(height: 12),
            Text(task.address, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text('Customer: ${task.client}'),
            Text('Phone: ${task.phone}'),
            const SizedBox(height: 8),
            Text(task.notes.isEmpty ? 'No notes' : task.notes),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  onPressed: () => _openMaps(task.lat, task.lng, context),
                ),
                const SizedBox(width: 12),
                if (nextAction != null)
                  ElevatedButton(
                    onPressed: () => onStatusChanged(task, nextAction.value),
                    child: Text(nextAction.label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TaskAction? _nextAction(String status) {
    switch (status) {
      case 'new':
        return const TaskAction('Accept', 'accepted');
      case 'accepted':
        return const TaskAction('Arrived', 'arrived');
      case 'arrived':
        return const TaskAction('Completed', 'completed');
      default:
        return null;
    }
  }

  Future<void> _openMaps(double lat, double lng, BuildContext context) async {
    await MapLauncher.tryLaunchNavigation(
      lat,
      lng,
      onFailure: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch navigation.')),
          );
        }
      },
    );
  }
}
