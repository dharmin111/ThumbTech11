// Services/TechnicianAvailabilityService.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TechnicianAvailabilityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔥 Check if technicians available for given pincode and service
  static Future<TechnicianCheckResult> checkAvailability({
    required String pincode,
    required String serviceType,
  }) async {
    try {
      print('🔍 Checking technician availability...');
      print('   Pincode: $pincode');
      print('   Service: $serviceType');

      // Get all technicians
      final techSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .get();

      List<Map<String, dynamic>> matchedTechnicians = [];

      for (var doc in techSnapshot.docs) {
        final data = doc.data();

        // Check if technician is active
        final isActive = data['isActive'] ?? true;
        if (!isActive) continue;

        // Check if technician is approved
        final isApproved = data['isApproved'] ?? true;
        if (!isApproved) continue;

        // Get technician categories
        final categories = List<String>.from(data['categories'] ?? []);

        // Get technician pincodes
        List<String> technicianPincodes = [];
        if (data['pincodes'] != null && (data['pincodes'] as List).isNotEmpty) {
          technicianPincodes = List<String>.from(data['pincodes']);
        } else if (data['pincode'] != null && data['pincode'].toString().isNotEmpty) {
          technicianPincodes = [data['pincode'].toString()];
        }

        // Check if service matches
        final serviceMatches = categories.contains(serviceType);

        // Check if pincode matches
        final pincodeMatches = technicianPincodes.contains(pincode);

        if (serviceMatches && pincodeMatches) {
          matchedTechnicians.add({
            'id': doc.id,
            'name': data['name'] ?? 'Technician',
            'phone': data['phone'] ?? '',
            'categories': categories,
            'pincodes': technicianPincodes,
            'rating': data['rating'] ?? 0,
            'totalReviews': data['totalReviews'] ?? 0,
          });
        }
      }

      print('📊 Matched technicians: ${matchedTechnicians.length}');

      return TechnicianCheckResult(
        isAvailable: matchedTechnicians.isNotEmpty,
        technicians: matchedTechnicians,
        count: matchedTechnicians.length,
      );
    } catch (e) {
      print('❌ Error checking technician availability: $e');
      return TechnicianCheckResult(
        isAvailable: false,
        technicians: [],
        count: 0,
        error: e.toString(),
      );
    }
  }
}

// ================= RESULT MODEL =================
class TechnicianCheckResult {
  final bool isAvailable;
  final List<Map<String, dynamic>> technicians;
  final int count;
  final String? error;

  TechnicianCheckResult({
    required this.isAvailable,
    required this.technicians,
    required this.count,
    this.error,
  });
}