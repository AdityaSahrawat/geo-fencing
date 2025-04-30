import 'package:flutter/material.dart';
import 'package:geo_attendance/teacher_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geo_attendance/login_screen.dart';
import 'package:geo_attendance/student_dashboard.dart';
import 'background_services.dart'; // Import your background service

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
  await initializeService(); // Start the background location service
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Wrapper(), // Handles login state
    );
  }
}
class Wrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
      future: _checkLoginState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If no data or error, go to LoginScreen
        if (!snapshot.hasData || snapshot.hasError) {
          return LoginScreen();
        }

        final token = snapshot.data!['token'];
        final role = snapshot.data!['role'];

        // If token or role is missing, go to LoginScreen
        if (token == null || role == null) {
          return LoginScreen();
        }

        // If both token and role exist, redirect based on role
        switch (role.toLowerCase()) {
          case 'student':
            return StudentDashboard();
          case 'teacher':
            return TeacherDashboard();
          // Unknown role? Go back to LoginScreen
          default:
            return LoginScreen();
        }
      },
    );
  }

  Future<Map<String, String?>> _checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString('token'),
      'role': prefs.getString('role'),
    };
  }
}