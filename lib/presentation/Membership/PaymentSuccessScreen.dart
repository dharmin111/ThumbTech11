// lib/presentation/membership/PaymentSuccessScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/MembershipService.dart';

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _isLoading = true;
  String _status = 'Processing...';

  @override
  void initState() {
    super.initState();
    _verifyPayment();
  }

  Future<void> _verifyPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Check if plan is active
      final hasPlan = await MembershipService.hasActivePlan();

      if (hasPlan) {
        setState(() {
          _status = '✅ Payment Successful!';
          _isLoading = false;
        });

        // Navigate to dashboard after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(context, '/dashboard');
        });
      } else {
        setState(() {
          _status = '❌ Payment Failed. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isLoading
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42D7D7)),
                strokeWidth: 3,
              )
                  : Icon(
                _status.contains('✅') ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: _status.contains('✅') ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _status.contains('✅') ? Colors.green : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (!_isLoading && !_status.contains('✅'))
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/plans');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42D7D7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}