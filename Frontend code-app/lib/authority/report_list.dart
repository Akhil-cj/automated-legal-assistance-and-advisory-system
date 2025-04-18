import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({super.key});

  @override
  _ComplaintFormPageState createState() => _ComplaintFormPageState();
}

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _location = "Fetching location...";
  final DateTime _currentTime = DateTime.now();
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    fetchLocation();
  }

  Future<void> fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enable location services on your device.')),
      );
      return;
    }

    // Request permission if not already granted
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      // Get the current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _location = "Lat: ${position.latitude}, Long: ${position.longitude}";
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permissions are denied.')),
      );
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = Uint8List.fromList(imageBytes);
      });
    }
  }

  Future<void> submitComplaint() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields and select an image.')),
      );
      return;
    }

    final imageBase64 = base64Encode(_imageBytes!);

    // Get current time in ISO8601 format
    final isoDateTime = _currentTime.toIso8601String();

    final response = await http.post(
      Uri.parse('http://localhost:5000/complaints'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _location,
        'time': isoDateTime, // Send the time in ISO8601 format
        'image_url': imageBase64,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complaint submitted successfully!')),
      );
      Navigator.pop(context, true); // Navigate back and notify of success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit complaint.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register Complaint')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: TextEditingController(text: _location),
              enabled: false,
              decoration: InputDecoration(labelText: 'Location'),
            ),
            SizedBox(height: 16),
            _imageBytes == null
                ? Text('No image selected.')
                : Image.memory(_imageBytes!, height: 150),
            ElevatedButton(
              onPressed: pickImage,
              child: Text('Pick Image'),
            ),
            ElevatedButton(
              onPressed: submitComplaint,
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}


class ComplaintDetailsPage extends StatelessWidget {
  final int complaintId;

  const ComplaintDetailsPage({super.key, required this.complaintId});

  Future<Map<String, dynamic>> fetchComplaintDetails() async {
    final response = await http
        .get(Uri.parse('http://localhost:5000/complaints/$complaintId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load complaint details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Complaint Details')),
      body: FutureBuilder(
        future: fetchComplaintDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading complaint details'));
          } else {
            final complaint = snapshot.data as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Title: ${complaint['title']}',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Description: ${complaint['description']}'),
                  SizedBox(height: 8),
                  Text('Location: ${complaint['location']}'),
                  SizedBox(height: 8),
                  Text('Time: ${complaint['time']}'),
                  SizedBox(height: 16),
                  complaint['image_url'] != null
                      ? Image.network(complaint['image_url'], height: 150,
                          errorBuilder: (context, error, stackTrace) {
                          return Text('Failed to load image.');
                        })
                      : Text('No image available'),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class ReportListPage extends StatefulWidget {
  const ReportListPage({super.key});

  @override
  _ReportListPageState createState() => _ReportListPageState();
}

class _ReportListPageState extends State<ReportListPage> {
  List complaints = [];

  @override
  void initState() {
    super.initState();
    fetchComplaints();
  }

  Future<void> fetchComplaints() async {
    final response =
        await http.get(Uri.parse('http://localhost:5000/complaints'));
    if (response.statusCode == 200) {
      setState(() {
        complaints = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load complaints');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Complaints')),
      body: ListView.builder(
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          final complaint = complaints[index];
          return ListTile(
            title: Text(complaint['title']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ComplaintDetailsPage(complaintId: complaint['id']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ComplaintFormPage()),
          ).then((_) =>
              fetchComplaints()); // Refresh list after adding a complaint
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
