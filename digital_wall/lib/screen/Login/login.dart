import 'dart:convert';
// import 'package:digital_wall/screen/Admin/admin.dart';
// import 'package:digital_wall/screen/Modifier/modifier.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/dropdown.dart';
import '../Dashboard/dashboard.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedRole;
  final List<String> _roles = ['admin', 'modifier'];

  @override
  void initState() {
    super.initState();
    // Auto-login check is now handled in Landing page
  }

  Future<void> loginUser() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();
    final String role = _selectedRole ?? '';

    print("uname: $username, password: $password, role: $role");

    if (username.isEmpty || password.isEmpty || role.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final Uri url = Uri.parse('http://192.168.1.22:8000/auth/login');
    try {
      print("Making request....");
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          // "authentication": "Bearer $token",
        },
        body: jsonEncode({
          'uname': username,
          'password': password,
          'role': role,
        }),
      );
      print('Response status::::::::: ${response.statusCode}');
      print('Response body::::::::::: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['accessToken'] as String?;
        final userName = data['uname'] as String?;

        if (token == null || token.isEmpty) {
          throw Exception("Token not found in response");
        }

        // Save token and user info to SharedPreferences for persistent login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', token);
        await prefs.setString('uname', userName ?? username); // Use username as fallback
        await prefs.setString('userRole', role);

        print('Saved Token: $token');
        print('Saved User: $userName');
        print('Saved Role: $role');

        print('Navigating to Dashboard...');
        try {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const Dashboard(),
              // builder: (context) => role == 'admin' ? const Admin() : const Modifier(),
            ),
          );
          print('Navigation completed successfully');
        } catch (e) {
          print('Navigation error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Navigation error: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter valid Username and Password!')),
        );
      }
    } catch (e) {
      print('Login error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show login form - auto-login check is in Landing page
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F36),
      appBar: AppBar(
        title: const Text(
          'Login',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Username',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              style: TextStyle(color: Colors.black),
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Dropdown(
              items: _roles,
              selectedItem: _selectedRole,
              label: 'Select Role',
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE3AA1D),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                loginUser();
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
