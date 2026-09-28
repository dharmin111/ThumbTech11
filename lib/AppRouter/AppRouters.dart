import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:thumstechs/Userform/CustomerFormScreen.dart';
import 'package:thumstechs/Userform/UserInfoScreen.dart';
import 'package:thumstechs/presentation/DashBoard/TechnicianDashboard.dart';
import '../presentation/DashBoard/CustomerDashboard.dart';
import '../presentation/authScreen/LoginScreen.dart';

class AppRouter {
  static Future<Widget> getStartScreen() async {
    // Get current user
    final User? user = FirebaseAuth.instance.currentUser;

    // Case 1: User not logged in
    if (user == null) {
      debugPrint('User not logged in - redirecting to LoginScreen');
      return const LoginScreen();
    }

    debugPrint('User logged in: ${user.uid}');

    try {
      // Check if user document exists in 'users' collection
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      // Case 2: User logged in but has no data in 'users' collection
      if (!userDoc.exists || userDoc.data() == null) {
        debugPrint('User has no profile data - redirecting to UserInfoScreen');
        return const UserInfoScreen();
      }

      // Get the role from user document
      final String role = userDoc.get('role');
      debugPrint('User role: $role');

      // Case 3: User is a CUSTOMER
      if (role == "customer") {
        // Check if customer has complete profile data
        final DocumentSnapshot customerDoc = await FirebaseFirestore.instance
            .collection(
              "users",
            ) // or "customers" collection based on your structure
            .doc(user.uid)
            .get();

        // If customer has all required data, go to Dashboard
        if (customerDoc.exists && _hasCompleteCustomerData(customerDoc)) {
          debugPrint('Customer has complete data - redirecting to Dashboard');
          return CustomerDashboard();
        } else {
          // Customer needs to complete profile
          debugPrint(
            'Customer needs to complete profile - redirecting to CustomerFormScreen',
          );
          return CustomerFillingScreen();
        }
      }
      // Case 4: User is a TECHNICIAN
      else if (role == "technician") {
        // Check if technician has complete profile data
        final DocumentSnapshot technicianDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        // If technician has all required data, go to TechnicianDashboard
        if (technicianDoc.exists && _hasCompleteTechnicianData(technicianDoc)) {
          debugPrint(
            'Technician has complete data - redirecting to TechnicianDashboard',
          );
          return TechnicianDashboard();
        } else {
          // Technician needs to complete profile
          debugPrint(
            'Technician needs to complete profile - redirecting to UserInfoScreen',
          );
          return const UserInfoScreen();
        }
      }
      // Case 5: Invalid role
      else {
        debugPrint('Invalid role - redirecting to UserSelectionScreen');
        return const LoginScreen();
      }
    } catch (e) {
      debugPrint('Error in routing: $e');
      // On error, redirect to login screen
      return const LoginScreen();
    }
  }

  // Helper method to check if customer has complete data
  static bool _hasCompleteCustomerData(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    // Check required fields for customer
    return data.containsKey('name') &&
        data.containsKey('phoneNumber') &&
        data.containsKey('address') &&
        data.containsKey('pincode') &&
        data['name'] != null &&
        data['name'].toString().isNotEmpty &&
        data['phoneNumber'] != null &&
        data['phoneNumber'].toString().isNotEmpty &&
        data['address'] != null &&
        data['address'].toString().isNotEmpty &&
        data['pincode'] != null &&
        data['pincode'].toString().isNotEmpty;
  }

  // Helper method to check if technician has complete data
  static bool _hasCompleteTechnicianData(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    // Check required fields for technician
    // You can add more fields as needed
    return data.containsKey('name') &&
        data.containsKey('phoneNumber') &&
        data.containsKey('address') &&
        data.containsKey('pincode') &&
        data['name'] != null &&
        data['name'].toString().isNotEmpty &&
        data['phoneNumber'] != null &&
        data['phoneNumber'].toString().isNotEmpty &&
        data['address'] != null &&
        data['address'].toString().isNotEmpty &&
        data['pincode'] != null &&
        data['pincode'].toString().isNotEmpty;
  }
}
