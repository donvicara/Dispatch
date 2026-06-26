import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dispatch_app/features/drivers/services/driver_service.dart';
import 'package:dispatch_app/features/notifications/services/notification_service.dart';
import 'package:dispatch_app/features/drivers/screens/driver_dashboard.dart';
import 'package:dispatch_app/features/drivers/screens/dispatcher_dashboard.dart';
import 'package:dispatch_app/features/auth/screens/login_screen.dart';
import 'package:dispatch_app/features/tasks/screens/task_detail_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userId,
    required this.isDispatcher,
  });

  final String userId;
  final bool isDispatcher;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _ensureDrivers();
    if (!widget.isDispatcher) {
      _setDriverPresence();
      NotificationService.instance.onNotificationTap = _openTaskById;
    }
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    if (!widget.isDispatcher) {
      NotificationService.instance.onNotificationTap = null;
    }
    super.dispose();
  }

  Future<void> _ensureDrivers() async {
    await DriverService.ensureDrivers();
  }

  void _setDriverPresence() {
    final driverName = widget.userId.replaceFirst('driver', 'Driver ');
    DriverService.setDriverPresence(widget.userId, driverName);
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      DriverService.updateDriverPresence(widget.userId);
    });
  }

  void _openTaskById(String taskId) {
    final route = MaterialPageRoute(
      builder: (_) => TaskDetailScreenWrapper(
        taskId: taskId,
        currentDriverId: widget.isDispatcher ? null : widget.userId,
      ),
    );
    navigatorKey.currentState?.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return widget.isDispatcher
        ? DispatcherDashboard(onLogout: () => _logout(context))
        : DriverDashboard(
            driverId: widget.userId,
            onLogout: () => _logout(context),
          );
  }

  void _logout(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
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
