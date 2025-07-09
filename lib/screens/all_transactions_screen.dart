import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  final Logger _logger = Logger();
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _sentTransactionsSubscription;
  StreamSubscription<QuerySnapshot>? _receivedTransactionsSubscription;
  bool _showRecentOnly = false; // Toggle for recent vs all transactions

  @override
  void initState() {
    super.initState();
    _fetchAllTransactions();
  }

  @override
  void dispose() {
    _sentTransactionsSubscription?.cancel();
    _receivedTransactionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllTransactions() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.w('No current user found, cannot fetch all transactions.');
      setState(() {
        _isLoading = false;
      });
      _showMessageBox(context, 'Please log in to view transactions.');
      return;
    }

    _logger.d('Fetching all transactions for UID: ${currentUser.uid}');

    // Cancel existing subscriptions before setting up new ones to avoid duplicates
    _sentTransactionsSubscription?.cancel();
    _receivedTransactionsSubscription?.cancel();

    // Listen to sent transactions
    _sentTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('senderUid', isEqualTo: currentUser.uid)
        .where('timestamp', isGreaterThanOrEqualTo: _showRecentOnly ? Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))) : Timestamp.fromDate(DateTime(1970)))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async { // Make the listener callback async
      _logger.d('Received ${snapshot.docs.length} sent transaction updates.');
      await _updateAllTransactions(snapshot.docs, isSender: true); // Await the update
    }, onError: (error) {
      _logger.e('Error listening to sent transactions: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessageBox(context, 'Error loading sent transactions: $error');
      }
    });

    // Listen to received transactions
    _receivedTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('receiverUid', isEqualTo: currentUser.uid) // Corrected to receiverUid as per your previous code
        .where('timestamp', isGreaterThanOrEqualTo: _showRecentOnly ? Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))) : Timestamp.fromDate(DateTime(1970)))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async { // Make the listener callback async
      _logger.d('Received ${snapshot.docs.length} received transaction updates.');
      await _updateAllTransactions(snapshot.docs, isSender: false); // Await the update
    }, onError: (error) {
      _logger.e('Error listening to received transactions: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showMessageBox(context, 'Error loading received transactions: $error');
      }
    });

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Changed to async to allow awaiting user data fetches
  Future<void> _updateAllTransactions(List<QueryDocumentSnapshot> docs, {required bool isSender}) async {
    List<Map<String, dynamic>> processedTransactions = [];
    List<Future<Map<String, dynamic>>> futures = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        _logger.w('Skipping transaction due to null data: ${doc.id}');
        continue;
      }

      final amount = (data['amount'] as num?)?.toDouble();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final description = data['description'] as String? ?? '';

      if (amount == null || timestamp == null) {
        _logger.w('Skipping transaction due to missing amount or timestamp: ${doc.id}');
        continue;
      }

      if (isSender) {
        // Corrected: Use 'receiverName' for sent transactions as stored in Firestore
        final receiverName = data['receiverName'] as String? ?? 'Unknown'; // CHANGED: from recipientName to receiverName
        processedTransactions.add({
          'id': doc.id,
          'timestamp_raw': timestamp,
          'icon': Icons.arrow_outward,
          'name': 'To $receiverName', // CHANGED: Using receiverName
          'date': DateFormat('MMM dd, hh:mm a').format(timestamp),
          'amount': '-₦${amount.toStringAsFixed(2)}',
          'statusColor': Colors.redAccent,
          'description': description,
        });
      } else {
        // For received transactions, fetch sender's name asynchronously
        futures.add(_getSenderNameForTransaction(doc.id, data, timestamp, amount, description));
      }
    }

    // Wait for all sender name lookups to complete for received transactions
    if (futures.isNotEmpty) {
      final resolvedReceivedTransactions = await Future.wait(futures);
      processedTransactions.addAll(resolvedReceivedTransactions);
    }

    if (mounted) {
      setState(() {
        // Remove old transactions from this type (sent or received) and add new ones
        // This ensures we always have the latest from each stream
        _allTransactions.removeWhere((t) =>
            isSender ? t['icon'] == Icons.arrow_outward : t['icon'] == Icons.arrow_downward);
        _allTransactions.addAll(processedTransactions);

        // Sort all transactions by timestamp (descending)
        _allTransactions.sort((a, b) => (b['timestamp_raw'] as DateTime).compareTo(a['timestamp_raw'] as DateTime));
      });
      _logger.d('Updated _allTransactions list size: ${_allTransactions.length}');
    }
  }

  // Helper function to fetch sender name for a received transaction
  Future<Map<String, dynamic>> _getSenderNameForTransaction(
      String docId,
      Map<String, dynamic> data,
      DateTime timestamp,
      double amount,
      String description) async {
    String senderName = 'Unknown';
    final senderUid = data['senderUid'] as String?;

    if (senderUid != null) {
      try {
        DocumentSnapshot senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(senderUid)
            .get();

        if (senderDoc.exists && senderDoc.data() != null) {
          final senderData = senderDoc.data() as Map<String, dynamic>;
          final firstName = senderData['firstName'] as String? ?? '';
          final lastName = senderData['lastName'] as String? ?? '';
          senderName = '$firstName $lastName'.trim();
          if (senderName.isEmpty) senderName = 'Unknown';
        }
      } catch (error) {
        _logger.w('Error fetching sender name for UID $senderUid: $error');
      }
    }

    return {
      'id': docId,
      'timestamp_raw': timestamp,
      'icon': Icons.arrow_downward,
      'name': 'From $senderName',
      'date': DateFormat('MMM dd, hh:mm a').format(timestamp),
      'amount': '+₦${amount.toStringAsFixed(2)}',
      'statusColor': Colors.green,
      'description': description,
    };
  }

  void _toggleRecentTransactions() {
    setState(() {
      _showRecentOnly = !_showRecentOnly;
      _allTransactions.clear(); // Clear current list to refetch
      _fetchAllTransactions(); // Refetch with new filter
    });
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

  Widget _buildTransactionItem({
    required IconData icon,
    required String name,
    required String date,
    required String amount,
    required Color statusColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _toggleRecentTransactions,
              child: Text(
                _showRecentOnly ? 'Show All' : 'Recent',
                style: const TextStyle(
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF)))
          : _allTransactions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_outlined, color: Colors.white54, size: 50),
                      SizedBox(height: 20),
                      Text(
                        'No transactions to display yet.',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _allTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _allTransactions[index];
                    return _buildTransactionItem(
                      icon: transaction['icon'] as IconData,
                      name: transaction['name'] as String,
                      date: transaction['date'] as String,
                      amount: transaction['amount'] as String,
                      statusColor: transaction['statusColor'] as Color,
                      description: transaction['description'] as String,
                    );
                  },
                ),
    );
  }
}
