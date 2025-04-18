import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthorityLoginScreen extends StatefulWidget {
  const AuthorityLoginScreen({super.key});

  @override
  _AuthorityLoginScreenState createState() => _AuthorityLoginScreenState();
}

class _AuthorityLoginScreenState extends State<AuthorityLoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

Future<void> login() async {
  final String name = nameController.text.trim();
  final String password = passwordController.text.trim();

  if (name.isEmpty || password.isEmpty) {
    _showErrorDialog('Please provide both name and password');
    return;
  }

  final response = await http.post(
    Uri.parse('http://localhost:5000/login_authority'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'name': name, 'password': password}),
  );

  final Map<String, dynamic> responseData = json.decode(response.body);

  if (response.statusCode == 200) {
    String? authorityName = responseData['authority_name'];
    if (authorityName != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('authority_name', authorityName);

      print("Authority Name Saved: $authorityName");

      // After saving the authority name, navigate to the dashboard with authority name
      Navigator.pushNamed(
        context, 
        '/authority/dashboard',
        arguments: authorityName,  // Pass authority name as an argument
      );
    } else {
      _showErrorDialog('Invalid response from server: authority_name is missing');
    }
  } else {
    _showErrorDialog(responseData['message']);
  }
}


// Utility function for error dialogs
void _showErrorDialog(String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Error'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Okay'),
        ),
      ],
    ),
  );
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
                      const Text(
                        'Login as Authority',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Authority Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: login,
                        child: const Text('Login'),
                      ),
                      const SizedBox(height: 10),
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
