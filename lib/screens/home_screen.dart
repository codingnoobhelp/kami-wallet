
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HomeScreen extends StatefulWidget {
  final String phoneNumber;
  final double initialBalance;

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

  late String _userAccountNumber;
  late double _accountBalance;

  final List<Map<String, dynamic>> _recentTransactions = [];

  // Added for Bottom Navigation Bar
  int _selectedIndex = 0; // Index of the selected tab

  @override
  void initState() {
    super.initState();
    String rawPhoneNumber = widget.phoneNumber;

    // Process the phone number to be used as account number
    if (rawPhoneNumber.startsWith('+234')) {
      if (rawPhoneNumber.length > 4 && rawPhoneNumber[4] == '0') {
        _userAccountNumber = rawPhoneNumber.substring(5);
      } else {
        _userAccountNumber = rawPhoneNumber.substring(4);
      }
    } else if (rawPhoneNumber.startsWith('0') && rawPhoneNumber.length >= 10) {
      _userAccountNumber = rawPhoneNumber.substring(1);
    } else {
      _userAccountNumber = rawPhoneNumber;
    }

    _userAccountNumber = _userAccountNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (_userAccountNumber.length > 10) {
      _userAccountNumber = _userAccountNumber.substring(_userAccountNumber.length - 10);
    }

    _accountBalance = widget.initialBalance;
    _logger.d('HomeScreen initialized for account number: $_userAccountNumber, balance: $_accountBalance');

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

  @override
  void dispose() {
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

   // Method to handle tap on a navigation bar item
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _logger.i('Bottom navigation item tapped: $index');
    // Here you would typically navigate to a different screen or show different content
    // For now, we just log the selection.
    if (index == 1) { // Assuming index 1 is for Profile
      // We will add navigation to PersonalInfoScreen here later
      _logger.i('Profile tab selected. Will navigate to PersonalInfoScreen soon.');
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
       // Added Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF2C2C2E), // Dark background for the bar
        selectedItemColor: const Color(0xFF007AFF), // Blue for selected item
        unselectedItemColor: Colors.white54, // Grey for unselected items
        currentIndex: _selectedIndex, // Set the current selected index
        onTap: _onItemTapped, // Handle tap events
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
           ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), // Added Chat icon
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card), // Added Card icon
            label: 'Card',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          // You can add more items here if needed, e.g., 'Settings', 'History'
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.history),
          //   label: 'History',
          // ),
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
          const Icon(
            Icons.person_outlined,
            color: Colors.white54
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
                    const Icon(Icons.keyboard_arrow_down, color: Color.from(alpha: 1, red: 1, green: 1, blue: 1)),
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
          }),
          _buildQuickActionItem(Icons.send, 'Transfer', () {
            _logger.i('Transfer button pressed');
          }),
          _buildQuickActionItem(Icons.receipt_long, 'Bills', () {
            _logger.i('Bill button pressed');
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
              color: const Color(0xFF2C2C2E).withValues(alpha: 1.0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13, ),
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
              color: statusColor.withValues(alpha: 0.2),
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
                        color: Colors.black.withValues(alpha: 0.3),
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