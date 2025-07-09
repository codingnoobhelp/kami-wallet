import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter_application_1/screens/qr_code_scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for local storage
import 'screens/phone_entry_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/personal_info_screen.dart';
import 'screens/success_screen.dart';
import 'screens/pin_setup_screen.dart'; // Corrected import for 4-digit transaction PIN
import 'screens/home_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/login_screen.dart'; // User Login Screen (6-digit login passcode)
import 'screens/biometric_settings_screen.dart';
import 'screens/account_settings_screen.dart';
import 'screens/pay_merchant_screen.dart';
import 'screens/transfer_entry_screen.dart';
import 'screens/transfer_amount_screen.dart';
import 'screens/transfer_confirmation_screen.dart';
import 'screens/transfer_success_screen.dart';
import 'screens/transaction_pin_screen.dart';
import 'screens/all_transactions_screen.dart'; // NEW: Import AllTransactionsScreen
import 'screens/login_passcode_screen.dart'; // Corrected import for 6-digit login passcode management
import 'screens/role_selection_screen.dart'; // Import RoleSelectionScreen
import 'screens/merchant_login_screen.dart'; // Import MerchantLoginPage
import 'screens/qr_generator_screen.dart'; // NEW: Import QrGeneratorScreen
import 'screens/merchant_signup_screen.dart'; // NEW: Import MerchantSignupScreen
import 'screens/merchant_home_screen.dart'; // NEW: Import MerchantHomeScreen
import 'screens/merchant_profile_screen.dart'; // NEW: Import MerchantProfileScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const Wallet());
}

final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

class Wallet extends StatelessWidget {
  const Wallet({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/role_selection', // Starting point: RoleSelectionScreen
      routes: {
        '/phone': (context) => const PhoneEntryPage(),
        '/otp': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return OtpVerificationPage(
            phoneNumber: args['phoneNumber'],
            verificationId: args['verificationId'],
            userExists: args['userExists'], // Pass userExists to OTP page
          );
        },
        '/personal': (context) => const PersonalInfoPage(),
        '/pin_setup': (context) => const PinSetupPage(), // Route for 4-digit transaction PIN setup
        '/success': (context) => const SuccessPage(),
        '/home': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final String phoneNumber = args?['phoneNumber'] as String? ?? 'N/A';
          final double initialBalance = args?['initialBalance'] as double? ?? 0.0;
          return HomeScreen(
            phoneNumber: phoneNumber,
            initialBalance: initialBalance,
          );
        },
        '/profile': (context) => const UserProfileScreen(),
        '/login': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return LoginPage(
            phoneNumber: args?['phoneNumber'] as String?, // Pass phone number to login screen
          );
        },
        '/merchant_login': (context) => const MerchantLoginPage(), // Merchant Login Page
        '/merchant_signup': (context) => const MerchantSignupScreen(), // NEW: Route for MerchantSignupScreen
        '/merchant_home': (context) { // NEW: Route for MerchantHomeScreen
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MerchantHomeScreen(
            merchantId: args['merchantId'],
          );
        },
        '/merchant_profile': (context) => const MerchantProfileScreen(), // NEW: Route for MerchantProfileScreen
        '/biometric_settings': (context) => const BiometricSettingsScreen(),
        '/account_settings': (context) => const AccountSettingsScreen(),
        //'/pay_merchant': (context) => const PayMerchantScreen(), // Assuming this exists or will be created
        '/transfer_entry': (context) => const TransferEntryScreen(),
        '/transfer_amount': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TransferAmountScreen(
            recipientName: args['recipientName'],
            recipientPhoneNumber: args['recipientPhoneNumber'],
            recipientUid: args['recipientUid'],
            bankName: args['bankName'],
          );
        },
        '/transfer_confirmation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TransferConfirmationScreen(
            recipientName: args['recipientName'],
            recipientPhoneNumber: args['recipientPhoneNumber'],
            recipientUid: args['recipientUid'],
            bankName: args['bankName'],
            amount: args['amount'],
            description: args['description'],
          );
        },
        '/transaction_pin': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TransactionPinScreen(
            recipientName: args['recipientName'],
            recipientPhoneNumber: args['recipientPhoneNumber'],
            recipientUid: args['recipientUid'],
            bankName: args['bankName'],
            amount: args['amount'],
            description: args['description'],
          );
        },
        '/transfer_success': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return TransferSuccessScreen(
            amount: args['amount'],
            recipientName: args['recipientName'],
            recipientPhoneNumber: args['recipientPhoneNumber'],
            bankName: args['bankName'],
          );
        },
        '/all_transactions': (context) => const AllTransactionsScreen(),
        '/qr_scanner': (context) => const QrScannerScreen(), // NEW: Route for QrScannerScreen
        '/qr_generator': (context) => const QrGeneratorScreen(), // NEW: Route for QrGeneratorScreen
        '/login_passcode': (context) => const LoginPasscodeScreen(), // Route for 6-digit login passcode management
        '/role_selection': (context) => RoleSelectionScreen(), // Role Selection Screen
      },
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
    );
  }
}