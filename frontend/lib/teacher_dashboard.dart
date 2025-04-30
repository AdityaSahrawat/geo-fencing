import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'take_attendance_page.dart';
import 'attendance_history.dart';
import 'cancel_class.dart';
import 'login_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String teacherName = "";
  String teacherEmail = "";
  String teacherPhoto = "https://randomuser.me/api/portraits/men/45.jpg"; // Default photo

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      teacherName = prefs.getString('TeacherName') ?? "Unknown";
      teacherEmail = prefs.getString('TeacherEmail') ?? "Not available";
      teacherPhoto = prefs.getString('teacherPhoto') ??
          "https://randomuser.me/api/portraits/men/45.jpg"; // Default image
          
    });
  }
    Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // Remove token from shared preferences

    // Navigate to the login screen and remove all previous routes
      Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Teacher Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 99, 190, 250),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Teacher Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(teacherPhoto),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teacherName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          teacherEmail,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Button Cards
            buildCardButton(
              context: context,
              title: "Take Attendance",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TakeAttendancePage()),
              ),
            ),
            const SizedBox(height: 20),
            buildCardButton(
              context: context,
              title: "Attendance History",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceHistoryPage()),
              ),
            ),
            const SizedBox(height: 20),
            buildCardButton(
              context: context,
              title: "Cancel Class",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CancelClassPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCardButton({required BuildContext context, required String title, required VoidCallback onTap}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
          alignment: Alignment.center,
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
