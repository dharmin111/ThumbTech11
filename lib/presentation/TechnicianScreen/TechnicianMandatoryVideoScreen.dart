// lib/presentation/TechnicianScreen/TechnicianMandatoryVideoScreen.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class TechnicianMandatoryVideoScreen extends StatefulWidget {
  final VoidCallback onVideoCompleted;

  const TechnicianMandatoryVideoScreen({
    super.key,
    required this.onVideoCompleted,
  });

  /// Helper static method to check if video needs to be played
  static Future<bool> shouldPlayVideo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final String uid = user.uid;

    final bool isCompletedPref = prefs.getBool('video_completed_$uid') ?? false;
    final int? lastPlayTimeMillis = prefs.getInt('video_last_play_$uid');

    // 1. If never completed watching startVideo: MUST PLAY!
    if (!isCompletedPref) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && (doc.data()?['startVideoCompleted'] ?? false) == true) {
          await prefs.setBool('video_completed_$uid', true);
          final Timestamp? fsLastTime = doc.data()?['lastStartVideoTime'] as Timestamp?;
          if (fsLastTime != null) {
            final lastDate = fsLastTime.toDate();
            if (DateTime.now().difference(lastDate).inHours < 24) {
              return false; // Played within last 24h
            }
          }
        } else {
          return true; // Never completed!
        }
      } catch (e) {
        return true;
      }
    }

    // 2. If already completed once, check 24-hour rule
    if (lastPlayTimeMillis != null) {
      final lastPlayDate = DateTime.fromMillisecondsSinceEpoch(lastPlayTimeMillis);
      final differenceInHours = DateTime.now().difference(lastPlayDate).inHours;
      if (differenceInHours >= 24) {
        return true; // 24 hours passed, MUST play again!
      } else {
        return false; // Played recently within 24h
      }
    } else {
      return true; // No timestamp recorded, MUST play!
    }
  }

  @override
  State<TechnicianMandatoryVideoScreen> createState() => _TechnicianMandatoryVideoScreenState();
}

class _TechnicianMandatoryVideoScreenState extends State<TechnicianMandatoryVideoScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isCompleted = false;
  bool _hasError = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/startVideo.MP4');
      await _controller.initialize();

      _controller.addListener(() {
        if (!mounted) return;

        final duration = _controller.value.duration;
        final position = _controller.value.position;

        if (duration.inMilliseconds > 0) {
          setState(() {
            _progress = position.inMilliseconds / duration.inMilliseconds;
          });
        }

        // Check if video reached 100% completion
        if (position >= duration && duration.inMilliseconds > 0 && !_isCompleted) {
          _onVideoFinished();
        }
      });

      await _controller.play();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Error loading mandatory startVideo: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _onVideoFinished() async {
    if (_isCompleted) return;
    setState(() {
      _isCompleted = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final prefs = await SharedPreferences.getInstance();

      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      await prefs.setBool('video_completed_$uid', true);
      await prefs.setInt('video_last_play_$uid', nowMillis);

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'startVideoCompleted': true,
          'lastStartVideoTime': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating Firestore startVideoCompleted: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryCyan = Color(0xFF00C4CC);

    return PopScope(
      canPop: false, // 🚫 CANNOT BE DISMISSED VIA BACK GESTURE
      child: Scaffold(
        backgroundColor: Colors.transparent, // ✅ Transparent for dashboard blur
        body: Stack(
          children: [
            // 1. BLURRED DASHBOARD BACKGROUND OVERLAY
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),

            // 2. CENTERED DIALOG CARD WITH MARGINS & SHADOW
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F1D),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: primaryCyan.withOpacity(0.25),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // TOP HEADER BANNER
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.white.withOpacity(0.08),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: primaryCyan, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Important Guidelines Video',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isCompleted)
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ),
                      ),

                      // VIDEO PLAYER AREA
                      Flexible(
                        child: Container(
                          color: Colors.black,
                          child: _isInitialized && !_hasError
                              ? AspectRatio(
                                  aspectRatio: _controller.value.aspectRatio > 0
                                      ? _controller.value.aspectRatio
                                      : 16 / 9,
                                  child: VideoPlayer(_controller),
                                )
                              : _hasError
                                  ? Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Video could not be loaded',
                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: () {
                                              _onVideoFinished();
                                              widget.onVideoCompleted();
                                            },
                                            style: ElevatedButton.styleFrom(backgroundColor: primaryCyan),
                                            child: const Text('Continue to Dashboard'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const Padding(
                                      padding: EdgeInsets.all(40.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: primaryCyan),
                                          SizedBox(height: 16),
                                          Text(
                                            'Loading Guidelines Video...',
                                            style: TextStyle(color: Colors.white, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                        ),
                      ),

                      // BOTTOM PROGRESS & CONTINUE BUTTON
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white.withOpacity(0.05),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // PROGRESS BAR
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress.clamp(0.0, 1.0),
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isCompleted ? Colors.green : primaryCyan,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // CONTINUE BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isCompleted
                                    ? () {
                                        widget.onVideoCompleted();
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isCompleted ? Colors.green : Colors.grey.shade800,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade800,
                                  disabledForegroundColor: Colors.white38,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _isCompleted
                                      ? 'CONTINUE TO DASHBOARD ✓'
                                      : 'WATCH FULL VIDEO TO CONTINUE (${(_progress * 100).toInt()}%)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
