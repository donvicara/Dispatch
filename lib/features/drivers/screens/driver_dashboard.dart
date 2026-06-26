import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dispatch_app/core/models/task.dart';
import 'package:dispatch_app/features/tasks/services/task_service.dart';
import 'package:dispatch_app/features/notifications/services/notification_service.dart';
import 'package:dispatch_app/shared/widgets/task_card.dart';
import 'package:dispatch_app/features/drivers/screens/home_screen.dart';
import 'package:dispatch_app/features/tasks/screens/task_detail_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({
    super.key,
    required this.driverId,
    required this.onLogout,
  });

  final String driverId;
  final VoidCallback onLogout;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final Set<String> _seenTaskIds = {};
  bool _initialized = false;
  late final StreamSubscription<QuerySnapshot> _taskSubscription;

  @override
  void initState() {
    super.initState();
    _taskSubscription = TaskService.getTasksByDriver(
      widget.driverId,
    ).listen(_onTaskSnapshot);
    NotificationService.instance.onNotificationTap = _handleNotificationTap;
  }

  @override
  void dispose() {
    NotificationService.instance.onNotificationTap = null;
    _taskSubscription.cancel();
    super.dispose();
  }

  void _onTaskSnapshot(QuerySnapshot snapshot) {
    final newTasks = snapshot.docs.map(Task.fromDocument).toList();
    if (!_initialized) {
      _seenTaskIds.addAll(newTasks.map((task) => task.id));
      _initialized = true;
      return;
    }
    for (final task in newTasks) {
      if (!_seenTaskIds.contains(task.id) && task.status == 'new') {
        NotificationService.instance.showTaskNotification(task);
      }
      _seenTaskIds.add(task.id);
    }
  }

  void _handleNotificationTap(String taskId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreenWrapper(
          taskId: taskId,
          currentDriverId: widget.driverId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: TaskService.getTasksByDriver(widget.driverId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load your tasks.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = snapshot.data!.docs.map(Task.fromDocument).toList();
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks assigned yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return DriverTaskCard(task: task, onStatusChanged: _updateStatus);
            },
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(Task task, String nextStatus) async {
    await TaskService.updateTaskStatus(task.id, nextStatus);
  }
}

class TaskDetailScreenWrapper extends StatelessWidget {
  const TaskDetailScreenWrapper({
    super.key,
    required this.taskId,
    this.currentDriverId,
  });

  final String taskId;
  final String? currentDriverId;

  @override
  Widget build(BuildContext context) {
    return TaskDetailScreen(taskId: taskId, currentDriverId: currentDriverId);
  }
}
