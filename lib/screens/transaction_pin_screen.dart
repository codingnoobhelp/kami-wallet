import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart';

class TransactionPinScreen extends StatefulWidget {
  final String recipientName;
  final String recipientPhoneNumber;
  final String recipientUid;
  final String bankName;
  final double amount;
  final String description;

  const TransactionPinScreen({
    super.key,
    required this.recipientName,
    required this.recipientPhoneNumber,
    required this.recipientUid,
    required this.bankName,
    required this.amount,
    required this.description,
  });

  @override
  State<TransactionPinScreen> createState() => _TransactionPinScreenState();
}

class _TransactionPinScreenState extends State<TransactionPinScreen> {
  final Logger _logger = Logger();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricEnabled = false;

  final defaultPinTheme = PinTheme(
    width: 60,
    height: 60,
    textStyle: const TextStyle(
      fontSize: 24,
      color: Colors.black,
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade400),
    ),
  );

  late final focusedPinTheme = defaultPinTheme.copyDecorationWith(
    border: Border.all(color: const Color(0xFF007AFF), width: 2),
    borderRadius: BorderRadius.circular(12),
  );

  late final submittedPinTheme = defaultPinTheme.copyWith(
    decoration: defaultPinTheme.decoration?.copyWith(
      color: Colors.grey[100],
    ),
  );

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _checkBiometricStatus() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            _isBiometricEnabled = userData?['biometricEnabled'] ?? false;
          });
        }
      }
    } catch (e) {
      _logger.e('Error checking biometric status: $e');
    }
  }

  Future<void> _verifyPinAndExecuteTransfer() async {
    if (_pinController.text.length != 4) {
      _showMessageBox(context, 'Please enter your 4-digit transaction PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found for transfer.');
      _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
      setState(() { _isLoading = false; });
      return;
    }

    final String enteredPinHash = _hashPin(_pinController.text);
    final String senderUid = currentUser.uid;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(senderUid).get();

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception("User document not found.");
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final String? storedTransactionPinHash = userData['transactionPinHash'];
      final bool transactionPinSet = userData['transactionPinSet'] ?? false;

      if (!transactionPinSet || storedTransactionPinHash == null) {
        _showMessageBox(context, 'Transaction PIN is not set. Please set it up in Account Settings.');
        setState(() { _isLoading = false; });
        return;
      }

      if (enteredPinHash != storedTransactionPinHash) {
        _showMessageBox(context, 'Incorrect transaction PIN. Please try again.');
        _pinController.clear();
        setState(() { _isLoading = false; });
        return;
      }

      _logger.i('Transaction PIN verified. Proceeding with transfer...');

      final senderDocRef = FirebaseFirestore.instance.collection('users').doc(senderUid);
      final recipientDocRef = FirebaseFirestore.instance.collection('users').doc(widget.recipientUid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final senderSnapshot = await transaction.get(senderDocRef);
        final recipientSnapshot = await transaction.get(recipientDocRef);

        if (!senderSnapshot.exists) {
          throw Exception("Sender account not found during transaction.");
        }
        if (!recipientSnapshot.exists) {
          throw Exception("Recipient account not found during transaction.");
        }

        double senderBalance = (senderSnapshot.data()?['accountBalance'] as num?)?.toDouble() ?? 0.0;
        double recipientBalance = (recipientSnapshot.data()?['accountBalance'] as num?)?.toDouble() ?? 0.0;

        if (senderBalance < widget.amount) {
          throw Exception("Insufficient balance. Transfer cancelled.");
        }

        transaction.update(senderDocRef, {'accountBalance': senderBalance - widget.amount});
        transaction.update(recipientDocRef, {'accountBalance': recipientBalance + widget.amount});

        final senderFirstName = senderSnapshot.data()?['firstName'] ?? '';
        final senderLastName = senderSnapshot.data()?['lastName'] ?? '';
        final senderName = '$senderFirstName $senderLastName'.trim();

        final newTransactionRef = FirebaseFirestore.instance.collection('transactions').doc();
        transaction.set(newTransactionRef, {
          'amount': widget.amount,
          'description': widget.description.isNotEmpty ? widget.description : 'Wallet Transfer',
          'timestamp': FieldValue.serverTimestamp(),
          'senderUid': senderUid,
          'receiverUid': widget.recipientUid,
          'senderPhoneNumber': currentUser.phoneNumber,
          'receiverPhoneNumber': widget.recipientPhoneNumber,
          'senderName': senderName,
          'receiverName': widget.recipientName,
        });

        _logger.i('Firestore transaction completed successfully.');
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/transfer_success',
          (route) => false,
          arguments: {
            'amount': widget.amount,
            'recipientName': widget.recipientName,
            'recipientPhoneNumber': widget.recipientPhoneNumber,
            'bankName': widget.bankName,
          },
        );
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error during PIN verification or transfer: ${e.message}');
      if (mounted) _showMessageBox(context, 'Transfer failed: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred during PIN verification or transfer: $e');
      if (mounted) _showMessageBox(context, 'Transfer failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_isBiometricEnabled) {
      _showMessageBox(context, 'Biometric authentication is not enabled. Please enable it in settings.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Biometric Confirmation'),
          content: const Text('Please authenticate with your fingerprint to confirm the transfer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to confirm the transfer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      Navigator.pop(context);

      if (authenticated) {
        _logger.i('Biometric authentication successful. Proceeding with transfer...');
        _verifyPinAndExecuteTransfer(); // Reuse the existing transfer logic
      } else {
        _logger.w('Biometric authentication cancelled or failed.');
        _showMessageBox(context, 'Biometric authentication failed. Please use your PIN.');
      }
    } catch (e) {
      Navigator.pop(context);
      _logger.e('Error during biometric authentication: $e');
      _showMessageBox(context, 'Error during biometric authentication: $e');
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

  void _onDigitPressed(String digit) {
    if (_pinController.text.length < 4) {
      _pinController.text += digit;
    }
    _logger.d('PIN input: ${_pinController.text}');
  }

  void _onBackspacePressed() {
    if (_pinController.text.isNotEmpty) {
      _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
    }
    _logger.d('PIN input: ${_pinController.text}');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white70 : Colors.black54;

    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final String formattedAmount = currencyFormatter.format(widget.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Enter Transaction PIN', style: TextStyle(color: textColor)),
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
              'Confirm transfer of $formattedAmount to ${widget.recipientName}',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please enter your 4-digit transaction PIN to complete the transfer.',
              style: TextStyle(
                color: hintColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Pinput(
                controller: _pinController,
                length: 4,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                obscureText: true,
                onCompleted: (pin) {
                  _logger.d('PIN input completed: $pin');
                  _verifyPinAndExecuteTransfer();
                },
                onChanged: (value) {
                  _logger.d('PIN input changed: $value');
                },
                cursor: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      width: 22,
                      height: 1,
                      color: const Color(0xFF007AFF),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Biometric Button (Bottom Left)
                if (_isBiometricEnabled)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _authenticateWithBiometrics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.fingerprint, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Pay with Fingerprint',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Empty space on the right to balance the layout
                const SizedBox(width: 100),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index < 9) {
                  return _buildKeypadButton('${index + 1}', () => _onDigitPressed('${index + 1}'));
                } else if (index == 10) {
                  return _buildKeypadButton('0', () => _onDigitPressed('0'));
                } else if (index == 11) {
                  return _buildKeypadButton(
                    '',
                    _onBackspacePressed,
                    icon: Icons.backspace_outlined,
                    buttonColor: Colors.red,
                    iconColor: Colors.white,
                  );
                } else {
                  return Container();
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPinAndExecuteTransfer,
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
                        'Confirm Transfer',
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

  Widget _buildKeypadButton(String text, VoidCallback onPressed, {IconData? icon, Color? buttonColor, Color? iconColor}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        decoration: BoxDecoration(
          color: buttonColor ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(50),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 30, color: iconColor ?? Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8))
            : Text(
                text,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
      ),
    );
  }
}