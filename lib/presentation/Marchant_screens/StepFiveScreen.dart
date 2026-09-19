// lib/presentation/Merchant/StepFiveScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StepFiveScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const StepFiveScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<StepFiveScreen> createState() => _StepFiveScreenState();
}

class _StepFiveScreenState extends State<StepFiveScreen> {
  bool _isLoading = false;
  final tealColor = const Color(0xFF006B6B);

  @override
  void initState() {
    super.initState();
    _updateStatusToPending();
  }

  Future<void> _updateStatusToPending() async {
    try {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.userId)
          .update({
        'status': 'pending_approval',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'merchantStatus': 'pending_approval',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ✅ Image
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      height: 200,
                      width: 100,
                      'assets/Step/stepFive.PNG',
                      //fit: BoxFit.cover,
                     // alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
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
              ),

              const SizedBox(height: 12),

              // ✅ Step Indicator - 5 Steps Active
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(1, true, tealColor),
                  _buildStepIndicator(2, true, tealColor),
                  _buildStepIndicator(3, true, tealColor),
                  _buildStepIndicator(4, true, tealColor),
                  _buildStepIndicator(5, true, tealColor),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive, Color tealColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? tealColor : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: tealColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : null,
        border: isActive
            ? Border.all(
          color: tealColor.withOpacity(0.3),
          width: 2,
        )
            : null,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}