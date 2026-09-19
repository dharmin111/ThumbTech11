// lib/presentation/Merchant/StepThreeScreen.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:thumstechs/presentation/Marchant_screens/StepSixScreen.dart';
import 'package:thumstechs/presentation/authScreen/LoginScreen.dart';
import '../../Services/authServices.dart';
import 'MerchantEditProfileScreen.dart';
import 'StepFourScreen.dart';

class StepSevenScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const StepSevenScreen({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<StepSevenScreen> createState() => _StepSevenScreenState();
}

class _StepSevenScreenState extends State<StepSevenScreen> {
  bool _isLoading = false;
   Color darkTeal = Color(0xFF00695C);
  final tealColor = const Color(0xFF006B6B);

  Future<void> _updateStatus() async {
    setState(() => _isLoading = true);
    try {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MerchantEditProfileScreen(
              userId: widget.userId,
              userEmail: widget.userEmail,
            ),
          ),
        );
      }
    } catch (e) {
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
    final authService = AuthService();
    await authService.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Logout Successfully"),
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          OutlinedButton(onPressed: (){
            logout();
          }, child: Text('Logout',style: TextStyle(color: darkTeal),))
        ],
      ),
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
                      'assets/Step/stepSeven.PNG',
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.center,
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

              const SizedBox(height: 5),

              // ✅ Bottom: Step Indicator + Button
              Column(
                children: [
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     _buildStepIndicator(1, true, tealColor),
                  //     _buildStepIndicator(2, true, tealColor),
                  //     _buildStepIndicator(3, false, tealColor),
                  //     _buildStepIndicator(4, false, tealColor),
                  //     _buildStepIndicator(5, false, tealColor),
                  //   ],
                  // ),
                  const SizedBox(height: 16),

                  // ✅ Button with arrow on RIGHT side - SAME AS StepTwo
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
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
                                    'Update Profile',
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