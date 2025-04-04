import 'package:flutter/material.dart';
import 'assistant.dart';
import 'authority/complaint_form.dart';
import 'home_page.dart';
import 'authority/assistant_authority.dart';
import 'authority/authority_navbar.dart';
import 'authority/login_authority.dart';
import 'authority/report_list.dart';
import 'authority/settings_authority.dart';
import 'user/assistant_user.dart';
import 'user/login_user.dart';
import 'user/ForgotPassword_user.dart';
import 'user/register_user.dart';
import 'user/register_complaint.dart';
import 'user/settings_user.dart';
import 'user/track_complaint.dart';
import 'user/user_navbar.dart';

void main() {
  runApp(const ALaaSApp());
}

class ALaaSApp extends StatelessWidget {
  const ALaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALaaS App',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/assistant': (context) => AIChatAssistantPage(),

        // User Routes
        '/user/login': (context) => const UserLoginScreen(),
        '/user/register': (context) => const SimpleRegisterScreen(),
        '/user/dashboard': (context) => const UserNavBar(),
        '/user/register_complaint': (context) => const RegisterComplaint(),
        '/user/track_complaint': (context) => UserComplaintsPage(),
        '/user/assistant_user': (context) => const AIChatAssistantUserPage(),
        '/user/settings': (context) => const SettingsUser(),
        '/user/ForgotPassword_user': (context) => const ForgotPasswordScreen(),

        // Authority Routes
        '/authority': (context) => const AuthorityLoginScreen(), 
        '/authority/dashboard': (context) => const AuthorityNavBar(),
        '/authority/complaint_form': (context) =>  AuthorityComplaintsPage(),
        '/authority/assistant_authority': (context) =>
            const AIChatAssistantAuthorityPage(),
        '/authority/settings': (context) => const SettingsAuthority(),
        '/authority/report': (context) => const ReportListPage(),
      },
    );
  }
}
