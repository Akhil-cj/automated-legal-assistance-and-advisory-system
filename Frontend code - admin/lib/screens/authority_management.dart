import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthorityManagementPage extends StatefulWidget {
  @override
  _AuthorityManagementPageState createState() => _AuthorityManagementPageState();
}

class _AuthorityManagementPageState extends State<AuthorityManagementPage> {
  List<Map<String, dynamic>> authorities = [];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController stateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAuthorities();
  }

  // Fetch authorities from the backend
  Future<void> fetchAuthorities() async {
    final response = await http.get(Uri.parse('http://localhost:5000/get_authorities'));

    if (response.statusCode == 200) {
      setState(() {
        authorities = List<Map<String, dynamic>>.from(json.decode(response.body));
      });
    } else {
      print("Failed to load authorities");
    }
  }

  // Add new authority
  Future<void> addAuthority() async {
    if (
       
        nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        stateController.text.isEmpty) return;

    final response = await http.post(
      Uri.parse('http://192.168.220.247:8080/add_authority'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "password": passwordController.text,
        "name": nameController.text,
        "email": emailController.text,
        "state": stateController.text
      }),
    );

    if (response.statusCode == 201) {
      fetchAuthorities();
      passwordController.clear();
      nameController.clear();
      emailController.clear();
      stateController.clear();
    } else {
      print("Failed to add authority");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Authority Management")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Add New Authority", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
            TextField(controller: emailController, decoration: InputDecoration(labelText: "Email")),
            TextField(controller: passwordController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
            TextField(controller: stateController, decoration: InputDecoration(labelText: "State")),
            SizedBox(height: 10),
            ElevatedButton(onPressed: addAuthority, child: Text("Add Authority")),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: authorities.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text("${authorities[index]["name"]} (${authorities[index]["authority_id"]})"),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Email: ${authorities[index]["email"]}"),
                          Text("State: ${authorities[index]["state"]}"),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
