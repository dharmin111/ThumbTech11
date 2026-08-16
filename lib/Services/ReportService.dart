// lib/Services/ReportService.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== REPORT CONTENT ====================

  static Future<void> reportContent({
    required String targetId,
    required String targetType, // 'booking', 'message', 'technician', 'service', 'user'
    required String targetName,
    required String reason,
    String? additionalInfo,
    String? reporterId,
  }) async {
    try {
      final userId = reporterId ?? _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Check if already reported this content
      final existingReport = await _firestore
          .collection('reports')
          .where('targetId', isEqualTo: targetId)
          .where('reporterId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingReport.docs.isNotEmpty) {
        throw Exception('You have already reported this content');
      }

      // Save report
      await _firestore.collection('reports').add({
        'targetId': targetId,
        'targetType': targetType,
        'targetName': targetName,
        'reason': reason,
        'additionalInfo': additionalInfo ?? '',
        'reporterId': userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to admin
      await _sendAdminNotification(targetId, targetType, targetName, reason);

      print('✅ Report submitted successfully');
    } catch (e) {
      print('❌ Error submitting report: $e');
      rethrow;
    }
  }

  static Future<void> _sendAdminNotification(
      String targetId,
      String targetType,
      String targetName,
      String reason,
      ) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': 'report',
        'targetId': targetId,
        'targetType': targetType,
        'targetName': targetName,
        'reason': reason,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Admin notification sent');
    } catch (e) {
      print('❌ Error sending admin notification: $e');
    }
  }

  // ==================== BLOCK USER ====================

  static Future<void> blockUser({
    required String blockedUserId,
    required String blockedUserName,
    String? blockerId,
  }) async {
    try {
      final userId = blockerId ?? _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      if (userId == blockedUserId) {
        throw Exception('You cannot block yourself');
      }

      // Check if already blocked
      final existingBlock = await _firestore
          .collection('blocked_users')
          .doc('${userId}_$blockedUserId')
          .get();

      if (existingBlock.exists) {
        throw Exception('User already blocked');
      }

      // Add to blocked list
      await _firestore.collection('blocked_users').doc('${userId}_$blockedUserId').set({
        'blockerId': userId,
        'blockedUserId': blockedUserId,
        'blockedUserName': blockedUserName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ User blocked successfully');
    } catch (e) {
      print('❌ Error blocking user: $e');
      rethrow;
    }
  }

  static Future<void> unblockUser({
    required String blockedUserId,
    String? blockerId,
  }) async {
    try {
      final userId = blockerId ?? _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      await _firestore
          .collection('blocked_users')
          .doc('${userId}_$blockedUserId')
          .delete();

      print('✅ User unblocked successfully');
    } catch (e) {
      print('❌ Error unblocking user: $e');
      rethrow;
    }
  }

  static Future<bool> isUserBlocked({
    required String userId,
    required String otherUserId,
  }) async {
    try {
      final doc = await _firestore
          .collection('blocked_users')
          .doc('${userId}_$otherUserId')
          .get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking block status: $e');
      return false;
    }
  }

  static Stream<List<Map<String, dynamic>>> getBlockedUsers(String userId) {
    return _firestore
        .collection('blocked_users')
        .where('blockerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ==================== GET REPORTS ====================

  static Stream<List<Map<String, dynamic>>> getPendingReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  static Future<void> updateReportStatus({
    required String reportId,
    required String status, // 'resolved', 'dismissed'
    String? adminNote,
  }) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status,
        'adminNote': adminNote ?? '',
        'resolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Report status updated to $status');
    } catch (e) {
      print('❌ Error updating report status: $e');
      rethrow;
    }
  }
}