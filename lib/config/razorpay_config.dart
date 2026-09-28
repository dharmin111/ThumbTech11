// lib/config/razorpay_config.dart

class RazorpayConfig {
  // 🔥 Your Live Key ID
  static const String keyId = 'rzp_live_SPtichTOa5mXBH';

  // 🔥 Updated Plans - Only 2 Plans
  static const Map<String, dynamic> plans = {
    '2_days': {
      'name': '2 Days Plan',
      'price': 99,      // ₹99 for 2 days
      'duration': 2,
    },
    '5_days': {
      'name': '5 Days Plan',
      'price': 249,     // ₹249 for 5 days
      'duration': 5,
    },
    // '30_days': {
    //   'name': '30 Days Plan',
    //   'price': 1499,
    //   'duration': 30,
    // }, // 🔥 Commented - Will add later
  };

  static Map<String, dynamic>? getPlan(String planType) {
    return plans[planType];
  }

  static int getPlanPrice(String planType) {
    return plans[planType]?['price'] ?? 0;
  }

  static int getPlanDuration(String planType) {
    return plans[planType]?['duration'] ?? 0;
  }

  static String getPlanName(String planType) {
    return plans[planType]?['name'] ?? planType;
  }
}