import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CancelClassPage extends StatefulWidget {
  const CancelClassPage({Key? key}) : super(key: key);

  @override
  _CancelClassPageState createState() => _CancelClassPageState();
}

class _CancelClassPageState extends State<CancelClassPage> {
  String? _selectedBranch;
  String? _selectedAdmissionYear;
  String _selectedType = "class"; // Default class type
DateTime? _selectedDate;
  final String VmURL = "http://35.193.196.5:5000";

  final String localURL = "http://10.0.10.5:5000";
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now(); // Automatically set today's date
  }
  bool isLoading = false;
  String error = '';

  Future<void> cancelClass() async {
    if (_selectedBranch == null || _selectedAdmissionYear == null) {
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
        Uri.parse('$VmURL/api/attendance/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'branch': _selectedBranch,
          'admissionYear': _selectedAdmissionYear,
          'type': _selectedType,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Class canceled. All students marked as present on $_selectedDate.")),
        );
      } else {
        throw Exception("Failed to cancel class");
      }
    } catch (e) {
      setState(() {
        error = 'Failed to cancel class. Please try again.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cancel Class", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color.fromARGB(255, 99, 190, 250),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Branch Dropdown
              Text("Branch", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedBranch,
                hint: Text("Select Branch"),
                items: ['cse', 'dsai', 'ece'].map((String branch) {
                  return DropdownMenuItem<String>(
                    value: branch,
                    child: Text(branch),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedBranch = newValue!;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              SizedBox(height: 36),

              // Admission Year Dropdown
              Text("Admission Year", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedAdmissionYear,
                hint: Text("Select Admission Year"),
                items: ['2020', '2021', '2022', '2023', '2024', '2025'].map((String year) {
                  return DropdownMenuItem<String>(
                    value: year,
                    child: Text(year),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedAdmissionYear = newValue!;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              SizedBox(height: 36),

              // Class Type Dropdown
              Text("Class Type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: <String>['tutorial', 'class', 'lab'].map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue!;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              SizedBox(height: 48),

              // Cancel Button
              Center(
                child: ElevatedButton(
                  onPressed: isLoading ? null : cancelClass,
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text("Cancel Class",style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Color.fromARGB(255, 99, 190, 250),
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
                ),
              ),

              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                      child: Text(error,
                          style: TextStyle(color: Colors.red, fontSize: 16))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
