import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/app.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/services/desktop_lifecycle_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final container = ProviderContainer();
  final db = container.read(databaseProvider);
  
  // Initialize Desktop Protection
  await DesktopLifecycleService(db).init();

  // Global Error Hardening
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _GlobalErrorScreen(details: details);
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SenteryApp(),
    ),
  );
}

class _GlobalErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;
  const _GlobalErrorScreen({required this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Hisab360: Unexpected Error',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app encountered a technical problem. Your data is still safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SenteryApp()),
                    (route) => false,
                  ),
                  child: const Text('Repair & Restart App'),
                ),
                const SizedBox(height: 16),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
