import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class PasscodeSetupPage extends StatefulWidget {
  const PasscodeSetupPage({super.key});

  @override
  State<PasscodeSetupPage> createState() => _PasscodeSetupPageState();
}

class _PasscodeSetupPageState extends State<PasscodeSetupPage> {
  final List<String> _passcode = List.filled(4, '');
  int _currentIndex = 0;
  final Logger _logger = Logger();

  String? _phone;
  String? _name; // New: to store name from previous screen
  String? _email; // New: to store email from previous screen

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _phone = args['phoneNumber'];
      _name = args['name']; // Extract name
      _email = args['email']; // Extract email
      _logger.d('Passcode setup screen received phone: $_phone, Name: $_name, Email: $_email');
    }
  }

  void _updatePasscode(String digit) {
    if (_currentIndex < 4) {
      setState(() {
        _passcode[_currentIndex] = digit;
        _currentIndex++;
      });
    }
    if (_currentIndex == 4) {
      _logger.i('Passcode entered: ${_passcode.join()}');

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Clear passcode and navigate to success screen
          setState(() {
            _passcode.fillRange(0, 4, '');
            _currentIndex = 0;
          });
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/success',
            (route) => false, // This ensures all previous routes are removed
            arguments: {
              'phoneNumber': _phone,
              'name': _name, // Pass name
              'email': _email, // Pass email
              // Initial balance is not generated here. It will be defaulted in success_screen or pulled from backend later.
            },
          );
        }
      });
    }
  }

  void _deleteDigit() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _passcode[_currentIndex] = '';
      });
    }
  }

  Widget _buildPasscodeDot(int index) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _passcode[index].isNotEmpty ? Colors.black : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildNumberPadButton(String digit) {
    return GestureDetector(
      onTap: () => _updatePasscode(digit),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Setup Passcode',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Create your 4-digit passcode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'This will be used to secure your account.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _buildPasscodeDot(index)),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                physics: const NeverScrollableScrollPhysics(), // Disable scrolling
                children: List.generate(9, (index) {
                  return _buildNumberPadButton('${index + 1}');
                })
                  ..add(Container()) // Empty space for alignment
                  ..add(_buildNumberPadButton('0'))
                  ..add(
                    GestureDetector(
                      onTap: _deleteDigit,
                      child: Container(
                        decoration: BoxDecoration(
                           color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade100 : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.backspace,
                            size: 24,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}