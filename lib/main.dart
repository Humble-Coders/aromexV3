import 'package:aromex/firebase_options.dart';
import 'package:aromex/theme.dart';
import 'package:aromex/widgets/custom_drawer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
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
      // FirebaseAuth.instance.currentUser == null
      //     ? LoginPage(
      //       onLoginSuccess: () {
      //         setState(() {
      //           // Trigger a rebuild to show the home page after login
      //         });
      //       },
      //     )
      //     : CustomDrawer(
      //       onLogout: () {
      //         setState(() {
      //           // Trigger a rebuild to show the login page after logout
      //         });
      //       },
      //     ),
      debugShowCheckedModeBanner: false,
    );
  }
}
