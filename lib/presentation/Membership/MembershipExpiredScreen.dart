import 'dart:async';
import 'package:flutter/material.dart';

class MembershipExpiredScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const MembershipExpiredScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<MembershipExpiredScreen> createState() => _MembershipExpiredScreenState();
}

class _MembershipExpiredScreenState extends State<MembershipExpiredScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Auto dismiss after 7 seconds
    _timer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/membership/ExpireM.PNG',
          fit: BoxFit.contain, // 🔥 Full screen cover
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.white,
              child: Center(
                child: Icon(
                  Icons.credit_card_off,
                  size: 100,
                  color: Colors.orange.shade700,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}