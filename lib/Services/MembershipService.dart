// lib/services/MembershipService.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/MembershipPlanModel.dart';

class MembershipService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== CHECK & ACTIVATE PLAN ====================

  /// Check and auto-activate 4-day free trial
  static Future<MembershipPlan?> checkAndActivatePlan() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return null;
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists || doc.data()?['plan'] == null) {
      print('📱 No plan found, activating 4-day free trial...');
      return await activateFreeTrial(user.uid);
    }

    final planData = doc.data()?['plan'] as Map<String, dynamic>;
    final plan = MembershipPlan.fromFirestore(planData);

    if (plan.isExpired) {
      print('⏰ Plan expired on: ${plan.expiryDate}');
      await docRef.update({'plan.isActive': false});
      return plan;
    }

    print('✅ Plan active. Days remaining: ${plan.daysRemaining}');
    return plan;
  }

  /// Activate 4-day free trial
  static Future<MembershipPlan> activateFreeTrial(String userId) async {
    final plan = MembershipPlan.createFreeTrial();

    await _firestore.collection('users').doc(userId).set({
      'plan': plan.toFirestore(),
    }, SetOptions(merge: true));

    print('✅ 4-day free trial activated for user: $userId');
    print('📅 Expires on: ${plan.expiryDate}');

    return plan;
  }

  // ==================== GET PLAN STATUS ====================

  /// 🔥 Get complete plan status for UI
  static Future<Map<String, dynamic>> getPlanStatus() async {
    final user = _auth.currentUser;

    // Default status when no user
    if (user == null) {
      return {
        'hasPlan': false,
        'isActive': false,
        'isExpired': true,
        'daysRemaining': 0,
        'planType': 'none',
        'isFreeTrial': false,
        'planLabel': 'No Plan',
        'expiryDate': null,
        'startDate': null,
        'trialUsed': false,
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        return _defaultStatus();
      }

      final planData = doc.data()?['plan'] as Map<String, dynamic>?;

      if (planData == null) {
        return _defaultStatus();
      }

      final plan = MembershipPlan.fromFirestore(planData);
      final isActive = plan.isActive && !plan.isExpired;

      // Get plan label
      String planLabel;
      switch (plan.planType) {
        case 'free_trial':
          planLabel = 'Free Trial';
          break;
        case '2_days':
          planLabel = '2 Days Plan';
          break;
        case '5_days':
          planLabel = '5 Days Plan';
          break;
        case '30_days':
          planLabel = '30 Days Plan';
          break;
        default:
          planLabel = plan.planType;
      }

      return {
        'hasPlan': true,
        'isActive': isActive,
        'isExpired': plan.isExpired,
        'daysRemaining': plan.daysRemaining,
        'planType': plan.planType,
        'isFreeTrial': plan.isFreeTrial,
        'planLabel': planLabel,
        'expiryDate': plan.expiryDate,
        'startDate': plan.startDate,
        'trialUsed': plan.trialUsed,
      };
    } catch (e) {
      print('❌ Error getting plan status: $e');
      return _defaultStatus();
    }
  }

  /// Default status when no plan exists
  static Map<String, dynamic> _defaultStatus() {
    return {
      'hasPlan': false,
      'isActive': false,
      'isExpired': true,
      'daysRemaining': 0,
      'planType': 'none',
      'isFreeTrial': false,
      'planLabel': 'No Plan',
      'expiryDate': null,
      'startDate': null,
      'trialUsed': false,
    };
  }

  // ==================== CHECK METHODS ====================

  /// Check if user has active plan
  static Future<bool> hasActivePlan() async {
    final status = await getPlanStatus();
    return status['isActive'] ?? false;
  }

  /// Get current plan
  static Future<MembershipPlan?> getCurrentPlan() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final planData = doc.data()?['plan'] as Map<String, dynamic>?;
      if (planData == null) return null;

      return MembershipPlan.fromFirestore(planData);
    } catch (e) {
      print('❌ Error getting plan: $e');
      return null;
    }
  }

  /// Get days remaining
  static Future<int> getDaysRemaining() async {
    final plan = await getCurrentPlan();
    if (plan == null) return 0;
    return plan.daysRemaining;
  }

  // ==================== UPDATE PLAN ====================

  /// Update plan (called from web after payment)
  static Future<void> updatePlan({
    required String userId,
    required String planType,
    required int durationDays,
  }) async {
    final plan = MembershipPlan.createPaidPlan(
      planType: planType,
      durationDays: durationDays,
    );

    await _firestore.collection('users').doc(userId).set({
      'plan': plan.toFirestore(),
    }, SetOptions(merge: true));

    print('✅ Plan updated for user: $userId');
    print('📅 Plan Type: $planType');
    print('📅 Expires on: ${plan.expiryDate}');
    print('📅 Days remaining: ${plan.daysRemaining}');
  }

  /// Renew plan (for testing)
  static Future<void> renewPlan() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final plan = MembershipPlan.createFreeTrial();
    await _firestore.collection('users').doc(user.uid).set({
      'plan': plan.toFirestore(),
    }, SetOptions(merge: true));

    print('✅ Plan renewed for user: ${user.uid}');
  }
}