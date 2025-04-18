import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthorityComplaintsPage extends StatefulWidget {
  @override
  _AuthorityComplaintsPageState createState() => _AuthorityComplaintsPageState();
}

class _AuthorityComplaintsPageState extends State<AuthorityComplaintsPage> {
  List complaints = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAuthorityComplaints();
  }

  Future<void> fetchAuthorityComplaints() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? authorityName = prefs.getString('authority_name');

  if (authorityName == null) {
    return;
  }

  final response = await http.get(
    Uri.parse('http://localhost:5000/view_authority_complaints'),
    headers: {
      'Content-Type': 'application/json',
      'Authority-Name': authorityName,
    },
  );

  print('Response Body: ${response.body}'); // Debugging line

  if (response.statusCode == 200) {
    var decodedData = json.decode(response.body);

    // Check if the response is a map and extract the list of complaints
    if (decodedData is Map<String, dynamic>) {
      complaints = decodedData['complaints'] ?? [];  // Ensure 'complaints' key exists
    } else if (decodedData is List) {
      complaints = decodedData;
    } else {
      complaints = []; // Default to an empty list if unexpected format
    }

    setState(() {
      isLoading = false;
    });
  } else {
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> updateStatus(String newStatus, String authorityName, int complaintId) async {
    final response = await http.put(
      Uri.parse('http://localhost:5000/update_authority_complaint_status'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'status': newStatus,
        'authority_name': authorityName,  // Send the authority's name to the backend
      }),
    );

    if (response.statusCode == 200) {
      fetchAuthorityComplaints(); // refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'resolved':
        color = Colors.green;
        break;
      case 'pending':
      case 'forwarded':
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }
    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _statusDropdown(String currentStatus, int complaintId) {
    // Ensure 'currentStatus' is always in lowercase or consistent case.
    String dropdownValue = currentStatus.toLowerCase();

    return DropdownButton<String>(
      value: dropdownValue,
      items: <String>['forwarded', 'resolved']
          .map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value.toUpperCase()),
        );
      }).toList(),
      onChanged: (String? newValue) async {
        if (newValue != null && newValue != dropdownValue) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? authorityName = prefs.getString('authority_name');
          
          if (authorityName != null) {
            updateStatus(newValue, authorityName, complaintId);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Authority Complaints'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : complaints.isEmpty
              ? Center(child: Text('No complaints found'))
              : ListView.builder(
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    var matches = complaint['matches'];
                    if (matches is List) {
                      // Display each match individually in a card
                      matches = matches.map((match) => match.toString()).toList();
                    } else if (matches is! String) {
                      matches = [matches.toString()];
                    }

                    final complaintId = int.tryParse(complaint['id'].toString()) ?? 0;

                    return Card(
                      margin: EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              complaint['subject'],
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold
                              ),
                            ),
                            SizedBox(height: 6),
                            Text("Sender: ${complaint['sender']}"),
                            SizedBox(height: 4),
                            Text("Date: ${complaint['date']}"),
                            SizedBox(height: 4),
                            Text("Complaint ID: $complaintId"),
                            SizedBox(height: 6),
                            Text("Summary: ${complaint['summary']}"),
                            SizedBox(height: 6),

                            // Display each match separately in a list
                            Text("Matched BNS Sections:", style: TextStyle(fontWeight: FontWeight.bold)),
                            if (matches != null && matches.isNotEmpty)
                              ...matches.map<Widget>((match) {
                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      match,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                );
                              }).toList(),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatusChip(complaint['status']),
                                _statusDropdown(complaint['status'], complaintId),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
