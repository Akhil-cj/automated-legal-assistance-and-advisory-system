import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'login_user.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isVerified = false;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _verifyUsername() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await http.post(
      Uri.parse('http://localhost:5000/verify_user'), // Updated URL
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': _usernameController.text}),
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      setState(() {
        _isVerified = true;
      });
    } else {
      setState(() {
        _errorMessage = 'Username not found';
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await http.post(
      Uri.parse('http://localhost:5000/reset_password'), // Updated URL
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': _usernameController.text,
        'new_password': _newPasswordController.text,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserLoginScreen()),);
    } else {
      setState(() {
        _errorMessage = 'Error resetting password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image.png'), // Background image
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.white.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Forgot Password',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _isVerified
                          ? Column(
                              children: [
                                TextField(
                                  controller: _newPasswordController,
                                  decoration: const InputDecoration(
                                    labelText: 'New Password',
                                    border: OutlineInputBorder(),
                                  ),
                                  obscureText: true,
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _confirmPasswordController,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm Password',
                                    border: OutlineInputBorder(),
                                  ),
                                  obscureText: true,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _resetPassword,
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text('Reset Password'),
                                ),
                              ],
                            )
                          : ElevatedButton(
                              onPressed: _verifyUsername,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Verify Username'),
                            ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
