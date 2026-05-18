import 'package:digital_wall/digital_wall.dart';
// import 'package:digital_wall/screen/Login/login.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      // home: Login(),
      home: Dashboard(),
    );
  }
}
