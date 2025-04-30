import 'package:flutter/material.dart';
import 'package:geo_attendance/attendance_history.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/intl.dart';
import 'device_utils.dart';
import 'dart:async';
import 'login_screen.dart';
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String status = "Waiting for attendance request...";
  bool isLoadingHistory = true;
  Position? location;
  String? email; // Use email instead of studentId
  List<Map<String, dynamic>> attendanceHistory = [];
  late IO.Socket socket;
    final String VmURL = "http://35.193.196.5:5000";
  final String localURL = "http://10.0.10.5:5000";
  String? _teacherName;
  String? _teacherEmail;
  String? _studentName;
  String? _rollNo;
  String? _branch;
   Timer? _biometricTimeout;
  bool _hasProvidedBiometrics = false;
   bool _biometricRequired = false; // Track if biometric is required from attendanceStarted
  bool _biometricVerified = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData().then((_) {
      initializeSocket();
    });
    fetchAttendanceHistory();
  }

  // Fetch profile data (email, name, rollNo, branch) from SharedPreferences
  Future<void> _fetchProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email'); // Retrieve email
      _studentName = prefs.getString('name'); // Retrieve student name
      _rollNo = prefs.getString('rollNo'); // Retrieve roll number
      _branch = prefs.getString('branch'); // Retrieve branch
    });
    print("Profile data retrieved: $email, $_studentName, $_rollNo, $_branch"); // Debug log
  }
  @override
  void dispose() {
    _biometricTimeout?.cancel();
    super.dispose();
  }
  void initializeSocket() {
    socket = IO.io('$VmURL', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      print("✅ Connected to socket");
      if (email != null) {
        
      debugPrint("Joining room with email: $email");
        socket.emit('joinRoom', email); // Join room using email
      }
    });

    // Listener for attendanceStarted event (require biometrics)
    socket.on('attendanceStarted', (data) async {
      debugPrint("Received attendanceStarted event: $data");
      setState(() {
        status = "Attendance session started. Please send your location.";
        _teacherName = data['teacher']['name']; // Extract teacher's name
        _teacherEmail = data['teacher']['email'];
        
        _biometricRequired = true; // Mark that biometric is required
        _biometricVerified = false;
      });
      final bool isAuthenticated = await authenticateWithBiometrics();
      
      setState(() {
        if (isAuthenticated) {
          _biometricVerified = true;
          status = "Biometric verified. Waiting for location request...";
        } else {
          status = "Biometric authentication missed. It will be required when sending location.";
        }
      });
        if (isAuthenticated) {
    await handleAttendanceRequest(data, requireBiometrics: false);
  }
    });

    // Listener for requestCoordinates event (no biometrics)
    socket.on('requestCoordinates', (data) async {
      debugPrint("Received requestCoordinates event in foreground: $data");
      if (data['students'].contains(email)) {
        //
        setState(() => status = "Attendance request received. Sending location...");
        debugPrint("Matched student email: $email"); 
          bool requireBiometrics = _biometricRequired && !_biometricVerified;
        await handleAttendanceRequest(data,requireBiometrics: requireBiometrics); 
          if (requireBiometrics && _hasProvidedBiometrics) {
          setState(() => _biometricVerified = true);
        }
      }
    });
    socket.on('finalAttendance', (_) {
      _biometricTimeout?.cancel(); 
      print("Final attendance recorded. Removing teacher info.");
      setState(() {
        _teacherName = null;
        _teacherEmail = null;
        status = "Your attendance is marked based on your location";
        _biometricRequired = false;
        _biometricVerified = false;
        _hasProvidedBiometrics = false;
      });

      // Set a timer to clear the status after 5 seconds
      Timer(Duration(seconds: 5), () {
        setState(() {
          status = ""; // Clear the status after 5 seconds
        });
      });
    });

    socket.onDisconnect((_) => print("⚠ Disconnected from socket"));
  }

  Future<void> handleAttendanceRequest(dynamic data, {bool requireBiometrics = false}) async {
  try {
    debugPrint("HANDLE ATTENDANCE STARTED");

    // Step 1: Perform biometric authentication if required
    if (requireBiometrics) {
      final bool isAuthenticated = await authenticateWithBiometrics();
      if (!isAuthenticated) {
        if (mounted) {
          setState(() => status = "❌ Biometric authentication failed. Attendance request denied.");
        }
        return;
      }
        if (mounted) {
          setState(() => _hasProvidedBiometrics = true);
        }
      

    }
  
    // Step 2: Check location permission status
    bool hasPermission = await checkAndRequestLocationPermission();
    debugPrint("HAS PERMISSION IS $hasPermission");
    

    // Step 3: Get the current location
    debugPrint("Before GETTING CURRENT POSITION");
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    debugPrint("CURRENT POSITION IS $position");
    if (mounted) {
      setState(() => location = position);
    }

    // Step 4: Fetch token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      if (mounted) {
        setState(() => status = "❌ Error: No token found!");
      }
      return;
    }

    // Step 5: Send location coordinates to the server
    final response = await http.post(
      Uri.parse('$VmURL/api/attendance/send-coordinates'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'roomNo': data['roomNo'],
        'latitude': position.latitude,
        'longitude': position.longitude,
        'email': email,
      }),
    );

    debugPrint("SENDING COORDINATES");

    // Step 6: Handle API response
    final responseData = json.decode(response.body);
    if (response.statusCode == 200) {
      if (mounted) {
        setState(() {
          status = "📌 Attendance ${responseData['status']}: ${responseData['message']}";
        });
      }
    } else {
      if (mounted) {
        setState(() => status = "❌ Failed to record attendance: ${responseData['message']}");
      }
    }
  } catch (e) {
    debugPrint("❌ Error handling attendance request: $e");
    if (mounted) {
      setState(() => status = "❌ Failed to record attendance: ${e.toString()}");
    }
  }
}

// Helper function to check and request location permissions
Future<bool> checkAndRequestLocationPermission() async {
  debugPrint("Checking location permission...");

  LocationPermission permission = await Geolocator.checkPermission();
debugPrint("Getting permission");
  // If permission is denied, request it
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    return false;
  }

  // If denied forever, return false
  if (permission == LocationPermission.deniedForever) {
    debugPrint("Location permission permanently denied!");
    return false;
  }

  // If granted while in use, attempt to request background access
  if (permission == LocationPermission.whileInUse) {
    debugPrint("Requesting background location permission...");
    
    debugPrint("returning true");
    return true;
  }

  // Check if we have full (background) access
  return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
}


  Future<void> fetchAttendanceHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() => status = "❌ Error: No token found!");
        return;
      }

      // Fetch attendance history
      final response = await http.get(
        Uri.parse('$VmURL/api/attendance/student-history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          attendanceHistory = List<Map<String, dynamic>>.from(data['attendanceHistory']);
          print("Attendance history fetched: $attendanceHistory");
          isLoadingHistory = false;
        });
      } else {
       
      }
    } catch (e) {
      print("❌ Error fetching attendance history: $e");
    }
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
      backgroundColor: const Color.fromARGB(255, 110, 169, 228),
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            fetchAttendanceHistory(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Profile Picture
                      CircleAvatar(
                        radius: 40,
                        child: Icon(Icons.person, size: 40), // Default profile icon
                      ),
                      const SizedBox(width: 16),
                      // Student Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $_studentName!',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Roll No: $_rollNo',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Branch: $_branch',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Attendance History Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.blue.shade800,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceHistoryScreen(
                          attendanceHistory: attendanceHistory,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'View Attendance History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attendance Status
              if (status.isNotEmpty && status != "Waiting for attendance request...")
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.blue.shade800,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_teacherName != null && _teacherEmail != null)
                          Card(
                            margin: const EdgeInsets.only(top: 16),
                            color: Colors.green.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Teacher is Live',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Teacher: $_teacherName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Email: $_teacherEmail',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
class AttendanceHistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> attendanceHistory;

  const AttendanceHistoryScreen({Key? key, required this.attendanceHistory}) : super(key: key);

  @override
  _AttendanceHistoryScreenState createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late List<Map<String, dynamic>> _attendanceHistory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _attendanceHistory = widget.attendanceHistory;
  }

  // Function to refresh attendance history
  Future<void> _refreshAttendanceHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: No token found!')),
        );
        return;
      }

      // Fetch updated attendance history
      final response = await http.get(
        Uri.parse('$VmURL/api/attendance/student-history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _attendanceHistory = List<Map<String, dynamic>>.from(data['attendanceHistory']);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to fetch attendance history: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error fetching attendance history: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 110, 169, 228),
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAttendanceHistory,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _attendanceHistory.length,
                itemBuilder: (context, index) {
                  final record = _attendanceHistory[index];
                  return Card(
                    color: Colors.blue.shade800,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date
                          Text(
                            'Date: ${record['date'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Teacher Name
                          Text(
                            'Teacher: ${record['teacher']['name'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Session Type
                          Text(
                            'Session Type: ${record['sessionType'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Status
                          Row(
                            children: [
                              Text(
                                'Status: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                record['status'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: record['status'] == 'Present'
                                      ? Colors.green
                                      : record['status'] == 'Late'
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
} 