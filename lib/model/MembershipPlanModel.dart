// lib/models/MembershipPlanModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MembershipPlan {
  final bool isActive;
  final DateTime startDate;
  final DateTime expiryDate;
  final String planType; // 'free_trial', '2_days', '5_days', '30_days'
  final bool trialUsed;

  MembershipPlan({
    required this.isActive,
    required this.startDate,
    required this.expiryDate,
    required this.planType,
    required this.trialUsed,
  });

  int get daysRemaining => expiryDate.difference(DateTime.now()).inDays;

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  bool get isFreeTrial => planType == 'free_trial';

  Map<String, dynamic> toFirestore() {
    return {
      'isActive': isActive,
      'startDate': Timestamp.fromDate(startDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'planType': planType,
      'trialUsed': trialUsed,
    };
  }

  factory MembershipPlan.fromFirestore(Map<String, dynamic> data) {
    return MembershipPlan(
      isActive: data['isActive'] ?? false,
      startDate: (data['startDate'] as Timestamp).toDate(),
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      planType: data['planType'] ?? 'free_trial',
      trialUsed: data['trialUsed'] ?? false,
    );
  }

  // 🔥 4-Day Free Trial
  static MembershipPlan createFreeTrial() {
    final now = DateTime.now();
    return MembershipPlan(
      isActive: true,
      startDate: now,
      expiryDate: now.add(const Duration(days: 4)),
      planType: 'free_trial',
      trialUsed: false,
    );
  }

  // 🔥 Paid Plans
  static MembershipPlan createPaidPlan({
    required String planType,
    required int durationDays,
  }) {
    final now = DateTime.now();
    return MembershipPlan(
      isActive: true,
      startDate: now,
      expiryDate: now.add(Duration(days: durationDays)),
      planType: planType,
      trialUsed: true,
    );
  }

  // 🔥 Plan Details
  static Map<String, dynamic> getPlanDetails(String planType) {
    final plans = {
      '2_days': {'duration': 2, 'price': 99, 'label': '2 Days'},
      '5_days': {'duration': 5, 'price': 249, 'label': '5 Days'},
      '30_days': {'duration': 30, 'price': 1499, 'label': '30 Days'},
    };
    return plans[planType] ?? {'duration': 0, 'price': 0, 'label': 'Unknown'};
  }
}