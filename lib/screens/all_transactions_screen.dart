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

    // Listen to sent transactions
    _sentTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('senderUid', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _logger.d('Received ${snapshot.docs.length} sent transaction updates.');
      _updateAllTransactions(snapshot.docs, isSender: true);
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
        .where('recipientUid', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      _logger.d('Received ${snapshot.docs.length} received transaction updates.');
      _updateAllTransactions(snapshot.docs, isSender: false);
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

  void _updateAllTransactions(List<QueryDocumentSnapshot> docs, {required bool isSender}) {
    List<Map<String, dynamic>> currentStreamTransactions = [];

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
        final recipientName = data['recipientName'] as String? ?? 'Unknown';
        currentStreamTransactions.add({
          'id': doc.id,
          'timestamp_raw': timestamp,
          'icon': Icons.arrow_outward,
          'name': 'To $recipientName',
          'date': DateFormat('MMM dd, hh:mm a').format(timestamp),
          'amount': '-₦${amount.toStringAsFixed(2)}',
          'statusColor': Colors.redAccent,
          'description': description,
        });
      } else {
        // Fetch sender's name from users collection since senderName is not stored
        String senderName = 'Unknown';
        final senderUid = data['senderUid'] as String?;
        if (senderUid != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(senderUid)
              .get()
              .then((senderDoc) {
            if (senderDoc.exists) {
              final senderData = senderDoc.data() as Map<String, dynamic>?;
              if (senderData != null) {
                final firstName = senderData['firstName'] as String? ?? '';
                final lastName = senderData['lastName'] as String? ?? '';
                senderName = '$firstName $lastName'.trim();
                if (senderName.isEmpty) senderName = 'Unknown';
              }
              // Update the transaction in the list
              if (mounted) {
                setState(() {
                  final index = _allTransactions.indexWhere((t) => t['id'] == doc.id);
                  if (index != -1) {
                    _allTransactions[index]['name'] = 'From $senderName';
                  }
                });
              }
            }
          }).catchError((error) {
            _logger.w('Error fetching sender name for UID $senderUid: $error');
          });
        }

        currentStreamTransactions.add({
          'id': doc.id,
          'timestamp_raw': timestamp,
          'icon': Icons.arrow_downward,
          'name': 'From $senderName',
          'date': DateFormat('MMM dd, hh:mm a').format(timestamp),
          'amount': '+₦${amount.toStringAsFixed(2)}',
          'statusColor': Colors.green,
          'description': description,
        });
      }
    }

    if (mounted) {
      setState(() {
        _allTransactions.removeWhere((t) =>
            isSender ? t['icon'] == Icons.arrow_outward : t['icon'] == Icons.arrow_downward);
        _allTransactions.addAll(currentStreamTransactions);
        _allTransactions.sort((a, b) => (b['timestamp_raw'] as DateTime).compareTo(a['timestamp_raw'] as DateTime));
      });
      _logger.d('Updated _allTransactions list size: ${_allTransactions.length}');
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
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