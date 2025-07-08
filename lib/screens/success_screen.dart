import 'package:flutter/material.dart';
import 'package:logger/logger.dart'; // Import logger

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Logger logger = Logger(); // Initialize logger

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    // Extract arguments. The 'name' argument will now be passed from PersonalInfoPage.
    String? userName = args?['name'] as String?; // Use a different variable name to avoid confusion with 'name' property
    final String? phoneNumber = args?['phoneNumber'] as String?;
    final double? initialBalance = args?['initialBalance'] as double?;

    void navigateToHome() {
      logger.d('Navigating to Home screen from SuccessPage. Phone: $phoneNumber, Balance: ${initialBalance ?? 0.0}');
      // Pass the extracted phone number and initial balance to the HomeScreen
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false, // Remove all previous routes
        arguments: {
          'phoneNumber': phoneNumber ?? 'N/A', // Use extracted phone number or default
          'initialBalance': initialBalance ?? 0.0, // Use extracted initial balance or default
        },
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to theme
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Placeholder for a success illustration or Confetti
            const SizedBox(height: 80),
            Center(
              child: Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).primaryColor, // Use primary color for success icon
                size: 120,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Congratulations, ${userName ?? 'User'}!', // Use userName here
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge!.color, // Adapts to theme
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Your account has been successfully created and secured.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium!.color, // Adapts to theme
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: navigateToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Black background
                  foregroundColor: Colors.white, // White text and icon color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Let\'s get in',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Keeping ConfettiWidget as a placeholder, as the actual confetti package isn't added
// If you want actual confetti, you'd add a package like 'confetti' and integrate it here.
class ConfettiWidget extends StatelessWidget {
  const ConfettiWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // This is a placeholder. You would typically use a package like 'confetti' here.
    return Container();
  }
}
