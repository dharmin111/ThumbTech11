// lib/presentation/TechnicianOnboardingScreens/TechReadFour.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../Userform/TechnicianServiceDetailsScreen.dart';

class TechReadFour extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final File? profileImage;

  const TechReadFour({super.key, this.userData, this.profileImage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Expanded takes remaining space, pushing button to bottom
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Image.asset(
                    'assets/onboarding/cust4.png',
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.6,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Image not found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Bottom Get Started Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (userData != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TechnicianServiceDetailsScreen(
                          name: userData?['name'] ?? '',
                          phone:
                              userData?['phoneNumber'] ??
                              userData?['phone'] ??
                              '',
                          address: userData?['address'] ?? '',
                          pincode: userData?['pincode'] ?? '',
                          profileImage: profileImage,
                          userId: userData?['id'] ?? '',
                        ),
                      ),
                    );
                  } else {
                    // Fallback if no data
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const TechnicianServiceDetailsScreen(
                              name: '',
                              phone: '',
                              address: '',
                              pincode: '',
                              userId: '',
                            ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Get Started',
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
