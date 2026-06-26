import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dispatch_app/features/drivers/screens/home_screen.dart';
import 'package:dispatch_app/features/notifications/services/notification_service.dart';
import 'package:dispatch_app/features/auth/screens/login_screen.dart';
import 'package:dispatch_app/features/tasks/screens/firestore_test_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? 'New task';
  final body = message.notification?.body ?? 'You have been assigned a task.';
  await NotificationService.instance.showSimpleNotification(title, body);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Firebase.initializeApp();
    await NotificationService.instance.init();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
  }

  runApp(const DispatchApp());
}

class DispatchApp extends StatefulWidget {
  const DispatchApp({super.key});

  @override
  State<DispatchApp> createState() => _DispatchAppState();
}

class _DispatchAppState extends State<DispatchApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title ?? 'New task';
        final body =
            message.notification?.body ?? 'You have been assigned a task.';
        NotificationService.instance.showSimpleNotification(title, body);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final taskId = message.data['taskId'];
        if (taskId != null) {
          NotificationService.instance.onNotificationTap?.call(taskId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Dispatch App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const FirestoreTestScreen(),
    );
  }
}

class LoginScreenWrapper extends StatelessWidget {
  const LoginScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const LoginScreen();
  }
}
