// lib/presentation/membership/MembershipScreen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/MembershipService.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _planStatus;

  // 🔥 Web URL for payment (Firebase Hosting)
  static const String _webUrl = 'https://thumbtech-521ae.web.app/plans';

  @override
  void initState() {
    super.initState();
    _loadPlanStatus();
  }

  Future<void> _loadPlanStatus() async {
    setState(() => _isLoading = true);
    try {
      _planStatus = await MembershipService.getPlanStatus();

      if (_planStatus!['isActive'] == true) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
    setState(() => _isLoading = false);
  }

  // 🔥 Open Web Link for Payment with Plan Type
  Future<void> _openWebPayment({String? planType}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please login first');
      }

      // 🔥 Open web URL with userId and planType
      String url = '$_webUrl?userId=${user.uid}';
      if (planType != null) {
        url = '$_webUrl?userId=${user.uid}&plan=$planType';
      }

      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        // After returning, refresh plan status
        await _loadPlanStatus();
      } else {
        throw 'Could not launch payment page';
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0C1B4D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 🔥 Plan Status Card
              _buildPlanStatusCard(),
              const SizedBox(height: 24),

              // 🔥 Plans Grid with Images Only
              _buildPlansGrid(),
              const SizedBox(height: 16),

              // 🔥 Error Message
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
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                        'You will be redirected to our secure payment page to complete your subscription.',
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

  // 🔥 Plan Status Card
  Widget _buildPlanStatusCard() {
    if (_planStatus == null) {
      return const SizedBox.shrink();
    }

    final isActive = _planStatus!['isActive'] ?? false;
    final isExpired = _planStatus!['isExpired'] ?? true;
    final daysRemaining = _planStatus!['daysRemaining'] ?? 0;
    final isFreeTrial = _planStatus!['isFreeTrial'] ?? false;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isActive) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      if (isFreeTrial) {
        statusText = 'Free Trial Active - $daysRemaining days remaining';
      } else {
        statusText = 'Plan Active - $daysRemaining days remaining';
      }
    } else if (isExpired) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Plan Expired - Please Subscribe';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Plan Inactive - Please Subscribe';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? '✅ Plan Active' : '❌ Plan Expired',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Plans Grid with Images Only (Tapable)
  Widget _buildPlansGrid() {
    final plans = [
      {
        'image': 'assets/membership/Trial Pack.png',
        'planType': '2_days',
        'price': '₹99',
      },
      {
        'image': 'assets/membership/growthpack.png',
        'planType': '5_days',
        'price': '₹249',
      },
    ];

    return Column(
      children: plans.map((plan) {
        return GestureDetector(
          onTap: () => _openWebPayment(planType: plan['planType'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                plan['image'] as String,
                width: 400,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFF42D7D7).withOpacity(0.1),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: const Color(0xFF42D7D7),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plan['planType'] == '2_days' ? 'Trial Pack' : 'Growth Pack',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0C1B4D),
                            ),
                          ),
                          Text(
                            plan['price'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}