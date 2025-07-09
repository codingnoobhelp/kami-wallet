import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:intl/intl.dart'; // Import for date formatting

// Import screens relevant to merchant actions
import 'merchant_profile_screen.dart'; // NEW: Import the MerchantProfileScreen (will create next)
import 'transfer_entry_screen.dart';
import 'qr_code_scanner_screen.dart'; // For 'Receive' quick action
import 'qr_generator_screen.dart'; // For 'My QR Code' quick action
import 'all_transactions_screen.dart'; // For 'See all' transactions
import 'dart:async'; // Import for StreamSubscription

class MerchantHomeScreen extends StatefulWidget {
  final String merchantId; // This will be the initial merchant ID from login

  const MerchantHomeScreen({
    super.key,
    required this.merchantId,
  });

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> with TickerProviderStateMixin {
  final Logger _logger = Logger();
  bool _isBalanceVisible = false;

  // Removed _isMenuOpen and animation controllers as the floating menu is removed

  String _merchantAccountNumber = 'N/A'; // Will display merchant's phone number or a unique merchant account identifier
  double _accountBalance = 0.0;

  String _merchantName = 'Merchant'; // Will display the fetched merchant name

  List<Map<String, dynamic>> _recentTransactions = []; // List to hold fetched transactions

  int _selectedIndex = 0; // For bottom navigation bar

  // StreamSubscriptions for real-time balance and transactions
  StreamSubscription<DocumentSnapshot>? _merchantBalanceSubscription;
  StreamSubscription<QuerySnapshot>? _sentTransactionsSubscription;
  StreamSubscription<QuerySnapshot>? _receivedTransactionsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchMerchantProfileAndBalance(); // Fetch merchant profile and balance once
    _setupBalanceAndTransactionListeners(); // Set up real-time listeners
  }

  // Fetch merchant profile and balance (one-time fetch)
  Future<void> _fetchMerchantProfileAndBalance() async {
    // For merchant home, we need the merchant's UID to fetch their document.
    // Assuming the merchantId passed here is the actual Firestore document ID
    // or can be used to query the merchant document to get the UID.
    // For simplicity, let's assume `widget.merchantId` is the Firestore document ID for now.
    // In a more complex scenario, you might have a Firebase Auth UID for the merchant.

    try {
      // Query the 'merchants' collection by 'merchantId' field
      QuerySnapshot merchantQuery = await FirebaseFirestore.instance
          .collection('merchants')
          .where('merchantId', isEqualTo: widget.merchantId)
          .limit(1)
          .get();

      if (merchantQuery.docs.isNotEmpty) {
        DocumentSnapshot merchantDoc = merchantQuery.docs.first;
        final merchantData = merchantDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _merchantName = merchantData['merchantName'] ?? 'Merchant';
            _merchantAccountNumber = _formatPhoneNumberForDisplay(merchantData['phoneNumber'] ?? 'N/A'); // Assuming merchants also have a phone number
            _accountBalance = (merchantData['accountBalance'] as num?)?.toDouble() ?? 0.0;
          });
        }
        _logger.i('Merchant data fetched: Name: $_merchantName, Balance: $_accountBalance');
      } else {
        _logger.w('Merchant document not found for ID: ${widget.merchantId}. Using initial data.');
        if (mounted) {
          setState(() {
            _merchantAccountNumber = 'N/A'; // Default if not found
            _accountBalance = 0.0; // Default if not found
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching merchant data: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error loading merchant data: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred fetching merchant data: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred.');
    }
  }

  // Set up real-time listeners for balance and transactions
  void _setupBalanceAndTransactionListeners() {
    // This part is tricky. If merchants have their own Firebase Auth UIDs,
    // you'd use FirebaseAuth.instance.currentUser.uid.
    // If not, you'd need to use the Firestore document ID of the merchant
    // that corresponds to widget.merchantId.
    // For now, I'll assume the merchant's document ID is available or can be derived.
    // Let's assume for simplicity that the merchant's document ID in 'merchants' collection
    // is the same as their 'merchantId' field for transaction tracking.
    // In a real app, you'd likely map the merchantId to a Firebase Auth UID.

    // To simplify, let's use the merchantId as the UID for transaction filtering
    // This is a simplification and might need adjustment based on your actual
    // merchant authentication and data structure.
    final String currentMerchantUidForTransactions = widget.merchantId; // Using merchantId as a pseudo-UID for transactions

    // Listen to merchant's balance changes
    // This assumes the merchant's balance is stored in their merchant document
    _merchantBalanceSubscription = FirebaseFirestore.instance
        .collection('merchants')
        .doc(currentMerchantUidForTransactions) // Assuming merchantId is the doc ID for balance
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final merchantData = snapshot.data()!;
        if (mounted) {
          setState(() {
            _accountBalance = (merchantData['accountBalance'] as num?)?.toDouble() ?? _accountBalance;
          });
        }
        _logger.d('Real-time merchant balance update: $_accountBalance');
      } else {
        _logger.w('Merchant balance document does not exist or is empty for UID: $currentMerchantUidForTransactions.');
      }
    }, onError: (error) {
      _logger.e('Error listening to merchant balance updates: $error');
    });

    // Listen to sent transactions by this merchant
    _sentTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('senderUid', isEqualTo: currentMerchantUidForTransactions)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      _logger.d('Received ${snapshot.docs.length} sent transaction updates for merchant.');
      _updateTransactions(snapshot.docs, isSender: true);
    }, onError: (error) {
      _logger.e('Error listening to sent transaction updates for merchant: $error');
    });

    // Listen to received transactions by this merchant
    _receivedTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('receiverUid', isEqualTo: currentMerchantUidForTransactions)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      _logger.d('Received ${snapshot.docs.length} received transaction updates for merchant.');
      _updateTransactions(snapshot.docs, isSender: false);
    }, onError: (error) {
      _logger.e('Error listening to received transaction updates for merchant: $error');
    });
  }


  // Helper to combine and sort transactions from both listeners
  void _updateTransactions(List<QueryDocumentSnapshot> docs, {required bool isSender}) {
    List<Map<String, dynamic>> currentStreamTransactions = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      _logger.d('Processing transaction doc: ${doc.id}, Data: $data');

      final amount = (data['amount'] as num?)?.toDouble();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final description = data['description'] as String? ?? '';

      if (amount == null || timestamp == null) {
        _logger.w('Skipping transaction due to missing amount or timestamp: ${doc.id}');
        continue;
      }

      if (isSender) {
        final receiverName = data['receiverName'] as String? ?? 'Unknown';
        currentStreamTransactions.add({
          'id': doc.id,
          'timestamp_raw': timestamp,
          'icon': Icons.arrow_outward,
          'name': 'To $receiverName',
          'date': DateFormat('MMM dd, hh:mm a').format(timestamp),
          'amount': '-₦${amount.toStringAsFixed(2)}',
          'statusColor': Colors.redAccent,
          'description': description,
        });
      } else {
        final senderName = data['senderName'] as String? ?? 'Unknown';
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
        _recentTransactions.removeWhere((t) =>
            isSender ? t['icon'] == Icons.arrow_outward : t['icon'] == Icons.arrow_downward);
        _recentTransactions.addAll(currentStreamTransactions);

        _recentTransactions.sort((a, b) {
          final DateTime dateA = a['timestamp_raw'];
          final DateTime dateB = b['timestamp_raw'];
          return dateB.compareTo(dateA);
        });

        _recentTransactions = _recentTransactions.take(2).toList();
      });
      _logger.d('Final _recentTransactions list size: ${_recentTransactions.length}');
    }
  }


  // Helper function to format phone number for display (e.g., remove country code prefix)
  String _formatPhoneNumberForDisplay(String rawPhoneNumber) {
    if (rawPhoneNumber.startsWith('+234')) {
      if (rawPhoneNumber.length > 4 && rawPhoneNumber[4] == '0') {
        return rawPhoneNumber.substring(5); // Remove +234 and leading 0
      } else {
        return rawPhoneNumber.substring(4); // Remove +234
      }
    } else if (rawPhoneNumber.startsWith('0') && rawPhoneNumber.length >= 10) {
      return rawPhoneNumber.substring(1); // Remove leading 0
    }
    return rawPhoneNumber; // Return as is if no specific formatting applies
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
  void dispose() {
    _merchantBalanceSubscription?.cancel();
    _sentTransactionsSubscription?.cancel();
    _receivedTransactionsSubscription?.cancel();
    // Removed animation controller dispose as floating menu is removed
    super.dispose();
  }

  String get _maskedBalance {
    if (_isBalanceVisible) {
      return '₦${_accountBalance.toStringAsFixed(2)}';
    } else {
      return '₦******';
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
    _logger.d('Balance visibility toggled to: $_isBalanceVisible');
  }

  // Removed _toggleMenu, _buildMenuOverlay, _buildMenuGrid, _buildMenuItem, _buildFloatingMenuButton

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _logger.i('Bottom navigation item tapped: $index');
    switch (index) {
      case 0: // Home tab
        // No navigation needed, already on home. Can refresh data if desired.
        _fetchMerchantProfileAndBalance(); // Refresh balance on home tab tap
        break;
      case 1: // Chat tab
        _showMessageBox(context, 'Chats tab selected. Functionality not yet implemented for merchants.');
        _logger.i('Chats tab selected. Functionality not yet implemented for merchants.');
        break;
      case 2: // Analytics tab
        _showMessageBox(context, 'Analytics tab selected. Functionality not yet implemented for merchants.');
        _logger.i('Analytics tab selected. Functionality not yet implemented for merchants.');
        break;
      case 3: // Profile tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MerchantProfileScreen()), // Navigate to MerchantProfileScreen
        );
        _logger.i('Profile tab selected. Navigating to MerchantProfileScreen.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Balance Section
            _buildBalanceSection(),

            // Quick Actions (Merchant specific)
            _buildQuickActions(),

            // Recent Transactions
            _buildRecentTransactions(),

            const Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF2C2C2E),
        selectedItemColor: const Color(0xFF007AFF),
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat', // Changed from 'Chats'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics), // Changed icon to analytics
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          // Display merchant's name here
          Text(
            'Hi, $_merchantName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white54),
            onPressed: () {
              _logger.i('Notifications icon pressed (Merchant Home)');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                _logger.i('Account number button tapped (Merchant Home). Placeholder for dropdown.');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _merchantAccountNumber, // Display merchant account number
                      style: const TextStyle(color: Color.fromARGB(235, 255, 255, 255)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: Color.fromARGB(255, 255, 255, 255)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _maskedBalance,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleBalanceVisibility,
                  child: Icon(
                    _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white54,
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionItem(Icons.send, 'Transfer', () {
            _logger.i('Transfer button pressed (Merchant Home)');
            Navigator.pushNamed(context, '/transfer_entry');
          }),
          _buildQuickActionItem(Icons.qr_code_scanner, 'Receive', () { // Changed to Receive and QR Scanner icon
            _logger.i('Receive (QR Scan) button pressed (Merchant Home)');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QrScannerScreen()),
            );
          }),
          _buildQuickActionItem(Icons.qr_code, 'My QR Code', () { // Changed to My QR Code and QR Code icon
            _logger.i('My QR Code (Generate) button pressed (Merchant Home)');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QrGeneratorScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RECENT TRANSACTIONS',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () {
                  _logger.i('See All Transactions pressed (Merchant Home)');
                  Navigator.pushNamed(context, '/all_transactions');
                },
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.receipt_outlined, color: Colors.white54),
                  SizedBox(width: 12),
                  Text(
                    'No Transactions done',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _recentTransactions[index];
                return _buildTransactionItem(
                  icon: transaction['icon'],
                  name: transaction['name'],
                  date: transaction['date'],
                  amount: transaction['amount'],
                  statusColor: transaction['statusColor'],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required IconData icon,
    required String name,
    required String date,
    required String amount,
    required Color statusColor,
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
}
