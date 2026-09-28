import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save complete technician data to Firestore (with multiple pincodes)
  Future<Map<String, dynamic>> saveTechnicianData({
    required String userId,
    required String name,
    required String phone,
    required String address,
    required List<String> pincodes, // ✅ Changed from String to List<String>
    required String description,
    required List<String> selectedCategories,
    required List<String> previousWorkImageUrls,
    required String? idCardImageUrl,
    required String? profileImageUrl,
  }) async {
    try {
      // Prepare technician data with multiple pincodes
      Map<String, dynamic> technicianData = {
        'id': userId,
        'name': name,
        'phoneNumber': phone,
        'phone': phone, // For backward compatibility
        'address': address,
        // ✅ Store multiple pincodes as array
        'pincodes': pincodes,
        // ✅ Keep single pincode for backward compatibility
        'pincode': pincodes.isNotEmpty ? pincodes[0] : '',
        'description': description,
        'categories': selectedCategories,
        'workImages': previousWorkImageUrls,
        'idCardImage': idCardImageUrl,
        'profileImageUrl': profileImageUrl,
        'role': 'technician',
        'isActive': true,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .set(technicianData, SetOptions(merge: true));

      print('✅ Technician data saved successfully');
      print('📊 Service Areas: ${pincodes.join(", ")}');
      print('📊 Categories: ${selectedCategories.length} selected');

      return {
        'success': true,
        'message': 'Technician application submitted successfully',
        'data': technicianData,
      };
    } catch (e) {
      print('❌ Error saving technician data: $e');
      return {'success': false, 'message': 'Failed to save data: $e'};
    }
  }

  /// Update technician categories
  Future<bool> updateTechnicianCategories({
    required String userId,
    required List<String> categories,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'categories': categories,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Categories updated: ${categories.join(", ")}');
      return true;
    } catch (e) {
      print('❌ Error updating categories: $e');
      return false;
    }
  }

  /// Update technician pincodes
  Future<bool> updateTechnicianPincodes({
    required String userId,
    required List<String> pincodes,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'pincodes': pincodes,
        'pincode': pincodes.isNotEmpty ? pincodes[0] : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Pincodes updated: ${pincodes.join(", ")}');
      return true;
    } catch (e) {
      print('❌ Error updating pincodes: $e');
      return false;
    }
  }

  /// Add new pincode to technician
  Future<bool> addPincode({
    required String userId,
    required String pincode,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'pincodes': FieldValue.arrayUnion([pincode]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Pincode added: $pincode');
      return true;
    } catch (e) {
      print('❌ Error adding pincode: $e');
      return false;
    }
  }

  /// Remove pincode from technician
  Future<bool> removePincode({
    required String userId,
    required String pincode,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'pincodes': FieldValue.arrayRemove([pincode]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update single pincode field if needed
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final currentPincodes = List<String>.from(data?['pincodes'] ?? []);

      if (currentPincodes.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update({
          'pincode': currentPincodes[0],
        });
      } else {
        await _firestore.collection('users').doc(userId).update({
          'pincode': '',
        });
      }

      print('✅ Pincode removed: $pincode');
      return true;
    } catch (e) {
      print('❌ Error removing pincode: $e');
      return false;
    }
  }

  /// Add new work images to existing technician
  Future<bool> addWorkImages({
    required String userId,
    required List<String> newImageUrls,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'workImages': FieldValue.arrayUnion(newImageUrls),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Added ${newImageUrls.length} work images');
      return true;
    } catch (e) {
      print('❌ Error adding work images: $e');
      return false;
    }
  }

  /// Remove work image from technician
  Future<bool> removeWorkImage({
    required String userId,
    required String imageUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'workImages': FieldValue.arrayRemove([imageUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Work image removed');
      return true;
    } catch (e) {
      print('❌ Error removing work image: $e');
      return false;
    }
  }

  /// Get complete technician data
  Future<Map<String, dynamic>?> getTechnicianData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error getting technician data: $e');
      return null;
    }
  }

  /// Get technician pincodes only
  Future<List<String>> getTechnicianPincodes(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        // First try to get pincodes array
        if (data?['pincodes'] != null &&
            (data?['pincodes'] as List).isNotEmpty) {
          return List<String>.from(data!['pincodes']);
        }
        // Fallback to single pincode
        else if (data?['pincode'] != null &&
            data!['pincode'].toString().isNotEmpty) {
          return [data['pincode'].toString()];
        }
      }
      return [];
    } catch (e) {
      print('❌ Error getting pincodes: $e');
      return [];
    }
  }

  /// Get technician categories only
  Future<List<String>> getTechnicianCategories(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return List<String>.from(data?['categories'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Error getting categories: $e');
      return [];
    }
  }

  /// Update technician availability status
  Future<bool> updateTechnicianAvailability({
    required String userId,
    required bool isActive,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Availability updated: ${isActive ? "Online" : "Offline"}');
      return true;
    } catch (e) {
      print('❌ Error updating availability: $e');
      return false;
    }
  }

  /// Update technician profile
  Future<bool> updateTechnicianProfile({
    required String userId,
    String? name,
    String? phone,
    String? address,
    String? description,
    String? profileImageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phoneNumber'] = phone;
      if (address != null) updates['address'] = address;
      if (description != null) updates['description'] = description;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(userId).update(updates);
      print('✅ Profile updated');
      return true;
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  /// Check if technician exists
  Future<bool> technicianExists(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking technician existence: $e');
      return false;
    }
  }

  /// Update technician status (pending, approved, rejected)
  Future<bool> updateTechnicianStatus({
    required String userId,
    required String status,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Status updated to: $status');
      return true;
    } catch (e) {
      print('❌ Error updating status: $e');
      return false;
    }
  }
}
