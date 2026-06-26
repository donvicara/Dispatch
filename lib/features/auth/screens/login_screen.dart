import 'package:flutter/material.dart';
import 'package:dispatch_app/features/drivers/screens/home_screen.dart';
import 'package:dispatch_app/features/tasks/screens/firestore_test_screen.dart';

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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FirestoreTestScreen(),
                    ),
                  );
                },
                child: const Text('Android Firebase MVP test'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
