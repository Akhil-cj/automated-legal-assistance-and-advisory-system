import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'assistant_authority.dart';
import 'dashboard_authority.dart';
import 'settings_authority.dart'; // Import Settings Page
 // Import AI Assistant Page

class AuthorityNavBar extends StatefulWidget {
  const AuthorityNavBar({super.key});

  @override
  _AuthorityNavBarState createState() => _AuthorityNavBarState();
}

class _AuthorityNavBarState extends State<AuthorityNavBar> {
  int _selectedIndex = 0;
  String authorityName = ''; // Initialize authorityName as an empty string

  // Pages list
  final List<Widget> _pages = [];

  // Function to load authorityName from SharedPreferences
  Future<void> _loadAuthorityName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      authorityName = prefs.getString('authority_name') ?? ''; // Get authority name from SharedPreferences
    });

    // Update _pages with authorityName
    _pages.clear();
    _pages.add(AuthorityDashboard(authorityName: authorityName)); // Pass authorityName to AuthorityDashboard
    _pages.add(AIChatAssistantAuthorityPage()); // Complaints widget
    _pages.add(SettingsAuthority()); // Settings widget
  }

  @override
  void initState() {
    super.initState();
    _loadAuthorityName(); // Call the method to load the authorityName
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If the authorityName is not loaded yet, show a loading indicator
    if (authorityName.isEmpty) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: _pages[_selectedIndex], // Display the selected page
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Virtual Assistant',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple,
        onTap: _onItemTapped,
      ),
    );
  }
}
