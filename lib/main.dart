import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/app.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/services/desktop_lifecycle_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // Use runZonedGuarded to catch any silent crashes during startup
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    final container = ProviderContainer();
    final db = container.read(databaseProvider);
    
    // Initialize Desktop Protection (Safe for Web)
    try {
      await DesktopLifecycleService(db).init();
    } catch (e) {
      debugPrint('[Main] Desktop init ignored: $e');
    }

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
  }, (error, stack) {
    debugPrint('[CRITICAL] Flutter Startup Error: $error');
    debugPrint(stack.toString());
  });
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
                  'Hisab360: Technical Issue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The system encountered an error. Your records are safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                     if (kIsWeb) {
                       // On web, a simple refresh is the best repair
                       // ignore: avoid_web_libraries_in_flutter
                       // import 'dart:html' as html;
                       // html.window.location.reload();
                     } else {
                       Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const SenteryApp()),
                        (route) => false,
                       );
                     }
                  },
                  child: const Text('Refresh & Repair'),
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
