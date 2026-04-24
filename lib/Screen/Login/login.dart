import 'package:flutter/material.dart';
import 'package:overview_app/Screen/SOPSearch/sopSearch.dart';
import 'LoginService/loginService.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController unameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoggingIn = false;

  @override
  void dispose() {
    unameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> checkAlreadyLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    if (token != null && token.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SOPSearch()),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    checkAlreadyLoggedIn();
  }

  void handleLogin() async {
    if (_isLoggingIn) return;

    String uname = unameController.text.trim();
    String password = passwordController.text.trim();

    // 1. Check empty fields
    if (uname.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter username and password")));
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      // 2. Call API
      final response = await LoginService().login(
        username: uname,
        password: password,
      );

      String token = response.data["data"]["token"];

      // print("LOGIN TOKEN: $token"); // debug

      // 🔹 4. Save token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token);
      await prefs.setString("UserName", uname);

      print("SAVED TOKEN: ${prefs.getString("token")}"); // verify

      // 3. Success message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Successful")));

      // 4. Go to next page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SOPSearch()),
      );
    } catch (e) {
      // 5. Error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Failed")));
    }

    // 6. Stop loading
    setState(() {
      _isLoggingIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 700;
    final horizontalPadding = isTablet ? 32.0 : 16.0;
    final formMaxWidth = (screenWidth - (horizontalPadding * 2)).clamp(
      140.0,
      500.0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  child: Container(
                    width: formMaxWidth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color.fromARGB(255, 214, 224, 236),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Login",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 36 : 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Sign in to your account to continue",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 15,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 124, 123, 123),
                          ),
                        ),
                        SizedBox(height: isTablet ? 36 : 30),
                        TextField(
                          controller: unameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.person),
                            labelText: 'UserName',
                            labelStyle: const TextStyle(
                              color: Color.fromARGB(255, 57, 73, 95),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 22, 129, 218),
                                width: 2,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.lock),
                            labelText: 'Password',
                            labelStyle: const TextStyle(
                              color: Color.fromARGB(255, 57, 73, 95),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 22, 129, 218),
                                width: 2,
                              ),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF1565C0),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.35),
                              surfaceTintColor: Colors.transparent,
                            ),
                            child: _isLoggingIn
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white),
                                  )
                                : const Text('Sign In'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
