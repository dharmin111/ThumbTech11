import 'package:shared_preferences/shared_preferences.dart';

class TaskCooldownService {
  static const String _lastAcceptedKey = 'last_task_accepted_timestamp';
  static const int cooldownMinutes = 10;

  /// Call this when a technician accepts a task
  static Future<void> recordTaskAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastAcceptedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns true if the technician is currently in the 10-minute cooldown period
  static Future<bool> isInCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAccepted = prefs.getInt(_lastAcceptedKey);

    if (lastAccepted == null) return false;

    final lastAcceptedTime = DateTime.fromMillisecondsSinceEpoch(lastAccepted);
    final difference = DateTime.now().difference(lastAcceptedTime);

    return difference.inMinutes < cooldownMinutes;
  }

  /// Returns the remaining cooldown time in seconds
  static Future<int> getRemainingCooldownSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAccepted = prefs.getInt(_lastAcceptedKey);

    if (lastAccepted == null) return 0;

    final lastAcceptedTime = DateTime.fromMillisecondsSinceEpoch(lastAccepted);
    final difference = DateTime.now().difference(lastAcceptedTime);
    
    final remaining = (cooldownMinutes * 60) - difference.inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
