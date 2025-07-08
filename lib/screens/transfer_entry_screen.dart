import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class TransferEntryScreen extends StatefulWidget {
  const TransferEntryScreen({super.key});

  @override
  State<TransferEntryScreen> createState() => _TransferEntryScreenState();
}

class _TransferEntryScreenState extends State<TransferEntryScreen> {
  final Logger _logger = Logger();
  final TextEditingController _accountNumberController = TextEditingController();
  bool _isLoading = false;
  String? _recipientName; // Stores recipient's name after lookup
  String? _recipientUid; // Stores recipient's UID after lookup
  String? _foundPhoneNumber; // Stores the found phone number (cleaned)

  @override
  void dispose() {
    _accountNumberController.dispose();
    super.dispose();
  }

  // Helper to format phone number for lookup (remove non-digits, add +234 if missing)
  String _formatPhoneNumberForLookup(String rawNumber) {
    String cleanedNumber = rawNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedNumber.startsWith('0') && cleanedNumber.length == 11) {
      // If it starts with 0 and is 11 digits (e.g., 080...)
      return '+234${cleanedNumber.substring(1)}';
    } else if (cleanedNumber.length == 10 && !cleanedNumber.startsWith('0')) {
      // If it's 10 digits and doesn't start with 0 (e.g., 80...)
      return '+234$cleanedNumber';
    } else if (cleanedNumber.startsWith('+234') && cleanedNumber.length >= 13) {
      // Already in international format
      return cleanedNumber;
    }
    return cleanedNumber; // Return as is if format is unexpected
  }

  Future<void> _lookupAccount() async {
    final String rawInput = _accountNumberController.text.trim();
    if (rawInput.isEmpty) {
      _showMessageBox(context, 'Please enter an account number.');
      return;
    }

    final String formattedPhoneNumber = _formatPhoneNumberForLookup(rawInput);
    if (formattedPhoneNumber.length < 10) { // Basic length check for a valid phone number
      _showMessageBox(context, 'Please enter a valid phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _recipientName = null; // Clear previous results
      _recipientUid = null;
      _foundPhoneNumber = null;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found for account lookup.');
      _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
      setState(() { _isLoading = false; });
      return;
    }

    // Prevent user from sending money to themselves
    if (formattedPhoneNumber == currentUser.phoneNumber) {
      _showMessageBox(context, 'You cannot send money to your own account.');
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: formattedPhoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final String firstName = userData['firstName'] ?? '';
        final String lastName = userData['lastName'] ?? '';
        setState(() {
          _recipientName = '$firstName $lastName'.trim();
          _recipientUid = querySnapshot.docs.first.id;
          _foundPhoneNumber = formattedPhoneNumber; // Store the found & formatted number
        });
        _logger.i('Recipient found: $_recipientName (UID: $_recipientUid)');
      } else {
        _showMessageBox(context, 'Account not found. Please check the number.');
        _logger.w('Account not found for number: $formattedPhoneNumber');
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error during account lookup: ${e.message}');
      _showMessageBox(context, 'Error looking up account: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred during account lookup: $e');
      _showMessageBox(context, 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToAmountScreen() {
    if (_recipientName != null && _recipientUid != null && _foundPhoneNumber != null) {
      Navigator.pushNamed(
        context,
        '/transfer_amount',
        arguments: {
          'recipientName': _recipientName,
          'recipientPhoneNumber': _foundPhoneNumber,
          'recipientUid': _recipientUid,
          'bankName': 'NexPay Wallet', // Always NexPay Wallet for internal transfers
        },
      );
    } else {
      _showMessageBox(context, 'Please lookup and select a valid recipient first.');
    }
  }

  void _showMessageBox(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Information'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white54 : Colors.grey[600];
    final inputFillColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100];
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Transfer', style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter account number',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter the recipient\'s phone number to find their NexPay Wallet account.',
              style: TextStyle(
                color: hintColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Account Number',
                hintStyle: TextStyle(color: hintColor),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2.0),
                ),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: Color(0xFF007AFF)),
                      )
                    : IconButton(
                        icon: Icon(Icons.search, color: hintColor),
                        onPressed: _lookupAccount,
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (_recipientName != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bank List',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: cardColor,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
                      title: Text('NexPay Wallet', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                      subtitle: Text(_recipientName!, style: TextStyle(color: hintColor)),
                      trailing: Icon(Icons.check_circle, color: Colors.green),
                      onTap: () {
                        // In a real scenario, this might select a bank.
                        // Here, it just confirms NexPay Wallet is selected.
                        _logger.i('NexPay Wallet selected for $_recipientName');
                        _navigateToAmountScreen();
                      },
                    ),
                  ),
                ],
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recipientName != null && !_isLoading ? _navigateToAmountScreen : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
