import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LoanTrackerApp());
}

class LoanTrackerApp extends StatelessWidget {
  const LoanTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loan Tracker',   
      debugShowCheckedModeBanner: false,
      
      // --- THEME SETTINGS ---
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Light grey background
        textTheme: GoogleFonts.poppinsTextTheme(), // Modern font
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      
      // --- AUTHENTICATION LOGIC ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If User is logged in, send them to Home with their UID
          if (snapshot.hasData) {
            return HomeScreen(uid: snapshot.data!.uid);
          }
          // Otherwise, show Login
          return const LoginScreen();
        },
      ),
    );
  }
}