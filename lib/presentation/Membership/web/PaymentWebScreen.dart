// lib/presentation/membership/web/PaymentWebScreen.dart
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../services/MembershipService.dart';
import '../../../config/razorpay_config.dart';

class PaymentWebScreen extends StatefulWidget {
  const PaymentWebScreen({super.key});

  @override
  State<PaymentWebScreen> createState() => _PaymentWebScreenState();
}

class _PaymentWebScreenState extends State<PaymentWebScreen> {
  String? _userId;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentPlan;
  Razorpay? _razorpay;

  // 🔥 Store payment details
  String? _selectedPlanType;
  int? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 🔥 Get userId from URL
    final uri = html.window.location;
    final params = Uri.parse(uri.toString()).queryParameters;
    _userId = params['userId'];

    print('📱 User ID from URL: $_userId');

    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _errorMessage = 'User ID not found in URL';
        _isLoading = false;
      });
      return;
    }

    // 🔥 Initialize Razorpay for Web
    _razorpay = Razorpay();

    // 🔥 Set event listeners
    _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    // 🔥 Check current plan
    await _checkPlan();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkPlan() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      if (doc.exists) {
        final planData = doc.data()?['plan'] as Map<String, dynamic>?;
        if (planData != null) {
          _currentPlan = planData;
          final isActive = planData['isActive'] ?? false;
          final expiryDate = (planData['expiryDate'] as Timestamp?)?.toDate();

          if (isActive &&
              expiryDate != null &&
              expiryDate.isAfter(DateTime.now())) {
            setState(() {
              _errorMessage = 'You already have an active plan!';
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error checking plan: $e');
    }
  }

  // ================= PAYMENT HANDLERS =================

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('✅ Payment Success: ${response.paymentId}');
    print('📦 Order ID: ${response.orderId}');
    print('📦 Signature: ${response.signature}');

    // 🔥 Update plan using stored values
    _updatePlanAfterPayment(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.message}');
    setState(() {
      _isProcessing = false;
      _errorMessage = response.message ?? 'Payment failed';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('📱 External Wallet: ${response.walletName}');
  }

  // 🔥 Update Plan After Payment
  Future<void> _updatePlanAfterPayment(PaymentSuccessResponse response) async {
    try {
      // 🔥 Use stored plan details instead of response.notes
      final planType = _selectedPlanType;
      final durationDays = _selectedDuration;

      if (_userId == null || planType == null || durationDays == null) {
        throw Exception('Missing payment details');
      }

      print('📊 Updating plan for user: $_userId');
      print('📊 Plan Type: $planType');
      print('📊 Duration: $durationDays days');

      // 🔥 Update plan in Firestore
      await MembershipService.updatePlan(
        userId: _userId!,
        planType: planType,
        durationDays: durationDays,
      );

      // 🔥 Save payment record
      await FirebaseFirestore.instance.collection('payments').add({
        'userId': _userId,
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
        'planType': planType,
        'amount': RazorpayConfig.getPlanPrice(planType),
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isProcessing = false;
        _errorMessage = '✅ Payment Successful! Your plan is now active.';
      });

      // 🔥 Show success message
      _showSuccessAndRedirect();
    } catch (e) {
      print('❌ Error updating plan: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error updating plan: $e';
      });
    }
  }

  void _showSuccessAndRedirect() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉 Payment Successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your membership has been activated successfully.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You can close this window now.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // 🔥 Close current window
              html.window.close();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42D7D7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Close Window'),
          ),
        ],
      ),
    );
  }

  // 🔥 Open Razorpay Payment
  Future<void> _openPayment(String planType) async {
    final plan = RazorpayConfig.getPlan(planType);
    if (plan == null) return;

    // 🔥 Store plan details for later use
    _selectedPlanType = planType;
    _selectedDuration = plan['duration'];

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();

      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? 'User';
      final userEmail = userData['email'] ?? '';
      final userPhone = userData['phone'] ?? '';

      final options = {
        'key': RazorpayConfig.keyId,
        'amount': (plan['price'] as int) * 100, // Amount in paise
        'name': 'Thumb Tech',
        'description': '${plan['name']} Membership',
        'prefill': {'contact': userPhone, 'email': userEmail, 'name': userName},
        'theme': {'color': '#42D7D7'},
        'notes': {
          'userId': _userId,
          'planType': planType,
          'durationDays': plan['duration'].toString(),
        },
      };

      print('📤 Opening Razorpay with options: $options');
      _razorpay?.open(options);
    } catch (e) {
      print('❌ Error opening payment: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF42D7D7)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Thumb Tech - Membership',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C1B4D),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF42D7D7),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Processing payment...',
                    style: TextStyle(fontSize: 16, color: Color(0xFF0C1B4D)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF42D7D7).withValues(alpha: 0.1),
                            const Color(0xFF42D7D7).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 48,
                            color: Color(0xFF42D7D7),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Choose Your Plan',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C1B4D),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a plan to continue using Thumb Tech',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🔥 Error/Success Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _errorMessage!.contains('✅')
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _errorMessage!.contains('✅')
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _errorMessage!.contains('✅')
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: _errorMessage!.contains('✅')
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: _errorMessage!.contains('✅')
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_errorMessage != null) const SizedBox(height: 16),

                    // 🔥 Plans Grid
                    _buildPlansGrid(),

                    const SizedBox(height: 16),

                    // 🔥 Note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Secure payment powered by Razorpay. You will be redirected to complete payment.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlansGrid() {
    final plans = [
      {
        'key': '2_days',
        'title': '2 Days',
        'price': '₹99',
        'duration': '2 Days',
        'badge': 'QUICK',
        'color': Colors.blue,
      },
      {
        'key': '5_days',
        'title': '5 Days',
        'price': '₹249',
        'duration': '5 Days',
        'badge': 'POPULAR',
        'color': const Color(0xFF42D7D7),
      },
      // 🔥 Commented - 30 Days Plan
      // {
      //   'key': '30_days',
      //   'title': '30 Days',
      //   'price': '₹1499',
      //   'duration': '30 Days',
      //   'badge': 'BEST VALUE',
      //   'color': Colors.orange,
      // },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isPopular = index == 1;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPopular ? const Color(0xFF42D7D7) : Colors.grey.shade200,
              width: isPopular ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPopular
                    ? const Color(0xFF42D7D7).withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan['title'] as String,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0C1B4D),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPopular
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF42D7D7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        plan['badge'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Price
                Row(
                  children: [
                    Text(
                      plan['price'] as String,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0C1B4D),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ ${plan['duration']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Features
                const Text(
                  '✅ Access to all services',
                  style: TextStyle(fontSize: 13, color: Color(0xFF0C1B4D)),
                ),
                const Text(
                  '✅ View service requests',
                  style: TextStyle(fontSize: 13, color: Color(0xFF0C1B4D)),
                ),
                const Text(
                  '✅ Accept jobs',
                  style: TextStyle(fontSize: 13, color: Color(0xFF0C1B4D)),
                ),
                const Text(
                  '✅ Chat with customers',
                  style: TextStyle(fontSize: 13, color: Color(0xFF0C1B4D)),
                ),

                const Spacer(),

                // Subscribe Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _openPayment(plan['key'] as String),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular
                          ? const Color(0xFF42D7D7)
                          : const Color(0xFF0C1B4D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Subscribe Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
