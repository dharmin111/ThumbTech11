// services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Admin_Model/AdminModel.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Register Admin
  Future<String> registerAdmin(AdminModel admin) async {
    try {
      final docRef = _firestore.collection('users').doc(admin.uid);
      await docRef.set(admin.toMap());
      return 'Admin registered successfully! Waiting for approval.';
    } catch (e) {
      throw Exception('Failed to register admin: $e');
    }
  }

  // ✅ Get Admin by UID
  Future<AdminModel?> getAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AdminModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get admin: $e');
    }
  }

  // ✅ Get Admin by Email
  Future<AdminModel?> getAdminByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return AdminModel.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get admin by email: $e');
    }
  }

  // ✅ Get All Admins
  Stream<List<AdminModel>> getAllAdmins() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AdminModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ✅ Get Pending Admins (for approval)
  Stream<List<AdminModel>> getPendingAdmins() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AdminModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ✅ Update Admin
  Future<void> updateAdmin(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update admin: $e');
    }
  }

  // ✅ Approve Admin
  Future<void> approveAdmin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ Add to activity log
      await _addActivityLog(uid, 'Admin account approved');
    } catch (e) {
      throw Exception('Failed to approve admin: $e');
    }
  }

  // ✅ Reject Admin (Delete)
  Future<void> rejectAdmin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to reject admin: $e');
    }
  }

  // ✅ Toggle Admin Status
  Future<void> toggleAdminStatus(String uid, bool isActive) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final status = isActive ? 'activated' : 'deactivated';
      await _addActivityLog(uid, 'Admin account $status');
    } catch (e) {
      throw Exception('Failed to toggle admin status: $e');
    }
  }

  // ✅ Update Last Login
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update last login: $e');
    }
  }

  // ✅ Add Activity Log
  Future<void> _addActivityLog(String uid, String activity) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      await docRef.update({
        'activityLog': FieldValue.arrayUnion([activity]),
      });
    } catch (e) {
      // Don't throw, just log
      print('Failed to add activity log: $e');
    }
  }

  // ✅ Check if Admin is Approved
  Future<bool> isAdminApproved(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['role'] == 'admin' && data['isApproved'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ✅ Delete Admin
  Future<void> deleteAdmin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete admin: $e');
    }
  }

  // ✅ Get Admin Statistics
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final allAdmins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final pendingAdmins = allAdmins.docs
          .where((doc) => doc.data()['isApproved'] == false)
          .length;

      final activeAdmins = allAdmins.docs
          .where((doc) => doc.data()['isActive'] == true)
          .length;

      return {
        'total': allAdmins.docs.length,
        'pending': pendingAdmins,
        'active': activeAdmins,
        'inactive': allAdmins.docs.length - activeAdmins,
      };
    } catch (e) {
      throw Exception('Failed to get admin stats: $e');
    }
  }

  // ✅ Search Admins
  Future<List<AdminModel>> searchAdmins(String query) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      return snapshot.docs
          .map((doc) => AdminModel.fromMap(doc.data(), doc.id))
          .where((admin) =>
      admin.name.toLowerCase().contains(query.toLowerCase()) ||
          admin.email.toLowerCase().contains(query.toLowerCase()) ||
          admin.phone.contains(query))
          .toList();
    } catch (e) {
      throw Exception('Failed to search admins: $e');
    }
  }

  // ✅ Get Recent Admins (last 10)
  Future<List<AdminModel>> getRecentAdmins() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => AdminModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get recent admins: $e');
    }
  }

  // ✅ Update Admin Permissions (Future Role-Based Access)
  Future<void> updatePermissions(String uid, Map<String, dynamic> permissions) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'permissions': permissions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update permissions: $e');
    }
  }

  // ✅ Check Permission
  Future<bool> hasPermission(String uid, String permission) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final permissions = data['permissions'] ?? {};
        return permissions[permission] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}