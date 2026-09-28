// lib/presentation/Merchant/StepTwoScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Services/authServices.dart';
import '../authScreen/LoginScreen.dart';
import 'StepFourScreen.dart';
import 'StepThreeScreen.dart';

class StepSixScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const StepSixScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<StepSixScreen> createState() => _StepSixScreenState();
}

class _StepSixScreenState extends State<StepSixScreen> {
  bool _isLoading = false;

  Future<void> _updateStatus() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .update({
        'status': 'uploaded',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'merchantStatus': 'uploaded',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StepFourScreen(
              userId: widget.userId,
              userEmail: widget.userEmail,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> logout() async {
    AuthService authService = AuthService();

    await authService.logout();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: logout,
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
              ),
              label: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00695C), // Dark Teal
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ Image - Cropped properly with Container constraints
              Container(
                height: MediaQuery.of(context).size.height * 0.60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/Step/stepSix.png',
                    fit: BoxFit.cover, // ✅ Crop to fill the container
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Image not found',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ✅ Step Indicator with Better Design
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(1, true),
                  _buildStepIndicator(2, true),
                  _buildStepIndicator(3, true),
                  _buildStepIndicator(4, false),
                  _buildStepIndicator(5, false),
                ],
              ),

              const SizedBox(height: 30),

              // ✅ Continue Button - Better Design
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006B6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20),

                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            Positioned(
                              right: 0,
                              child: Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF006B6B) : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: const Color(0xFF42D7D7).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Color(0xFF006B6B),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}