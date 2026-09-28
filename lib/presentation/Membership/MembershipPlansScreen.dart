// lib/presentation/membership/MembershipPlansScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/MembershipService.dart';

class MembershipPlansScreen extends StatefulWidget {
  const MembershipPlansScreen({super.key});

  @override
  State<MembershipPlansScreen> createState() => _MembershipPlansScreenState();
}

class _MembershipPlansScreenState extends State<MembershipPlansScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _checkUserPlan();
  }

  Future<void> _checkUserPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final hasPlan = await MembershipService.hasActivePlan();
    if (hasPlan) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  // 🔥 Subscribe to Plan (Web/App both)
  Future<void> _subscribeToPlan(
    String planType,
    int durationDays,
    int price,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please login first');
      }

      await MembershipService.updatePlan(
        userId: user.uid,
        planType: planType,
        durationDays: durationDays,
      );

      if (mounted) {
        _showSuccessDialog(planType);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String planType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎉 Payment Successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your $planType membership has been activated successfully.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF42D7D7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 FIXED: Check if running on web
    // Using kIsWeb from foundation or checking platform
    final ThemeData theme = Theme.of(context);
    final TargetPlatform platform = Theme.of(context).platform;

    // 🔥 Better way to check if mobile
    _isMobile =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Membership Plans',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0C1B4D),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isMobile)
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF0C1B4D)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
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
                            'Subscribe to continue using Thumb Tech',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_errorMessage != null) const SizedBox(height: 16),

                    // Plans Grid
                    _buildPlansGrid(),

                    const SizedBox(height: 24),

                    // Back to Dashboard
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/dashboard');
                      },
                      child: const Text(
                        '← Back to Dashboard',
                        style: TextStyle(color: Color(0xFF42D7D7)),
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
        'title': '2 Days',
        'price': '₹199',
        'duration': '2 Days',
        'badge': 'QUICK',
        'planType': '2_days',
        'days': 2,
        'amount': 199,
        'features': [
          '✅ Access to all services',
          '✅ View service requests',
          '✅ Accept jobs',
          '✅ Chat with customers',
        ],
      },
      {
        'title': '5 Days',
        'price': '₹399',
        'duration': '5 Days',
        'badge': 'POPULAR',
        'planType': '5_days',
        'days': 5,
        'amount': 399,
        'features': [
          '✅ Access to all services',
          '✅ View service requests',
          '✅ Accept jobs',
          '✅ Chat with customers',
          '✅ Priority support',
        ],
      },
      {
        'title': '30 Days',
        'price': '₹1499',
        'duration': '30 Days',
        'badge': 'BEST VALUE',
        'planType': '30_days',
        'days': 30,
        'amount': 1499,
        'features': [
          '✅ Access to all services',
          '✅ View service requests',
          '✅ Accept jobs',
          '✅ Chat with customers',
          '✅ Priority support',
          '✅ Save 25%',
        ],
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _isMobile ? 1 : 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isPopular = index == 1; // 5 Days plan is popular

        return _buildPlanCard(
          title: plan['title'] as String,
          price: plan['price'] as String,
          duration: plan['duration'] as String,
          badge: plan['badge'] as String,
          isPopular: isPopular,
          features: plan['features'] as List<String>,
          planType: plan['planType'] as String,
          days: plan['days'] as int,
          amount: plan['amount'] as int,
        );
      },
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String duration,
    required String badge,
    required bool isPopular,
    required List<String> features,
    required String planType,
    required int days,
    required int amount,
  }) {
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
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
                if (badge.isNotEmpty)
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
                      badge,
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
                  price,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ $duration',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Features
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  feature,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0C1B4D),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Subscribe Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _subscribeToPlan(planType, days, amount),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
