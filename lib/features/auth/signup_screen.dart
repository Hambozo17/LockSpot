import 'package:flutter/material.dart';
import 'package:lockspot/services/auth_service.dart';
import 'package:lockspot/services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _auth = AuthService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('First Name'),
            TextField(controller: _firstNameController),
            const SizedBox(height: 16),
            const Text('Last Name'),
            TextField(controller: _lastNameController),
            const SizedBox(height: 16),
            const Text('Phone Number'),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            const Text('Email'),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            const Text('Password'),
            TextField(controller: _passwordController, obscureText: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await _auth.signUp(
                      _firstNameController.text,
                      _lastNameController.text,
                      _phoneController.text,
                      _emailController.text,
                      _passwordController.text,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Registration successful! Please log in.'),
                      ),
                    );
                    Navigator.of(context).pop();
                  } on ApiException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registration failed: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Sign Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}