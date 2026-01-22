import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../core/services/dish_seeder_service.dart';
import '../core/data/dish_data.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('--- DB SEEDER SCRIPT STARTED ---');

  try {
    print('Loading environment variables (.env)...');
    try {
      await dotenv.load(); // Default looks for .env in root
      print('.env loaded successfully.');
    } catch (e) {
      print('Warning: .env load failed: $e. Using empty env.');
    }

    print('Initialising Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print(
        'Firebase Initialised successfully for project: ${DefaultFirebaseOptions.currentPlatform.projectId}');

    final seeder = DishSeederService();

    print('Targeting ALL DISHES. Total: ${allDishes.length}');
    print('Starting seeding process...');

    await seeder.seedDishes(allDishes);

    print('--- DB SEEDER SCRIPT COMPLETED SUCCESSFULLY ---');
    print('Wait 5s for logs to sync...');
    await Future.delayed(const Duration(seconds: 5));
  } catch (e, stack) {
    print('CRITICAL ERROR IN SCRIPT: $e');
    print('STACK TRACE: $stack');
  }

  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text('Seeding Finished',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Check terminal for logs.',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    ),
  );
}
