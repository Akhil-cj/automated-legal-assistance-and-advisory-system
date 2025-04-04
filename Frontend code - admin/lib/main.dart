import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'home.dart';
import 'screens/authority_management.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/email_management.dart';
import 'theme/theme.dart';

void main() {
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: customTheme,
      routerConfig: _router,
    );
  }
}

// ✅ GoRouter setup with all routes
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>  HomeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) =>  LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) =>  DashboardScreen(),
    ),
    GoRoute(
      path: '/emails',
      builder: (context, state) =>  EmailListPage(),
    ),
    GoRoute(
      path: '/authority',
      builder: (context, state) =>  AuthorityManagementPage(),
    ),
  ],
);
