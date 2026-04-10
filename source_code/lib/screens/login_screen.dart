// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'lawyer_home_screen.dart';
import 'manager_home_screen.dart';
import '../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  String _selectedRole = 'Lawyer';
  bool _isLoading = false;

  Future<void> _login() async {
    if (_idController.text.trim().isEmpty) {
      _showError('Please enter your ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final database = FirebaseDatabase.instance.ref();
      final prefs = await SharedPreferences.getInstance();

      if (_selectedRole == 'Lawyer') {
        final snapshot = await database.child('lawyers/${_idController.text.trim()}').get();

        if (snapshot.exists) {
          // Update FCM token for notifications
          //final fcmToken = await NotificationService().getFCMToken();
          // if (fcmToken != null) {
          //   await database.child('lawyers/${_idController.text.trim()}/fcmToken').set(fcmToken);
          // }
          // Save login state
          await prefs.setString('role', 'Lawyer');
          await prefs.setString('id', _idController.text.trim());

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LawyerHomeScreen(lawyerId: _idController.text.trim()),
              ),
            );
          }
        } else {
          _showError('Invalid Lawyer ID');
        }
      } else {
        final snapshot = await database.child('managers/${_idController.text.trim()}').get();

        if (snapshot.exists) {
          // Save login state
          await prefs.setString('role', 'Manager');
          await prefs.setString('id', _idController.text.trim());

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ManagerHomeScreen(managerId: _idController.text.trim()),
              ),
            );
          }
        } else {
          _showError('Invalid Manager ID');
        }
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.gavel,
                size: 80,
                color: Colors.blueGrey[900],
              ),
              const SizedBox(height: 20),
              Text(
                'Courtroom Manager',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Select Role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: ['Lawyer', 'Manager'].map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedRole = value!);
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: '${_selectedRole} ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'LOGIN',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }
}