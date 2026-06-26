import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dispatch_app/core/models/driver.dart';
import 'package:dispatch_app/core/models/task.dart';
import 'package:dispatch_app/shared/constants/status.dart';
import 'package:dispatch_app/features/drivers/services/driver_service.dart';
import 'package:dispatch_app/features/tasks/services/task_service.dart';
import 'package:dispatch_app/features/tasks/screens/create_task_screen.dart';

class DispatcherDashboard extends StatefulWidget {
  const DispatcherDashboard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<DispatcherDashboard> createState() => _DispatcherDashboardState();
}

class _DispatcherDashboardState extends State<DispatcherDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatcher Dashboard'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: TaskService.getAllTasks(),
              builder: (context, taskSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: DriverService.getAllDrivers(),
                  builder: (context, driverSnapshot) {
                    if (taskSnapshot.hasError || driverSnapshot.hasError) {
                      return const Center(child: Text('Failed to load data.'));
                    }
                    if (!taskSnapshot.hasData || !driverSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final drivers = driverSnapshot.data!.docs
                        .map((doc) => Driver.fromDocument(doc))
                        .toList();
                    final driverMap = {
                      for (var driver in drivers) driver.id: driver,
                    };
                    final tasks = taskSnapshot.data!.docs
                        .map((doc) => Task.fromDocument(doc))
                        .toList();
                    final activeTasks = tasks
                        .where((task) => task.status != 'completed')
                        .length;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active tasks: $activeTasks',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Drivers',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...drivers.map((driver) {
                            final lastSeen = driver.lastSeen != null
                                ? DateTime.fromMillisecondsSinceEpoch(
                                    driver.lastSeen!.millisecondsSinceEpoch,
                                  )
                                : null;
                            return Card(
                              child: ListTile(
                                title: Text(driver.name),
                                subtitle: Text(
                                  driver.online ? 'Online' : 'Offline',
                                ),
                                trailing: Text(
                                  lastSeen != null
                                      ? 'Seen ${_formatRelative(lastSeen)}'
                                      : 'No recent activity',
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          Text(
                            'Tasks',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (tasks.isEmpty)
                            const Text('No tasks created yet.'),
                          ...tasks.map((task) {
                            final driverName =
                                driverMap[task.driverId]?.name ?? task.driverId;
                            return Card(
                              child: ListTile(
                                title: Text(task.address),
                                subtitle: Text(
                                  '$driverName · ${statusLabels[task.status] ?? task.status}',
                                ),
                                trailing: Text(
                                  task.createdAt != null
                                      ? _formatTime(task.createdAt!.toDate())
                                      : '',
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelative(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _openCreateTask() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateTaskScreen()));
  }
}
