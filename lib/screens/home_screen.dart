import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:intl/intl.dart'; // Import for date formatting

import 'user_profile_screen.dart'; // Import the UserProfileScreen
import 'pay_merchant_screen.dart'; // Import PayMerchantScreen
import 'transfer_entry_screen.dart'; // NEW: Import TransferEntryScreen
import 'all_transactions_screen.dart'; // NEW: Import AllTransactionsScreen
import 'dart:async'; // Import for StreamSubscription

class HomeScreen extends StatefulWidget {
  final String phoneNumber; // This will be the initial phone number from auth
  final double initialBalance; // This will be the initial balance (fallback)

  const HomeScreen({
    super.key,
    required this.phoneNumber,
    required this.initialBalance,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final Logger _logger = Logger();
  bool _isBalanceVisible = false;
  bool _isMenuOpen = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  String _userAccountNumber = 'N/A';
  double _accountBalance = 0.0;

  String _userFirstName = 'User';
  String _userLastName = '';

  List<Map<String, dynamic>> _recentTransactions = []; // List to hold fetched transactions

  int _selectedIndex = 0;

  // StreamSubscriptions for real-time balance and transactions
  StreamSubscription<DocumentSnapshot>? _userBalanceSubscription;
  StreamSubscription<QuerySnapshot>? _sentTransactionsSubscription; // Separate listener for sent
  StreamSubscription<QuerySnapshot>? _receivedTransactionsSubscription; // Separate listener for received

  @override
  void initState() {
    super.initState();
    _fetchUserProfileAndBalance(); // Fetch user profile and balance once
    _setupBalanceAndTransactionListeners(); // Set up real-time listeners

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.250).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  // Fetch user profile and balance (one-time fetch as requested)
  Future<void> _fetchUserProfileAndBalance() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.w('No current user found on HomeScreen. Cannot fetch user data.');
      if (mounted) {
        setState(() {
          _userAccountNumber = _formatPhoneNumberForDisplay(widget.phoneNumber);
          _userFirstName = 'User';
          _userLastName = '';
          _accountBalance = widget.initialBalance;
        });
      }
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
            _userAccountNumber = _formatPhoneNumberForDisplay(userData['phoneNumber'] ?? 'N/A');
            _userFirstName = userData['firstName'] ?? 'User';
            _userLastName = userData['lastName'] ?? '';
            _accountBalance = (userData['accountBalance'] as num?)?.toDouble() ?? 0.0;
          });
        }
        _logger.i('User data fetched: Balance: $_accountBalance');
      } else {
        _logger.w('User document does not exist for UID: ${currentUser.uid}. Using initial data.');
        if (mounted) {
          setState(() {
            _userAccountNumber = _formatPhoneNumberForDisplay(currentUser.phoneNumber ?? widget.phoneNumber);
            _accountBalance = widget.initialBalance;
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching user data: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error loading user data: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred fetching user data: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred.');
    }
  }

  // Set up real-time listeners for balance and transactions
  void _setupBalanceAndTransactionListeners() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.w('No current user found, cannot set up Firestore listeners.');
      return;
    }
    _logger.d('Setting up Firestore listeners for UID: ${currentUser.uid}');

    // Listen to user's balance changes
    _userBalanceSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final userData = snapshot.data()!;
        if (mounted) {
          setState(() {
            _accountBalance = (userData['accountBalance'] as num?)?.toDouble() ?? _accountBalance;
          });
        }
        _logger.d('Real-time balance update: $_accountBalance');
      } else {
        _logger.w('User balance document does not exist or is empty.');
      }
    }, onError: (error) {
      _logger.e('Error listening to balance updates: $error');
    });

    // Listen to sent transactions
    _sentTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('senderUid', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true) // Re-added orderBy for initial fetch and sorting
        .limit(5) // Keep limit for fetching a reasonable amount for recent display
        .snapshots()
        .listen((snapshot) {
      _logger.d('Received ${snapshot.docs.length} sent transaction updates.');
      _updateTransactions(snapshot.docs, isSender: true);
    }, onError: (error) {
      _logger.e('Error listening to sent transaction updates: $error');
    });

    // Listen to received transactions
    _receivedTransactionsSubscription = FirebaseFirestore.instance
        .collection('transactions')
        .where('receiverUid', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true) // Re-added orderBy for initial fetch and sorting
        .limit(5) // Keep limit for fetching a reasonable amount for recent display
        .snapshots()
        .listen((snapshot) {
      _logger.d('Received ${snapshot.docs.length} received transaction updates.');
      _updateTransactions(snapshot.docs, isSender: false);
    }, onError: (error) {
      _logger.e('Error listening to received transaction updates: $error');
    });
  }

  // Helper to combine and sort transactions from both listeners
  void _updateTransactions(List<QueryDocumentSnapshot> docs, {required bool isSender}) {
    // Create a temporary list for transactions from this specific stream (sent or received)
    List<Map<String, dynamic>> currentStreamTransactions = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      _logger.d('Processing transaction doc: ${doc.id}, Data: $data');

      final amount = (data['amount'] as num?)?.toDouble();
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      final description = data['description'] as String? ?? '';

      if (amount == null || timestamp == null) {
        _logger.w('Skipping transaction due to missing amount or timestamp: ${doc.id}');
        continue; // Skip if essential data is missing
      }

      if (isSender) {
        final receiverName = data['receiverName'] as String? ?? 'Unknown';
        currentStreamTransactions.add({
          'id': doc.id, // Add document ID for unique identification
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
          'id': doc.id, // Add document ID for unique identification
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
        // Remove old transactions from this type (sent or received) and add new ones
        // This ensures we always have the latest from each stream
        _recentTransactions.removeWhere((t) =>
            isSender ? t['icon'] == Icons.arrow_outward : t['icon'] == Icons.arrow_downward);
        _recentTransactions.addAll(currentStreamTransactions);

        // Sort all transactions by timestamp (descending)
        _recentTransactions.sort((a, b) {
          final DateTime dateA = a['timestamp_raw'];
          final DateTime dateB = b['timestamp_raw'];
          return dateB.compareTo(dateA);
        });

        // Take the top 2 most recent transactions overall for display on home screen
        _recentTransactions = _recentTransactions.take(2).toList(); // Changed limit to 2
      });
      _logger.d('Final _recentTransactions list size: ${_recentTransactions.length}');
      if (_recentTransactions.isNotEmpty) {
        _logger.d('First transaction in list: ${_recentTransactions.first}');
      }
    }
  }


  // Helper function to format phone number for display
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
    _userBalanceSubscription?.cancel();
    _sentTransactionsSubscription?.cancel();
    _receivedTransactionsSubscription?.cancel();
    _animationController.dispose();
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

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
    if (_isMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _logger.i('Bottom navigation item tapped: $index');
    if (index == 3) { // Profile tab
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserProfileScreen()),
      );
      _logger.i('Profile tab selected. Navigating to UserProfileScreen.');
    }
    if (index == 0) { // Home tab - ensure it doesn't navigate away from itself unnecessarily
      _fetchUserProfileAndBalance(); // Refresh balance on home tab tap
      // No need to call _setupBalanceAndTransactionListeners here, as listeners are persistent
    }
    if (index == 1) {
       _showMessageBox(context, 'Chats tab selected. Functionality not yet implemented.');
       _logger.i('Chats tab selected. Functionality not yet implemented.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(),

                // Balance Section
                _buildBalanceSection(),

                // Quick Actions
                _buildQuickActions(),

                // Recent Transactions
                _buildRecentTransactions(),

                const Spacer(),
              ],
            ),
          ),

          // Floating Menu Overlay
          if (_isMenuOpen) _buildMenuOverlay(),

          // Floating Menu Button
          _buildFloatingMenuButton(),
        ],
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
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card),
            label: 'Card',
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
          // Display user's first name here
          Text(
            'Hi, $_userFirstName',
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
              _logger.i('Notifications icon pressed');
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
                _logger.i('Account number button tapped. Placeholder for dropdown.');
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
                      _userAccountNumber,
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
          _buildQuickActionItem(Icons.phone_android, 'Airtime', () {
            _logger.i('Airtime button pressed');
            // Navigator.pushNamed(context, '/airtime'); // Example for Airtime
          }),
          _buildQuickActionItem(Icons.send, 'Transfer', () {
            _logger.i('Transfer button pressed');
            Navigator.pushNamed(context, '/transfer_entry'); // Navigate to new TransferEntryScreen
          }),
          _buildQuickActionItem(Icons.receipt_long, 'Bills', () {
            _logger.i('Bill button pressed');
            // Navigator.pushNamed(context, '/bills'); // Example for Bills
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
                  _logger.i('See All Transactions pressed');
                  Navigator.pushNamed(context, '/all_transactions'); // Navigate to new AllTransactionsScreen
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
              itemCount: _recentTransactions.length, // This will now be max 2
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

  Widget _buildMenuOverlay() {
    return GestureDetector(
      onTap: _toggleMenu,
      child: Container(
        color: Colors.black54,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 100),
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.apps, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'All Menu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildMenuGrid(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildMenuItem(Icons.phone_android, 'Airtime', Colors.purple),
        _buildMenuItem(Icons.bar_chart, 'Data', Colors.blue),
        _buildMenuItem(Icons.receipt_long, 'Bills', Colors.red),
        _buildMenuItem(Icons.account_balance_wallet, 'Vault', Colors.green),
        _buildMenuItem(Icons.credit_card, 'Cards', Colors.grey[800]!),
        _buildMenuItem(Icons.qr_code_scanner, 'Scan', Colors.orange),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        _logger.i('$label menu item pressed');
        _toggleMenu(); // Close menu after selection
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingMenuButton() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _toggleMenu,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isMenuOpen ? Icons.close : Icons.apps,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
