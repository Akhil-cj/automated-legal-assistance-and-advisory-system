import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailListPage extends StatefulWidget {
  @override
  _EmailListPageState createState() => _EmailListPageState();
}

class _EmailListPageState extends State<EmailListPage> {
  List emails = [];
  bool isLoading = false;
  String statusMessage = '';

  Future<void> fetchEmails() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Loading emails...';
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/emails'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          emails = data['emails'] ?? [];
          statusMessage = 'Processed ${data['new_count']} new emails';
        });
      } else {
        setState(() => statusMessage = 'Error loading emails.');
      }
    } catch (e) {
      setState(() => statusMessage = 'Failed to fetch emails.');
    }
    setState(() => isLoading = false);
  }

  Future<void> reloadEmails() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Reloading emails...';
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:5000/reload'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          emails = data['emails'] ?? [];
          statusMessage = data['message'];
        });
      } else {
        setState(() => statusMessage = 'Error reloading emails.');
      }
    } catch (e) {
      setState(() => statusMessage = 'Failed to reload emails.');
    }
    setState(() => isLoading = false);
  }

  Future<String> fetchSummary(String section) async {
    final response = await http.get(Uri.parse('http://localhost:5000/get_summary?section=$section'));
    if (response.statusCode == 200) {
      return json.decode(response.body)['summary'];
    }
    return 'Error loading summary.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Emails Viewer', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Container(
        padding: EdgeInsets.all(16.0),
        color: Colors.grey[100],
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: fetchEmails,
                  icon: Icon(Icons.download),
                  label: Text('Load Emails'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: reloadEmails,
                  icon: Icon(Icons.refresh),
                  label: Text('Reload Emails'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (statusMessage.isNotEmpty)
              Text(statusMessage, style: TextStyle(color: Colors.blue, fontSize: 16)),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : emails.isEmpty
                      ? Center(child: Text('No emails processed yet.', style: TextStyle(fontSize: 16, color: Colors.black54)))
                      : ListView.builder(
                          itemCount: emails.length,
                          itemBuilder: (context, index) {
                            final email = emails[index];
                            return EmailCard(email: email, fetchSummary: fetchSummary);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailCard extends StatefulWidget {
  final Map email;
  final Future<String> Function(String) fetchSummary;

  EmailCard({required this.email, required this.fetchSummary});

  @override
  _EmailCardState createState() => _EmailCardState();
}

class _EmailCardState extends State<EmailCard> {
  String? selectedStatus;
  String? selectedAuthority;
  bool isUpdating = false;
  List<String> authorities = ['Child rights protection', 'Social welfare', 'Food health and safety','Woman welfare and safety','police','others']; // Example authorities

  Future<void> updateEmailStatus(String emailId, String status) async {
    setState(() => isUpdating = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/update_status/$emailId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"status": status, "authority": selectedAuthority}),
      );

      if (response.statusCode == 200) {
        setState(() {
          widget.email['status'] = status;
          selectedStatus = status;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email status updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }

    setState(() => isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      elevation: 3,
      color: Colors.blueGrey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.email['subject'],
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 5),
            Text('From: ${widget.email['sender']}', style: TextStyle(color: Colors.white)),
            Text('Date: ${widget.email['date']}', style: TextStyle(color: Colors.white)),
            SizedBox(height: 10),
            Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.email['summary'], style: TextStyle(color: Colors.white70)),
            SizedBox(height: 10),

            // Email Status Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status: ${widget.email['status']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                DropdownButton<String>(
                  value: selectedStatus ?? widget.email['status'],
                  dropdownColor: Colors.grey[800],
                  onChanged: isUpdating
                      ? null
                      : (String? newStatus) {
                          if (newStatus != null) {
                            setState(() {
                              selectedStatus = newStatus;
                              if (newStatus == "Forwarded") {
                                selectedAuthority = authorities.first;
                              }
                            });
                          }
                        },
                  items: ['Pending', 'Forwarded']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status, style: TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                ),
              ],
            ),

            // Show Authority Dropdown if "Forwarded" is selected
            if (selectedStatus == "Forwarded")
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Text('Select Authority:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  DropdownButton<String>(
                    value: selectedAuthority,
                    dropdownColor: Colors.grey[800],
                    onChanged: isUpdating
                        ? null
                        : (String? newAuthority) {
                            if (newAuthority != null) {
                              setState(() => selectedAuthority = newAuthority);
                            }
                          },
                    items: authorities
                        .map((authority) => DropdownMenuItem(
                              value: authority,
                              child: Text(authority, style: TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                  ),
                ],
              ),

            SizedBox(height: 10),
            ElevatedButton(
              onPressed: selectedStatus == "Forwarded" && selectedAuthority == null
                  ? null
                  : () => updateEmailStatus(widget.email['id'].toString(), selectedStatus!),
              child: isUpdating ? CircularProgressIndicator() : Text('Update Status'),
            ),

            SizedBox(height: 10),
            Text('Matched IPC Sections:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            if (widget.email['matches'] != null && widget.email['matches'].isNotEmpty)
              Column(
                children: List.generate(widget.email['matches'].length, (i) {
                  final match = widget.email['matches'][i];
                  return SectionMatch(match: match, fetchSummary: widget.fetchSummary);
                }),
              )
            else
              Text('No matching IPC sections found.', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class SectionMatch extends StatefulWidget {
  final Map match;
  final Future<String> Function(String) fetchSummary;

  SectionMatch({required this.match, required this.fetchSummary});

  @override
  _SectionMatchState createState() => _SectionMatchState();
}

class _SectionMatchState extends State<SectionMatch> {
  bool showSummary = false;
  String summary = '';
  String detailedDescription = '';
  bool isSummaryLoading = false;
  bool isDetailedLoading = false;

  // Fetch summary when clicking the section number
  void fetchSummary() async {
    setState(() => isSummaryLoading = true);
    summary = await widget.fetchSummary(widget.match['section'].toString());
    setState(() {
      isSummaryLoading = false;
      showSummary = true; // Show the summary after fetching
    });
  }

  // Fetch detailed description when clicking "Get detailed summary"
  void fetchDetailedDescription() async {
    setState(() => isDetailedLoading = true);
    detailedDescription = widget.match['description']; // Directly assign the stored description
    setState(() => isDetailedLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[200],
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Section ${widget.match['section']}',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            onTap: fetchSummary, // Fetch summary when tapping the section number
          ),
          if (showSummary)
            Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSummaryLoading)
                    Center(child: CircularProgressIndicator())
                  else if (summary.isNotEmpty)
                    Text(summary, style: TextStyle(color: Colors.black87)),
                  
                  SizedBox(height: 5),
                  
                  TextButton.icon(
                    onPressed: fetchDetailedDescription,
                    icon: Icon(Icons.article),
                    label: Text('Get detailed description'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),

                  if (isDetailedLoading)
                    Center(child: CircularProgressIndicator())
                  else if (detailedDescription.isNotEmpty)
                    Text(detailedDescription, style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


