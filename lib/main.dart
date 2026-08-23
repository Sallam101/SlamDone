import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/controllers/app_controller.dart';
import 'src/controllers/app_scope.dart';
import 'src/database/local_database.dart';
import 'src/firebase/firebase_config.dart';
import 'src/repositories/app_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorBoundary();

  if (FirebaseConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }

  final database = LocalDatabase();
  await database.open();
  final repository = AppRepository(database);
  final controller = AppController(database: database, repository: repository);
  await controller.initialize();
  runApp(AppScope(controller: controller, child: const AutivraApp()));
}

void _installErrorBoundary() {
  ErrorWidget.builder = (details) => const Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: Color(0xFFF7F4FA),
      child: Center(
        child: SizedBox(
          width: 520,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_outlined, size: 34),
                  SizedBox(height: 10),
                  Text(
                    'This section recovered from a layout problem.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Refresh the page or reopen SupeSlam. Your browser-saved data is not removed.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
