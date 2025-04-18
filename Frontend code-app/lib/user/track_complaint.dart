import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserComplaintsPage extends StatefulWidget {
  @override
  _UserComplaintsPageState createState() => _UserComplaintsPageState();
}

class _UserComplaintsPageState extends State<UserComplaintsPage> {
  List complaints = [];
  bool isLoading = true;
  String? loggedInUsername;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      loggedInUsername = prefs.getString('username');
    });

    if (loggedInUsername != null) {
      fetchComplaints();
    }
  }

  Future<void> fetchComplaints() async {
    if (loggedInUsername == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final response = await http.get(
      Uri.parse('http://localhost:5000/view_user_complaints'),
      headers: {
        "Content-Type": "application/json",
        "Username": loggedInUsername!,  // Correctly passing username in headers
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        complaints = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load complaints. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Complaints'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : complaints.isEmpty
              ? const Center(child: Text('No complaints found'))
              : ListView.builder(
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(complaint['subject']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("To: ${complaint['to_authority']}"),
                            Text("Status: ${complaint['status']}"),
                            const SizedBox(height: 4),
                            Text("Description: ${complaint['description']}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
