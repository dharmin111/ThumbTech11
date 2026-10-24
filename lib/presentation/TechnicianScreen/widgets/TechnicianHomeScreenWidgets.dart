// lib/presentation/TechnicianScreen/widgets/TechnicianHomeScreenWidgets.dart

import 'package:flutter/material.dart';

/// ✅ Welcome Banner Widget
class TechnicianWelcomeBanner extends StatelessWidget {
  final String? technicianName;

  const TechnicianWelcomeBanner({
    super.key,
    this.technicianName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2563EB).withOpacity(0.08),
            const Color(0xFF2563EB).withOpacity(0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 1),
          Text(
            technicianName ?? 'Technician',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ In-Between Banner Widget
class TechnicianInBetweenBanner extends StatelessWidget {
  final VoidCallback? onTap;
  final double height;

  const TechnicianInBetweenBanner({
    super.key,
    this.onTap,
    this.height = 240,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/AppLogoo/abservice.PNG',
            width: double.infinity,
            height: height,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: double.infinity,
                height: height,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Text(
                    'Banner not found',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ✅ Custom Action Card (Used for Service Areas & Service Categories)
class TechnicianCustomCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const TechnicianCustomCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported, color: Colors.blue, size: 20);
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0C1B4D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A92A6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF0C1B4D),
            ),
          ],
        ),
      ),
    );
  }
}

/// ✅ Availability Toggle Switch (Exact Gradient & Left Alignment)
class TechnicianAvailabilityToggle extends StatelessWidget {
  final bool isAvailable;
  final ValueChanged<bool> onChanged;

  const TechnicianAvailabilityToggle({
    super.key,
    required this.isAvailable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isAvailable
              ? [
                  const Color(0xFF07193A),
                  const Color(0xFF007A9E),
                  const Color(0xFF00C4CC),
                ]
              : [
                  const Color(0xFF1E293B),
                  const Color(0xFF334155),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isAvailable ? const Color(0xFF00C4CC) : Colors.black).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You are currently',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable ? 'Available for Jobs' : 'Offline',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? const Color(0xFF00E5FF) : Colors.grey.shade400,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAvailable
                      ? 'Turn off if you are not available'
                      : 'Turn on to start receiving jobs',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: isAvailable,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF10B981),
              activeThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.shade600,
              inactiveThumbColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Single Stat Card
class TechnicianStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const TechnicianStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ✅ Stats Cards Row (Tasks, Categories, Areas)
class TechnicianStatsCardsRow extends StatelessWidget {
  final int totalPending;
  final int categoriesCount;
  final int areasCount;

  const TechnicianStatsCardsRow({
    super.key,
    required this.totalPending,
    required this.categoriesCount,
    required this.areasCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TechnicianStatCard(
              title: 'Pending Tasks',
              value: totalPending.toString(),
              icon: Icons.pending_actions,
              color: totalPending > 0 ? Colors.orange : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TechnicianStatCard(
              title: 'Categories',
              value: categoriesCount.toString(),
              icon: Icons.category,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TechnicianStatCard(
              title: 'Areas',
              value: areasCount.toString(),
              icon: Icons.location_on,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Incomplete Profile Widget
class TechnicianIncompleteProfileWidget extends StatelessWidget {
  const TechnicianIncompleteProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange[400]),
          const SizedBox(height: 16),
          const Text(
            'Profile Incomplete',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please complete your profile to start receiving requests.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// ✅ Offline Widget
class TechnicianOfflineWidget extends StatelessWidget {
  const TechnicianOfflineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.toggle_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'You are offline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn on availability to see pending service requests.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// ✅ Empty State Widget
class TechnicianEmptyWidget extends StatelessWidget {
  const TechnicianEmptyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No pending requests',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks matching your categories and pincodes will appear here automatically',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ✅ Cooldown Widget
class TechnicianCooldownWidget extends StatelessWidget {
  final int remainingCooldownSeconds;

  const TechnicianCooldownWidget({
    super.key,
    required this.remainingCooldownSeconds,
  });

  @override
  Widget build(BuildContext context) {
    int mins = remainingCooldownSeconds ~/ 60;
    int secs = remainingCooldownSeconds % 60;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.timer_outlined, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Task Accept Cooldown Active',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You recently accepted a task. Next task will be available in:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Text(
            '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
