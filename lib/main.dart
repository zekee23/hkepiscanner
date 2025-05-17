import 'package:attendancehkepi/admin/admin_home_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this
import 'package:attendancehkepi/screens/loginpage.dart'; // Your login page
import 'admin/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance HKEPI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      initialRoute: '/loginpage',
      routes: {
        '/loginpage': (context) => const LoginPage(),
        // Add more routes here if needed, e.g.:
        '/dashboard': (context) => const AdminHomePage(),
      },
    );
  }
}
