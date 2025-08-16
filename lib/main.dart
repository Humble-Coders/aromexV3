import 'package:aromex/firebase_options.dart';
import 'package:aromex/theme.dart';
import 'package:aromex/widgets/custom_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // If Firebase is already initialized, use the existing app
      Firebase.app();
    }
  } catch (e) {
    // If there's an error, try to initialize with default options
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e2) {
      print('Failed to initialize Firebase: $e2');
    }
  }

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: theme,
      home: CustomDrawer(
        onLogout: () {
          setState(() {});
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
