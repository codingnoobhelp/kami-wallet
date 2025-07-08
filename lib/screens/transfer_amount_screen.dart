import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TransferAmountScreen extends StatefulWidget {
  final String recipientName;
  final String recipientPhoneNumber;
  final String recipientUid;
  final String bankName;

  const TransferAmountScreen({
    super.key,
    required this.recipientName,
    required this.recipientPhoneNumber,
    required this.recipientUid,
    required this.bankName,
  });

  @override
  State<TransferAmountScreen> createState() => _TransferAmountScreenState();
}

class _TransferAmountScreenState extends State<TransferAmountScreen> {
  final Logger _logger = Logger();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  double _currentUserBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserBalance(); // Fetch current user's balance
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserBalance() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to fetch balance.');
      return;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentUserBalance = (userData['accountBalance'] as num?)?.toDouble() ?? 0.0;
          });
        }
        _logger.i('Current user balance fetched: $_currentUserBalance');
      } else {
        _logger.w('Current user document not found. Balance defaulted to 0.');
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching current user balance: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred fetching current user balance: $e');
    }
  }

  void _navigateToConfirmationScreen() {
    final double? amount = double.tryParse(_amountController.text.trim());
    final String description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      _showMessageBox(context, 'Please enter a valid amount to send.');
      return;
    }

    if (amount > _currentUserBalance) {
      _showMessageBox(context, 'Insufficient balance. Your current balance is ₦${_currentUserBalance.toStringAsFixed(2)}.');
      return;
    }

    Navigator.pushNamed(
      context,
      '/transfer_confirmation',
      arguments: {
        'recipientName': widget.recipientName,
        'recipientPhoneNumber': widget.recipientPhoneNumber,
        'recipientUid': widget.recipientUid,
        'bankName': widget.bankName,
        'amount': amount,
        'description': description,
      },
    );
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
              'Sending to:',
              style: TextStyle(
                color: hintColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.recipientName,
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.bankName} - ${widget.recipientPhoneNumber}',
              style: TextStyle(
                color: hintColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Amount',
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
                prefixText: '₦ ', // Naira symbol
                prefixStyle: TextStyle(color: textColor, fontSize: 16),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descriptionController,
              keyboardType: TextInputType.text,
              maxLines: 2,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Description (Optional)',
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
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _navigateToConfirmationScreen,
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
                        'Send',
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
