import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'ForgotPassword_user.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginUser() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  final response = await http.post(
    Uri.parse('http://localhost:5000/login_user'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'username': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
    }),
  );

  setState(() {
    _isLoading = false;
  });

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    
    // Ensure username is stored even if not returned by backend
    final loggedInUsername = data['username'] ?? _emailController.text.trim();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString('username');

    if (savedUsername == null || savedUsername != loggedInUsername) {
      await prefs.setString('username', loggedInUsername); // Save only if new or different
      print("Username saved locally: $loggedInUsername");
    }

    Navigator.pushReplacementNamed(context, '/user/dashboard');
  } else {
    setState(() {
      _errorMessage = 'Invalid credentials';
    });
  }
}

  void _navigateToRegister() {
    Navigator.pushNamed(context, '/user/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image.png'),
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
                      const Text('Login as User',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          )),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _loginUser,
                              child: const Text('Login'),
                            ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _navigateToRegister,
                        child: const Text('Register as a New User'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?'),
                      ),
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
