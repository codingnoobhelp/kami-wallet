import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For currency formatting

class TransferConfirmationScreen extends StatefulWidget {
  final String recipientName;
  final String recipientPhoneNumber;
  final String recipientUid;
  final String bankName;
  final double amount;
  final String description;

  const TransferConfirmationScreen({
    super.key,
    required this.recipientName,
    required this.recipientPhoneNumber,
    required this.recipientUid,
    required this.bankName,
    required this.amount,
    required this.description,
  });

  @override
  State<TransferConfirmationScreen> createState() => _TransferConfirmationScreenState();
}

class _TransferConfirmationScreenState extends State<TransferConfirmationScreen> {
  final Logger _logger = Logger();
  // Removed _isTransferring state as the actual transfer logic moves to TransactionPinScreen

  // Helper function to format phone number for display (remove country code prefix)
  String _formatPhoneNumberForDisplay(String rawPhoneNumber) {
    if (rawPhoneNumber.startsWith('+234')) {
      String withoutCountryCode = rawPhoneNumber.substring(4);
      if (withoutCountryCode.startsWith('0')) {
        return withoutCountryCode.substring(1);
      }
      return withoutCountryCode;
    }
    return rawPhoneNumber;
  }

  // This function now only navigates to the PIN entry screen
  void _navigateToPinEntry() {
    _logger.i('Navigating to TransactionPinScreen for PIN entry.');
    Navigator.pushNamed(
      context,
      '/transaction_pin', // New route for transaction PIN
      arguments: {
        'recipientName': widget.recipientName,
        'recipientPhoneNumber': widget.recipientPhoneNumber,
        'recipientUid': widget.recipientUid,
        'bankName': widget.bankName,
        'amount': widget.amount,
        'description': widget.description,
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
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;

    // Format amount for display
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final String formattedAmount = currencyFormatter.format(widget.amount);

    // Format recipient phone number for display
    final String displayedRecipientPhoneNumber = _formatPhoneNumberForDisplay(widget.recipientPhoneNumber);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Confirm Transfer', style: TextStyle(color: textColor)),
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
              'Please review the transfer details:',
              style: TextStyle(
                color: hintColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Recipient Name:', widget.recipientName, textColor, hintColor ?? Colors.grey),
                    _buildDetailRow('Account Number:', displayedRecipientPhoneNumber, textColor, hintColor ?? Colors.grey),
                    _buildDetailRow('Bank Name:', widget.bankName, textColor, hintColor ?? Colors.grey),
                    const Divider(height: 20, thickness: 1),
                    _buildDetailRow('Amount:', formattedAmount, textColor, hintColor ?? Colors.grey, isAmount: true),
                    if (widget.description.isNotEmpty)
                      _buildDetailRow('Description:', widget.description, textColor, hintColor ?? Colors.grey),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToPinEntry, // Now navigates to PIN entry
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text( // No longer needs _isTransferring check here
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

  Widget _buildDetailRow(String label, String value, Color textColor, Color hintColor, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: hintColor, fontSize: 15),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
