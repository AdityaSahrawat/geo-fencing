import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';

class Student {
  final String email;
  String status;
  String finalStatus;

  Student({
    required this.email,
    this.status = 'Pending',
    this.finalStatus = 'Absent',
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      email: json['email'] ?? 'Unknown Email',
      status: json['status'] ?? 'Pending',
      finalStatus: json['finalStatus'] ?? 'Absent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'status': status,
      'finalStatus': finalStatus,
    };
  }
}

class TakeAttendancePage extends StatefulWidget {
  const TakeAttendancePage({Key? key}) : super(key: key);

  @override
  _TakeAttendancePageState createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage> {
  String _selectedType = "class"; // Default class type
  final String VmURL = "http://35.193.196.5:5000";
  final String localURL = "http://10.0.10.5:5000";

  bool isLoading = false;
  bool sessionActive = false;
  String error = '';
  List<Student> students = []; // Use the Student model
  int nextIterationTime = 180; // Timer set to 1 minute for testing
  Timer? timer;
  late io.Socket socket;
  bool isSessionActive = true; // Track session state
  bool isAttendanceCompleted = false;

  // Dropdown values
  String? _selectedRoomNo;
  String? _selectedBranch;
  String? _selectedAdmissionYear;

  @override
  void initState() {
    super.initState();
    connectSocket();
  }

  void connectSocket() {
    socket = io.io('$VmURL', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      debugPrint('✅ Connected to Socket.IO server');
    });

    socket.onDisconnect((_) {
      debugPrint('⚠ Disconnected from Socket.IO server');
    });

    // Listener for attendance updates
    socket.on('attendanceUpdate', (data) {
      debugPrint("Received attendanceUpdate event: $data"); // Debug log

      setState(() {
        if (data['students'] == null || data['students'].isEmpty) {
          debugPrint("❌ Error: 'students' list is empty or missing");
          return;
        }

        // Convert server data to a List<Student>
        final List<Student> updatedStudents = (data['students'] as List)
            .map((student) => Student.fromJson(student))
            .toList();

        // If the students list is empty, initialize it with the updated students
        if (students.isEmpty) {
          students = updatedStudents;
        } else {
          // Update the students list
          students = students.map((student) {
            // Find the updated student data
            final updatedStudent = updatedStudents.firstWhere(
              (s) => s.email == student.email,
              orElse: () => student, // Return the original student if no match is found
            );

            debugPrint("Matching Student: ${student.email} -> ${updatedStudent.email}");

            // Update the student's status if a match is found
            return Student(
              email: student.email,
              status: updatedStudent.status,
              finalStatus: student.finalStatus,
            );
          }).toList();
        }
      });
    });

    socket.on('finalAttendance', (data) {
      print("Received finalAttendance event: $data"); // Debug log

      setState(() {
        if (data['students'] == null || data['students'].isEmpty) {
          print("❌ Error: 'students' list is empty or missing");
          return;
        }

        // Convert server data to a List<Student>
        final List<Student> updatedStudents = (data['students'] as List)
            .map((student) => Student.fromJson(student))
            .toList();

        // Update the students list
        students = students.map((student) {
          // Find the updated student data
          final updatedStudent = updatedStudents.firstWhere(
            (s) => s.email == student.email,
            orElse: () => student, // Return the original student if no match is found
          );

          print("✅ Found Student: ${updatedStudent.email}");

          // Update the student's final status if a match is found
          return Student(
            email: student.email,
            status: updatedStudent.finalStatus,
            finalStatus: updatedStudent.finalStatus, // Ensure finalStatus is updated
          );
        }).toList();
        
students =updatedStudents;
        // Set attendance completion to true
        isAttendanceCompleted = true;
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    socket.disconnect();
    super.dispose();
  }

  void startTimer() {
    timer?.cancel(); // Cancel any existing timer
    timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (nextIterationTime > 0) {
        setState(() {
          nextIterationTime--;
        });
      } else {
        // Timer completed: Send a request to /take
        await sendTakeRequest();
        setState(() {
          nextIterationTime = 180; // Reset timer to 1 minute
        });
      }
    });
  }

  Future<void> sendTakeRequest() async {
    try {
      String token = await _getToken();
      var response = await http.post(
        Uri.parse('$VmURL/api/attendance/take'),
        headers: {
          'Authorization': 'Bearer $token', // Include the token in the headers
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'roomNo': _selectedRoomNo, // Use the selected room number
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Request to /take successful");
      } else {
        debugPrint("❌ Failed to send request to /take: ${response.statusCode}");
        throw Exception("Failed to send request to /take");
      }
    } catch (e) {
      debugPrint("❌ Error in sendTakeRequest: $e"); // Log the error
      setState(() {
        error = 'Failed to send request to /take';
      });
    }
  }

  Future<void> startAttendance() async {
    if (_selectedRoomNo == null || _selectedBranch == null || _selectedAdmissionYear == null) {
      setState(() {
        error = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      error = '';
      isLoading = true;
    });

    try {
      String token = await _getToken();

      var response = await http.post(
        Uri.parse('$VmURL/api/attendance/start'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomNo': _selectedRoomNo,
          'branch': _selectedBranch,
          'admissionYear': _selectedAdmissionYear,
          'type': _selectedType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          sessionActive = true;
          isSessionActive = true;
          students = (data['students'] as List)
              .map((student) => Student.fromJson(student))
              .toList();
          nextIterationTime = 180; // Reset timer to 1 minute
        });
        startTimer(); // Start the timer after successful API call
      } else {
        throw Exception("Failed to start attendance");
      }
    } catch (e) {
      print("❌ Error starting attendance: $e"); // Log the error
      setState(() {
        error = 'Failed to start attendance. Please try again.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> stopAttendance() async {
    setState(() {
      isLoading = true;
    });

    try {
      String token = await _getToken();
      var response = await http.post(
        Uri.parse('$VmURL/api/attendance/stop'),
        body: jsonEncode({
          'roomNo': _selectedRoomNo, // Use the selected room number
        }),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          sessionActive = false;
          isSessionActive = false;
          // Set attendance completion to true
          nextIterationTime = 180; // Reset timer
        });
        timer?.cancel();

        // Fetch final attendance data from the socket
        socket.emit('finalAttendance', {'roomNo': _selectedRoomNo});
      } else {
        throw Exception("Failed to stop attendance session");
      }
    } catch (e) {
      setState(() {
        error = 'Failed to stop attendance. Please try again.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
    
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Helper methods to calculate counts
  int getTotalStudents() {
    return students.length;
  }

  int getPresentStudents() {
    return students.where((student) => student.status == 'Present').length;
  }

  int getAbsentStudents() {
    return students.where((student) => student.status == 'Absent').length;
  }

  int getPendingStudents() {
    return students.where((student) => student.status == 'Pending').length;
  }

  // Helper method to build a count card
  Widget _buildCountCard(String title, int count, Color color) {
    return Card(
      elevation: 3,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Take Attendance"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (isAttendanceCompleted) ...[
              Text(
                "Attendance Completed",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(student.email), // Display student email
                        subtitle: Text(
                          "Final Status: ${student.finalStatus}",
                          style: TextStyle(
                            color: student.finalStatus == 'Absent' ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (!sessionActive && !isAttendanceCompleted) ...[
              // Dropdown for Room No
              DropdownButtonFormField<String>(
                value: _selectedRoomNo,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRoomNo = newValue!;
                  });
                },
                items: <String>['krc', '102', '103', '104','campus']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: "Room No",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),

              // Dropdown for Branch
              DropdownButtonFormField<String>(
                value: _selectedBranch,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedBranch = newValue!;
                  });
                },
                items: <String>['CSE', 'DSAI', 'ECE']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: "Branch",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),

              // Dropdown for Admission Year
              DropdownButtonFormField<String>(
                value: _selectedAdmissionYear,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedAdmissionYear = newValue!;
                  });
                },
                items: <String>['2022', '2023', '2024']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: "Admission Year",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),

              // Dropdown for Class Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                items: <String>['tutorial', 'class', 'lab']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: "Class Type",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),

              // Start Attendance Button
              ElevatedButton(
                onPressed: sessionActive ? null : startAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Start Attendance", style: TextStyle(fontSize: 16)),
              ),
            ],
            if (sessionActive) ...[
              Text(
                "Next Iteration in: ${formatTime(nextIterationTime)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 20),
              DataTable(
                columns: const [
                  DataColumn(label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Count", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  DataRow(cells: [
                    DataCell(Text("Total Students")),
                    DataCell(Text(getTotalStudents().toString())),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Present")),
                    DataCell(Text(getPresentStudents().toString())),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Absent")),
                    DataCell(Text(getAbsentStudents().toString())),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Pending")),
                    DataCell(Text(getPendingStudents().toString())),
                  ]),
                ],
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final status = isSessionActive
                        ? student.status // Use status if session is active
                        : student.finalStatus; // Use finalStatus if session is inactive

                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text(student.email), // Display student email
                        subtitle: Text(
                          "Status: $status",
                          style: TextStyle(
                            color: status == 'Absent' ? Colors.red : (status == 'Pending' ? Colors.orange : Colors.green),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: stopAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text("Stop Attendance", style: TextStyle(fontSize: 16)),
              ),
            ],
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  error,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}