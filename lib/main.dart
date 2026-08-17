import 'package:flutter/material.dart';
import 'package:overview_app/Screen/Login/login.dart';
import 'package:overview_app/Services/DioServices.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Dioservices.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Overview',
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: LoginPage(),
    );
  }
}
