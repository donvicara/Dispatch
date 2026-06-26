import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final title = message.notification?.title ?? 'New task';
  final body = message.notification?.body ?? 'You have been assigned a task.';
  await NotificationService.instance.showSimpleNotification(title, body);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.requestPermission();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Dispatch App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const LoginScreen(),
    );
  }
}

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
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
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
      task.id.hashCode,
      'New Task assigned',
      task.address,
      const NotificationDetails(
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
      title.hashCode ^ body.hashCode,
      title,
      body,
      const NotificationDetails(
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

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static final List<String> users = ['admin', 'driver1', 'driver2', 'driver3'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch App Login')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select your role',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...users.map((user) {
              final isDispatcher = user == 'admin';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HomeScreen(
                          userId: user,
                          isDispatcher: isDispatcher,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: Text(
                    isDispatcher ? 'Dispatcher (admin)' : 'Driver: $user',
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

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
  final driversRef = FirebaseFirestore.instance.collection('drivers');
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
    final driverDefinitions = [
      {'id': 'driver1', 'name': 'Driver 1'},
      {'id': 'driver2', 'name': 'Driver 2'},
      {'id': 'driver3', 'name': 'Driver 3'},
    ];
    for (final driver in driverDefinitions) {
      final doc = driversRef.doc(driver['id']);
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        await doc.set({
          'name': driver['name'],
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _setDriverPresence() {
    final driverDoc = driversRef.doc(widget.userId);
    driverDoc.set({
      'name': widget.userId.replaceFirst('driver', 'Driver '),
      'online': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      driverDoc.update({
        'lastSeen': FieldValue.serverTimestamp(),
        'online': true,
      });
    });
  }

  void _openTaskById(String taskId) {
    final route = MaterialPageRoute(
      builder: (_) => TaskDetailScreen(
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

class Driver {
  Driver({
    required this.id,
    required this.name,
    required this.online,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final bool online;
  final Timestamp? lastSeen;

  factory Driver.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Driver(
      id: doc.id,
      name: data['name']?.toString() ?? doc.id,
      online: data['online'] as bool? ?? false,
      lastSeen: data['lastSeen'] as Timestamp?,
    );
  }
}

class Task {
  Task({
    required this.id,
    required this.address,
    required this.client,
    required this.phone,
    required this.notes,
    required this.lat,
    required this.lng,
    required this.driverId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String address;
  final String client;
  final String phone;
  final String notes;
  final double lat;
  final double lng;
  final String driverId;
  final String status;
  final Timestamp? createdAt;

  factory Task.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      address: data['address']?.toString() ?? '',
      client: data['client']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      driverId: data['driverId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'new',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

const statusLabels = {
  'new': 'New',
  'accepted': 'Accepted',
  'arrived': 'Arrived',
  'completed': 'Completed',
};

class DispatcherDashboard extends StatefulWidget {
  const DispatcherDashboard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<DispatcherDashboard> createState() => _DispatcherDashboardState();
}

class _DispatcherDashboardState extends State<DispatcherDashboard> {
  final tasksRef = FirebaseFirestore.instance.collection('tasks');
  final driversRef = FirebaseFirestore.instance.collection('drivers');

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
              stream: tasksRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, taskSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: driversRef.orderBy('name').snapshots(),
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
    final driversStream = FirebaseFirestore.instance
        .collection('drivers')
        .orderBy('name')
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: StreamBuilder<QuerySnapshot>(
        stream: driversStream,
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

    final newTask = await FirebaseFirestore.instance.collection('tasks').add({
      'address': address,
      'client': client,
      'phone': phone,
      'notes': notes,
      'lat': _marker.latitude,
      'lng': _marker.longitude,
      'driverId': _selectedDriverId,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });

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
  final tasksRef = FirebaseFirestore.instance.collection('tasks');
  final Set<String> _seenTaskIds = {};
  bool _initialized = false;
  late final StreamSubscription<QuerySnapshot> _taskSubscription;

  @override
  void initState() {
    super.initState();
    _taskSubscription = tasksRef
        .where('driverId', isEqualTo: widget.driverId)
        .snapshots()
        .listen(_onTaskSnapshot);
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
        builder: (_) =>
            TaskDetailScreen(taskId: taskId, currentDriverId: widget.driverId),
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
        stream: tasksRef
            .where('driverId', isEqualTo: widget.driverId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
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
    await tasksRef.doc(task.id).update({
      'status': nextStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

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

  _TaskAction? _nextAction(String status) {
    switch (status) {
      case 'new':
        return const _TaskAction('Accept', 'accepted');
      case 'accepted':
        return const _TaskAction('Arrived', 'arrived');
      case 'arrived':
        return const _TaskAction('Completed', 'completed');
      default:
        return null;
    }
  }

  Future<void> _openMaps(double lat, double lng, BuildContext context) async {
    final googleUrl = Uri.parse('google.navigation:q=$lat,$lng');
    final browserUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(browserUrl)) {
      await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch navigation.')),
      );
    }
  }
}

class _TaskAction {
  const _TaskAction(this.label, this.value);

  final String label;
  final String value;
}

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
    final taskDoc = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: taskDoc.snapshots(),
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
    await FirebaseFirestore.instance.collection('tasks').doc(task.id).update({
      'status': nextStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task status updated.')));
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final fallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
      return;
    }
  }
}
