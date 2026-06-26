import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dispatch_app/core/models/task.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  void Function(String payload)? onNotificationTap;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap?.call(payload);
        }
      },
    );
    const channel = AndroidNotificationChannel(
      'dispatch_tasks',
      'Dispatch tasks',
      description: 'Task assignment and driver updates',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> showTaskNotification(Task task) async {
    await _plugin.show(
      id: task.id.hashCode,
      title: 'New Task assigned',
      body: task.address,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'dispatch_tasks',
          'Dispatch tasks',
          channelDescription: 'Task assignment and driver updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: task.id,
    );
  }

  Future<void> showSimpleNotification(String title, String body) async {
    await _plugin.show(
      id: title.hashCode ^ body.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'dispatch_tasks',
          'Dispatch tasks',
          channelDescription: 'Task assignment and driver updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
