import 'package:flutter/material.dart';
import 'package:lockspot/features/auth/auth_screen.dart';
import 'package:lockspot/features/main_screen.dart';
import 'package:lockspot/services/auth_service.dart';
import 'package:lockspot/shared/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No Firebase initialization needed - using our own backend
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockSpot',
      theme: appTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _auth.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking auth state
    if (_auth.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logoandlogotextstackedV.png',
                height: 100,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    // Check if user is logged in
    if (_auth.isLoggedIn) {
      return const MainScreen();
    } else {
      return const AuthScreen();
    }
  }
}
