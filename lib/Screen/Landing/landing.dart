import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Login/login.dart';

class LandingPage extends StatefulWidget {
  @override
  _LandingPageState createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState(){
    super.initState();

    Timer(Duration(seconds: 5),(){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context)=>LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF39495F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/tdg_logo.png',
              width: 200,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            const Text(
              'TDG Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
