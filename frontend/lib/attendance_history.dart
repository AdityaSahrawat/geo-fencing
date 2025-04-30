import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
  final String VmURL = "http://35.193.196.5:5000";

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryPageState createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final String localURL = "http://10.0.10.5:5000";

  bool isLoading = false;
  String error = '';
  List<dynamic> attendanceHistory = [];
  Map<String, dynamic>? selectedSession;

  @override
  void initState() {
    super.initState();
    fetchAttendanceHistory();
  }

  Future<void> fetchAttendanceHistory() async {
    setState(() {
      isLoading = true;
      error = '';
      selectedSession = null;
    });

    try {
      String token = await _getToken();

      // Send a GET request to fetch the entire history
      final response = await http.get(
        Uri.parse('$VmURL/api/attendance/history'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      // Print the response status code and body for debugging
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          attendanceHistory = data['attendanceHistory'];
        });

        // Print the fetched attendance history for debugging
        print('Fetched Attendance History: $attendanceHistory');
      } else if (response.statusCode == 404) {
        setState(() {
          attendanceHistory = [];
        });

        // Print a message for 404 status code
        print('No attendance history found (404)');
      } else {
        throw Exception("Failed to fetch attendance history: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        error = 'Failed to fetch attendance history: $e';
      });

      // Print the error for debugging
      print('Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void selectSession(Map<String, dynamic> session) {
    setState(() {
      selectedSession = session;
    });

    // Navigate to a new page when a session is clicked
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsPage(session: session),
      ),
    );
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String formatTime(String timeString) {
    try {
      final time = DateTime.parse(timeString); // Convert UTC to local time (IST)
      return DateFormat('hh:mm a').format(time); // Format in IST
    } catch (e) {
      return timeString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance History"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Error message
          if (error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (isLoading)
            const LinearProgressIndicator(),

          // Content section
          Expanded(
            child: ListView.builder(
              itemCount: attendanceHistory.length,
              itemBuilder: (context, index) {
                final attendance = attendanceHistory[index];
                final sessions = attendance['sessions'] ?? [];

                return Card(
                  margin: const EdgeInsets.all(16),
                  child: ExpansionTile(
                    title: 
                    Text("Date: ${formatDate(attendance['date'])}",style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 16),),
                    subtitle: Text(
                      "Room: ${attendance['roomNo']}",
                      style: const TextStyle(fontWeight: FontWeight.w400,fontSize: 14),
                    ),
                    children: sessions.map<Widget>((session) {
                      return ListTile(
                        title: Text(
                          "Type: ${session['type'] ?? 'Unknown'}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Branch: ${session['branch'] ?? 'Unknown'}"),
                            Text("Start Time: ${formatTime(session['startTime'] ?? '')}"),
                            Text("Students: ${session['students']?.length ?? 0}")
                         
                          ],
                        ),
                        onTap: () => selectSession(session),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SessionDetailsPage extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionDetailsPage({Key? key, required this.session}) : super(key: key);

  @override
  _SessionDetailsPageState createState() => _SessionDetailsPageState();
}

class _SessionDetailsPageState extends State<SessionDetailsPage> {
  late List<dynamic> students;
  bool isLoading = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    students = widget.session['students'] ?? [];
  }

  Future<void> updateStudentStatus(String sessionId, String studentId, String status) async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$VmURL/api/attendance/update-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'studentId': studentId,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        // Update the local state
        setState(() {
          for (int i = 0; i < students.length; i++) {
            if (students[i]['_id'] == studentId) {
              students[i]['finalStatus'] = status;
              break;
            }
          }
        });
      } else {
        throw Exception("Failed to update student status: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        error = 'Failed to update student status: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Session Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Error message
          if (error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(12),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (isLoading)
            const LinearProgressIndicator(),

          // Students list
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Students (${students.length})",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade300,
              ),
              itemBuilder: (context, index) {
                final student = students[index];
                final status = student['finalStatus'] ?? 'Absent';
                final email = student['studentId']?['email'] ?? 'Unknown Email';
                final studentId = student['_id'];
                final sessionId = widget.session['_id'];

                return ListTile(
                  title: Text(email),
                  subtitle: Row(
                    children: [
                      Text(
                        "Status: ",
                        style: TextStyle(
                          color: status == 'Present' ? Colors.green : Colors.red,
                        ),
                      ),
                      // Dropdown to update status
                      DropdownButton<String>(
                        value: status,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            updateStudentStatus(sessionId, studentId, newValue);
                          }
                        },
                        items: <String>['Present', 'Absent']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: value == 'Present' ? Colors.green : Colors.red,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}