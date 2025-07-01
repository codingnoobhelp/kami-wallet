import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/phone_entry_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/personal_info_screen.dart';
import 'screens/success_screen.dart';
import 'screens/passcode_setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://kmkuckemyegjdrwdffil.supabase.co', // Replace with your actual URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtta3Vja2VteWVnamRyd2RmZmlsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEzNTIwNzAsImV4cCI6MjA2NjkyODA3MH0.vyj6G5ceEpxHjohY_FkLQsjiJjO2l7fstF4MdlzRUbA', // Replace with your actual anon key
  );
  
  runApp(Wallet());
}

// Global Supabase client for easy access throughout the app
final supabase = Supabase.instance.client;

class Wallet extends StatelessWidget {
  const Wallet({super.key}); //added

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      // For testing - directly show HomeScreen
      home: HomeScreen(
        phoneNumber: '1234567890',   // dummy phone number
        initialBalance: 1000.0,      // dummy balance
      ),
      
      // Your original routes (uncomment when ready to use full flow)
      // initialRoute: '/phone',
      // routes: {
      //   '/phone': (context) => const PhoneEntryPage(),
      //   '/otp': (context) => const OtpVerificationPage(),
      //   '/personal': (context) => const PersonalInfoPage(),
      //   '/success': (context) => const SuccessPage(),
      //   '/passcode': (context) => const PasscodeSetupPage(),
      //   '/home': (context) {
      //     final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      //     final String phoneNumber = args?['phoneNumber'] as String? ?? 'N/A';
      //     final double initialBalance = args?['initialBalance'] as double? ?? 0.0;
      //
      //     return HomeScreen(
      //       phoneNumber: phoneNumber,
      //       initialBalance: initialBalance,
      //     );
      //   },
      // },
      
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
    );
  }
}