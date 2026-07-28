// presentation/AdminScreen/admin_stats.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widget/hover_scale.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  bool _isLoading = true;
  DateTime? _lastUpdated;

  // Stats Data
  int _totalTechnicians = 0;
  int _totalCustomers = 0;
  int _newTechniciansToday = 0;
  int _newCustomersToday = 0;
  int _totalTasksToday = 0;
  int _totalTasksThisWeek = 0;
  int _totalTasksThisMonth = 0;

  // Daily data for charts
  List<DailyStats> _technicianDailyStats = [];
  List<DailyStats> _customerDailyStats = [];
  List<DailyStats> _taskDailyStats = [];

  // Monthly data
  List<MonthlyStats> _monthlyStats = [];

  // ==================== THEME ====================
  static const Color kBg = Color(0xFFF4F5FA);
  static const Color kIndigo = Color(0xFF6366F1);
  static const Color kViolet = Color(0xFF8B5CF6);
  static const Color kTeal = Color(0xFF14B8A6);
  static const Color kAmber = Color(0xFFF59E0B);
  static const Color kRose = Color(0xFFF43F5E);
  static const Color kInk = Color(0xFF1E1B2E);

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadTechnicianStats(),
        _loadCustomerStats(),
        _loadTaskStats(),
      ]);
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });
      }
    }
  }

  Future<void> _loadTechnicianStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'technician')
        .get();

    _totalTechnicians = snapshot.docs.length;

    _newTechniciansToday = snapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(today);
    }).length;

    _technicianDailyStats = [];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));

      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(date) &&
            createdAt.isBefore(nextDate);
      }).length;

      _technicianDailyStats.add(DailyStats(date: date, count: count));
    }
  }

  Future<void> _loadCustomerStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .get();

    _totalCustomers = snapshot.docs.length;

    _newCustomersToday = snapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(today);
    }).length;

    _customerDailyStats = [];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));

      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(date) &&
            createdAt.isBefore(nextDate);
      }).length;

      _customerDailyStats.add(DailyStats(date: date, count: count));
    }
  }

  Future<void> _loadTaskStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    final snapshot = await FirebaseFirestore.instance
        .collection('service_requests')
        .get();

    _totalTasksToday = snapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(today);
    }).length;

    _totalTasksThisWeek = snapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(weekAgo);
    }).length;

    _totalTasksThisMonth = snapshot.docs.where((doc) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      return createdAt != null && createdAt.isAfter(monthAgo);
    }).length;

    _taskDailyStats = [];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));

      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(date) &&
            createdAt.isBefore(nextDate);
      }).length;

      _taskDailyStats.add(DailyStats(date: date, count: count));
    }

    _monthlyStats = [];
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(now.year, now.month - i + 1, 1);

      final count = snapshot.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.isAfter(date) &&
            createdAt.isBefore(nextMonth);
      }).length;

      _monthlyStats.add(
        MonthlyStats(month: DateFormat('MMM yyyy').format(date), count: count),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: RefreshIndicator(
        onRefresh: _loadAllStats,
        color: kIndigo,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeaderBar(),
            SliverToBoxAdapter(
              child: _isLoading
                  ? SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildLoadingState(),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Overview'),
                          const SizedBox(height: 12),
                          _buildSummaryCards(context),
                          const SizedBox(height: 24),
                          _sectionLabel('Daily Trends'),
                          const SizedBox(height: 12),
                          _buildDailyStatsSection(),
                          const SizedBox(height: 24),
                          _sectionLabel('Monthly Overview'),
                          const SizedBox(height: 12),
                          _buildMonthlyStatsSection(),
                          const SizedBox(height: 24),
                          _sectionLabel('Detailed Summary'),
                          const SizedBox(height: 12),
                          _buildDetailedStats(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeaderBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: kIndigo,
      expandedHeight: 128,
      automaticallyImplyLeading: Navigator.canPop(context),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
        title: const Text(
          'Statistics & Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kIndigo, kViolet],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: _decoCircle(140, Colors.white.withValues(alpha: 0.08)),
              ),
              Positioned(
                right: 60,
                bottom: -40,
                child: _decoCircle(90, Colors.white.withValues(alpha: 0.06)),
              ),
              if (_lastUpdated != null)
                Positioned(
                  left: 20,
                  bottom: 44,
                  child: Text(
                    'Updated ${DateFormat('h:mm a').format(_lastUpdated!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: AnimatedRotation(
            turns: _isLoading ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: const Icon(Icons.refresh_rounded),
          ),
          onPressed: _isLoading ? null : _loadAllStats,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _decoCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: kIndigo,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kInk,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(strokeWidth: 3, color: kIndigo),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading statistics…',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ==================== SUMMARY CARDS ====================
  Widget _buildSummaryCards(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 420
        ? 2
        : width < 700
        ? 2
        : width < 1000
        ? 3
        : 4;
    final aspectRatio = width < 420 ? 1.25 : 1.35;

    final cards = [
      _CardData(
        title: 'Technicians',
        value: _totalTechnicians.toString(),
        subtitle: '+$_newTechniciansToday today',
        icon: Icons.build_rounded,
        colors: const [kIndigo, Color(0xFF818CF8)],
      ),
      _CardData(
        title: 'Customers',
        value: _totalCustomers.toString(),
        subtitle: '+$_newCustomersToday today',
        icon: Icons.people_alt_rounded,
        colors: const [kTeal, Color(0xFF5EEAD4)],
      ),
      _CardData(
        title: 'Tasks Today',
        value: _totalTasksToday.toString(),
        subtitle: 'Created today',
        icon: Icons.task_alt_rounded,
        colors: const [kAmber, Color(0xFFFCD34D)],
      ),
      _CardData(
        title: 'This Month',
        value: _totalTasksThisMonth.toString(),
        subtitle: 'Total tasks',
        icon: Icons.calendar_month_rounded,
        colors: const [kViolet, Color(0xFFC4B5FD)],
      ),
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      childAspectRatio: aspectRatio,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map(_buildSummaryCard).toList(),
    );
  }

  Widget _buildSummaryCard(_CardData data) {
    return HoverScale(
      hoverScale: 1.03,
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHovering
                  ? data.colors[0].withValues(alpha: 0.35)
                  : Colors.grey.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? data.colors[0].withValues(alpha: 0.28)
                    : Colors.grey.withValues(alpha: 0.10),
                blurRadius: isHovering ? 22 : 10,
                offset: Offset(0, isHovering ? 10 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: data.colors),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: data.colors[0].withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(data.icon, color: Colors.white, size: 18),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: data.colors[0],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== DAILY STATS SECTION ====================
  Widget _buildDailyStatsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDailyChart(
            title: 'Technicians Joined',
            data: _technicianDailyStats,
            colors: const [kIndigo, Color(0xFF818CF8)],
          ),
          const SizedBox(height: 22),
          _buildDailyChart(
            title: 'Customers Joined',
            data: _customerDailyStats,
            colors: const [kTeal, Color(0xFF5EEAD4)],
          ),
          const SizedBox(height: 22),
          _buildDailyChart(
            title: 'Tasks Created',
            data: _taskDailyStats,
            colors: const [kAmber, Color(0xFFFCD34D)],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChart({
    required String title,
    required List<DailyStats> data,
    required List<Color> colors,
  }) {
    final maxValue = data.isEmpty
        ? 1
        : data.map((e) => e.count).fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1 : maxValue;
    final allZero = data.every((e) => e.count == 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors[0].withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'max $safeMax',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors[0],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: allZero
              ? Center(
                  child: Text(
                    'No activity in the last 7 days',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade400,
                    ),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: data
                      .map(
                        (stat) => Expanded(
                          child: _HoverBar(
                            stat: stat,
                            colors: colors,
                            maxValue: safeMax,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ==================== MONTHLY STATS ====================
  Widget _buildMonthlyStatsSection() {
    final maxCount = _monthlyStats.isEmpty
        ? 1
        : _monthlyStats
              .map((e) => e.count)
              .fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxCount == 0 ? 1 : maxCount;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks created per month over the last 6 months',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _monthlyStats
                  .map(
                    (stat) => Expanded(
                      child: _HoverMonthBar(stat: stat, maxValue: safeMax),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DETAILED STATS ====================
  Widget _buildDetailedStats() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            'Total Technicians',
            _totalTechnicians.toString(),
            Icons.build_rounded,
            kIndigo,
          ),
          _divider(),
          _buildDetailRow(
            'Total Customers',
            _totalCustomers.toString(),
            Icons.people_alt_rounded,
            kTeal,
          ),
          _divider(),
          _buildDetailRow(
            'Tasks Today',
            _totalTasksToday.toString(),
            Icons.today_rounded,
            kAmber,
          ),
          _divider(),
          _buildDetailRow(
            'Tasks This Week',
            _totalTasksThisWeek.toString(),
            Icons.date_range_rounded,
            kViolet,
          ),
          _divider(),
          _buildDetailRow(
            'Tasks This Month',
            _totalTasksThisMonth.toString(),
            Icons.calendar_month_rounded,
            kRose,
          ),
          _divider(),
          _buildDetailRow(
            'New Technicians Today',
            '+$_newTechniciansToday',
            Icons.person_add_rounded,
            kIndigo,
          ),
          _divider(),
          _buildDetailRow(
            'New Customers Today',
            '+$_newCustomersToday',
            Icons.person_add_alt_1_rounded,
            kTeal,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade100);

  Widget _buildDetailRow(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return HoverScale(
      hoverScale: 1.0,
      builder: (context, isHovering, isPressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isHovering
                ? color.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kInk,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SHARED CARD WRAPPER ====================
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  _CardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });
}

// ==================== HOVER-ANIMATED DAILY BAR ====================
// Fixed: uses Expanded + LayoutBuilder for the bar area so the bar can
// NEVER exceed the space it's given, no matter the parent's height.
// This eliminates the "RenderFlex overflowed" error permanently.
class _HoverBar extends StatelessWidget {
  final DailyStats stat;
  final List<Color> colors;
  final int maxValue;

  const _HoverBar({
    required this.stat,
    required this.colors,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final double fraction = maxValue > 0
        ? (stat.count / maxValue).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return HoverScale(
      hoverScale: 1.0,
      builder: (context, isHovering, isPressed) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              stat.count.toString(),
              style: TextStyle(
                fontSize: 10,
                color: isHovering ? colors[0] : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // The bar always fits: it's constrained by Expanded, and its
            // fraction-based height is computed against the space actually
            // available via LayoutBuilder.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barHeight = (constraints.maxHeight * fraction).clamp(
                    4.0,
                    constraints.maxHeight,
                  );
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isHovering ? 20 : 16,
                      height: barHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isHovering
                            ? [
                                BoxShadow(
                                  color: colors[0].withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            colors[0],
                            colors[1].withValues(alpha: isHovering ? 0.9 : 0.6),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('E').format(stat.date),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        );
      },
    );
  }
}

// ==================== HOVER-ANIMATED MONTHLY BAR ====================
class _HoverMonthBar extends StatelessWidget {
  final MonthlyStats stat;
  final int maxValue;

  const _HoverMonthBar({required this.stat, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final double fraction = maxValue > 0
        ? (stat.count / maxValue).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return HoverScale(
      hoverScale: 1.0,
      builder: (context, isHovering, isPressed) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              stat.count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isHovering
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barHeight = (constraints.maxHeight * fraction).clamp(
                    4.0,
                    constraints.maxHeight,
                  );
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: barHeight,
                      width: isHovering ? 26 : 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: isHovering
                            ? [
                                const BoxShadow(
                                  color: Color(0x556366F1),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ]
                            : [],
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF6366F1), Color(0xFFA5B4FC)],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              stat.month,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
            ),
          ],
        );
      },
    );
  }
}

// ==================== DATA MODELS ====================
class DailyStats {
  final DateTime date;
  final int count;

  DailyStats({required this.date, required this.count});
}

class MonthlyStats {
  final String month;
  final int count;

  MonthlyStats({required this.month, required this.count});
}
