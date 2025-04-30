import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'signup_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _errorMessage = '';
  String _selectedRole = 'student';
  final String VmURL = "http://35.193.196.5:5000";
  final String localURL = "http://10.0.10.5:5000";
  
Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    final response = await http.post(
      Uri.parse('$VmURL/api/${_selectedRole}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    final responseData = json.decode(response.body);
    print("API Response: $responseData"); // Debug log

    if (response.statusCode == 200) {
      // Save token, role, and user details to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', responseData['token']);
      await prefs.setString('email', _emailController.text); 
        if(_selectedRole == 'teacher'){
           await prefs.setString('role', 'teacher'); 
          if(responseData['teacher'] != null){
        final teacher = responseData['teacher'];
        print("This is response data: $teacher");
          await prefs.setString('TeacherName', teacher['name'] ?? 'Teacher'); // Save name
        await prefs.setString('TeacherEmail', teacher['email'] ?? 'N/A');

        }
        }
      // Save name and rollNo from userDetails
      if(_selectedRole == 'student'){
       
      if (responseData['userDetails'] != null) {
        final userDetails = responseData['userDetails'];
        print("This is response data: $userDetails");
                   await prefs.setString('role', 'student'); 

        await prefs.setString('name', userDetails['name'] ?? 'Student'); // Save name
        await prefs.setString('rollNo', userDetails['rollNo'] ?? 'N/A');
        await prefs.setString('branch', userDetails['branch'] ?? 'N/A');  // Save roll number
      }

      print("User details saved to SharedPreferences:"); // Debug log
      print("Name: ${responseData['userDetails']['name']}");
      print("Roll No: ${responseData['userDetails']['rollNo']}");
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => _selectedRole == 'student'
              ? const StudentDashboard()
              : const TeacherDashboard(),
        ),
      );
    } else {
      setState(() {
        _errorMessage = responseData['message'] ?? 'Login failed';
        _isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Network error: $e';
      _isLoading = false;
    });
  }
}
  @override
  Widget build(BuildContext context) {
    // The rest of your build method remains unchanged
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo
                  Icon(
                    Icons.school,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                 
                  // Title
                  Text(
                    'College Attendance App',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                 
                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade800),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_errorMessage.isNotEmpty) const SizedBox(height: 16),
                 
                  // Role Selector
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.light ? Colors.grey[300]! : Colors.grey[700]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'student'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'student'
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                              ),
                              child: Text(
                                'Student',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRole == 'student'
                                      ? Colors.white
                                      : Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRole = 'teacher'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'teacher'
                                    ? Theme.of(context).primaryColor
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                              ),
                              child: Text(
                                'Teacher',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRole == 'teacher'
                                      ? Colors.white
                                      :Theme.of(context).textTheme.bodyMedium?.color
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                 
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                 
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                 
                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('LOGIN'),
                  ),
                  const SizedBox(height: 16),
                 
                  // Register Link
                 TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterScreen()),
    );
  },
  child: const Text("Don't have an account? Register"),
)

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
 
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

