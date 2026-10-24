// widgets/TechnicianHomeScreen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:thumstechs/presentation/TechnicianScreen/TechnicianProfileScreen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../Services/oneSignalNotificationService.dart';
import '../../Services/MembershipService.dart';
import '../../Services/TaskCooldownService.dart';
import '../Membership/MembershipScreen.dart';
import '../membership/MembershipExpiredScreen.dart';
import 'TechnicianMyServicesScreen.dart';
import 'YouTubeVideoPlayerScreen.dart';
import 'TechnicianAreasScreen.dart';
import 'TechnicianCategoriesScreen.dart';
import 'TechnicianMandatoryVideoScreen.dart';
import 'widgets/TechnicianHomeScreenWidgets.dart';

class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  String? technicianName;
  List<String> technicianCategories = [];
  List<String> technicianPincodes = [];
  bool isAvailable = true;
  bool isLoading = true;
  bool _isActive = true;

  int totalPending = 0;
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _requestsStream;
  int _lastRequestCount = 0;
  bool _isPopupShowing = false;
  bool _isFirstSnapshot = true;
  String? _highlightedRequestId;
  bool _shouldHighlight = false;
  final ScrollController _scrollController = ScrollController();

  // Cooldown logic
  bool _isOnCooldown = false;
  int _remainingCooldownSeconds = 0;
  Timer? _cooldownTimer;

  static const int _expireMinutes = 2;
  static const String _membershipUrl = 'https://thumbtech-521ae.web.app/plans';

  @override
  void initState() {
    super.initState();
    _loadDataDirectly();
    _checkCooldownStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMandatoryVideo();
    });
  }

  Future<void> _checkMandatoryVideo() async {
    final bool shouldPlay = await TechnicianMandatoryVideoScreen.shouldPlayVideo();
    if (shouldPlay && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (context) => TechnicianMandatoryVideoScreen(
          onVideoCompleted: () {
            Navigator.pop(context);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _isActive = false;
    _scrollController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ================= 🔥 COOLDOWN LOGIC =================
  Future<void> _checkCooldownStatus() async {
    final onCooldown = await TaskCooldownService.isInCooldown();
    if (mounted) {
      setState(() {
        _isOnCooldown = onCooldown;
      });
      if (_isOnCooldown) {
        _startCooldownTimer();
      }
    }
  }

  void _startCooldownTimer() async {
    _cooldownTimer?.cancel();
    _remainingCooldownSeconds = await TaskCooldownService.getRemainingCooldownSeconds();

    if (_remainingCooldownSeconds > 0) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_remainingCooldownSeconds > 0) {
          setState(() {
            _remainingCooldownSeconds--;
          });
        } else {
          timer.cancel();
          setState(() {
            _isOnCooldown = false;
          });
          _setupRealTimeStream(); // Refresh stream when cooldown ends
        }
      });
    }
  }

  // ================= 🔥 DIRECT LOAD =================
  Future<void> _loadDataDirectly() async {
    setState(() {
      isLoading = true;
    });
    await _fetchTechnicianData();
    setState(() {
      isLoading = false;
    });
  }

  // ================= 🔥 OPEN MEMBERSHIP WEBSITE =================
  Future<void> _openMembershipWebsite() async {
    try {
      final url = Uri.parse(_membershipUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch URL';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening website: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= FETCH TECHNICIAN DATA =================
  Future<void> _fetchTechnicianData() async {
    if (!_isActive || !mounted) return;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
        _showIncompleteProfileDialog();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      List<String> pincodesList = [];
      if (data['pincodes'] != null && (data['pincodes'] as List).isNotEmpty) {
        pincodesList = List<String>.from(data['pincodes']);
      } else if (data['pincode'] != null &&
          data['pincode'].toString().isNotEmpty) {
        pincodesList = [data['pincode'].toString()];
      }

      if (!_isActive || !mounted) return;

      setState(() {
        technicianName = data['name'] ?? 'Technician';
        technicianCategories = List<String>.from(data['categories'] ?? []);
        technicianPincodes = pincodesList;
        isAvailable = data['isActive'] ?? true;
      });

      if (technicianCategories.isNotEmpty && technicianPincodes.isNotEmpty) {
        _setupRealTimeStream();
      } else {
        if (!_isActive || !mounted) return;
        setState(() {
          isLoading = false;
        });
        _showIncompleteProfileDialog();
      }
    } catch (e) {
      print('❌ Error fetching technician data: $e');
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // ================= 🔥 SETUP REAL-TIME STREAM WITH AUTO-EXPIRE =================
  void _setupRealTimeStream() {
    if (technicianCategories.isEmpty || technicianPincodes.isEmpty) {
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      _requestsStream = FirebaseFirestore.instance
          .collection('service_requests')
          .where('status', isEqualTo: 'pending')
          .where('technicianId', isNull: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
        // If technician is on cooldown, don't show any tasks
        if (_isOnCooldown) {
          if (mounted) {
            setState(() {
              totalPending = 0;
            });
          }
          return [];
        }

        final now = DateTime.now();
        final expiredIds = <String>[];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null) {
            final diff = now.difference(createdAt);
            if (diff.inMinutes >= _expireMinutes) {
              expiredIds.add(doc.id);
              print('⏰ Request ${doc.id} expired (${diff.inMinutes} minutes old)');
            }
          }
        }

        if (expiredIds.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final id in expiredIds) {
            final ref = FirebaseFirestore.instance
                .collection('service_requests')
                .doc(id);
            batch.update(ref, {
              'status': 'expired',
              'expiredAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          batch.commit().catchError((e) {
            print('❌ Error updating expired requests: $e');
          });
        }

        final filteredDocs = snapshot.docs.where((doc) {
          final data = doc.data();
          final serviceType = data['serviceType']?.toString() ?? '';
          final customerPincode = data['pincode']?.toString() ?? '';
          final status = data['status'] ?? 'pending';

          if (status != 'pending') return false;

          final categoryMatches = technicianCategories.contains(serviceType);
          final pincodeMatches = technicianPincodes.contains(customerPincode);

          return categoryMatches && pincodeMatches;
        }).toList();

        print('📊 Filtered Docs Count: ${filteredDocs.length}');

        if (_isFirstSnapshot) {
          _lastRequestCount = filteredDocs.length;
          _isFirstSnapshot = false;
          print('📊 First snapshot, count: $_lastRequestCount');
        } else {
          if (filteredDocs.length > _lastRequestCount &&
              filteredDocs.isNotEmpty) {
            final newRequest = filteredDocs.first;
            final data = newRequest.data();

            print('🔔 NEW REQUEST DETECTED!');
            print('📦 Request ID: ${data['requestId']}');
            print('📦 Service Name: ${data['serviceName']}');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showNewTaskPopup(data);
              }
            });
          }
          _lastRequestCount = filteredDocs.length;
        }

        if (mounted) {
          setState(() {
            totalPending = filteredDocs.length;
          });
        }

        return filteredDocs;
      });

      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });

      print('✅ Real-time stream setup complete');
      print('📊 Categories: ${technicianCategories.join(", ")}');
      print('📊 Pincodes: ${technicianPincodes.join(", ")}');
    } catch (e) {
      print('❌ Error setting up stream: $e');
      if (!_isActive || !mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // ✅ Check if visiting charges text should show
  bool _shouldShowVisitingChargesText(Map<String, dynamic> data) {
    String serviceType = data['serviceType']?.toString() ?? '';
    double budget = (data['budget'] ?? 0).toDouble();

    bool isWaterPurifier =
    serviceType.toLowerCase().contains('water purifier');
    bool isBudget199 = budget == 199.0;

    return isWaterPurifier && isBudget199;
  }

  // ✅ Build Visiting Charges Note Widget
  Widget _buildVisitingChargesNote(Map<String, dynamic> data) {
    bool isWaterPurifier = data['serviceType']
        ?.toString()
        .toLowerCase()
        .contains('water purifier') ??
        false;
    double budget = (data['budget'] ?? 0).toDouble();

    if (!isWaterPurifier || budget != 199.0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '₹199 applies if No work is done.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No visiting charges if customer get the service.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ DISPLAY SERVICE NAME (Washing Machine + Asset video)
  // ═══════════════════════════════════════════════════════
  String _getDisplayServiceName(Map<String, dynamic> data) {
    final String serviceName =
        data['serviceName']?.toString() ?? 'Service Request';
    final String serviceType = data['serviceType']?.toString() ?? '';
    final String videoId = data['videoId']?.toString() ?? '';

    final bool isWashingMachine =
        serviceType.toLowerCase().contains('washing machine') ||
            serviceName.toLowerCase().contains('washing machine');

    final bool hasAssetVideo = videoId.startsWith('assets/');

    // ✅ Washing Machine + Asset video → Deep Cleaning
    if (isWashingMachine && hasAssetVideo) {
      return 'Washing Machine Deep Cleaning';
    }

    return serviceName;
  }

  // ═══════════════════════════════════════════════════════
  // ✅ VIDEO HELPERS — YouTube + Asset
  // ═══════════════════════════════════════════════════════

  bool _isAssetVideo(String videoId) {
    return videoId.startsWith('assets/');
  }

  bool _isYouTubeVideo(String videoId) {
    return videoId.isNotEmpty && !videoId.startsWith('assets/');
  }

  // ═══════════════════════════════════════════════════════
  // ✅ MAP LOGIC
  // ═══════════════════════════════════════════════════════
  bool _hasLocation(Map<String, dynamic> data) {
    final locationModel = data['locationModel'];

    if (locationModel is Map<String, dynamic>) {
      return locationModel['latitude'] != null &&
          locationModel['longitude'] != null;
    }

    if (locationModel is GeoPoint) {
      return true;
    }

    final address = data['location'] as String? ?? '';
    return address.isNotEmpty;
  }

  Future<void> _openMap(Map<String, dynamic> data) async {
    try {
      final locationData = data['locationModel'];

      double? latitude;
      double? longitude;

      if (locationData is Map<String, dynamic>) {
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        if (lat != null && lng != null) {
          latitude = (lat as num).toDouble();
          longitude = (lng as num).toDouble();
        }
      } else if (locationData is GeoPoint) {
        latitude = locationData.latitude;
        longitude = locationData.longitude;
      }

      if (latitude == null || longitude == null) {
        final addressText = data['location'] as String? ?? '';
        if (addressText.isNotEmpty) {
          final Uri url = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addressText)}',
          );

          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            _showSnack('Cannot open Google Maps', Colors.red);
          }
          return;
        } else {
          _showSnack('No location available for this request', Colors.orange);
          return;
        }
      }

      final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );

      print('🗺️ Opening map: $latitude, $longitude');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Cannot open Google Maps', Colors.red);
      }
    } catch (e) {
      print('❌ Error opening map: $e');
      _showSnack('Error opening map: $e', Colors.red);
    }
  }

  Future<void> _openMapWithDirections(Map<String, dynamic> data) async {
    try {
      final locationData = data['locationModel'];

      double? latitude;
      double? longitude;

      if (locationData is Map<String, dynamic>) {
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        if (lat != null && lng != null) {
          latitude = (lat as num).toDouble();
          longitude = (lng as num).toDouble();
        }
      } else if (locationData is GeoPoint) {
        latitude = locationData.latitude;
        longitude = locationData.longitude;
      }

      if (latitude == null || longitude == null) {
        _showSnack('No GPS location available', Colors.orange);
        return;
      }

      final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Cannot open Google Maps', Colors.red);
      }
    } catch (e) {
      print('❌ Error opening directions: $e');
      _showSnack('Error: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================= POPUP FUNCTIONS =================
  void _showNewTaskPopup(Map<String, dynamic> data) {
    if (!mounted || _isPopupShowing || _isOnCooldown) return;

    bool showVisitingCharges = _shouldShowVisitingChargesText(data);
    bool hasLocation = _hasLocation(data);

    _isPopupShowing = true;
    final String requestId = data['requestId'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "New Service Request",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getDisplayServiceName(data),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF0C1B4D),
                ),
              ),
              const SizedBox(height: 12),
              _buildPopupDetailRow('Customer', data['userName'] ?? 'N/A'),
              const SizedBox(height: 6),
              _buildPopupDetailRow('Budget', '₹${data['budget'] ?? 0}'),
              if (showVisitingCharges) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '199 INR Visiting Charges',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              _buildPopupDetailRow('Location', data['location'] ?? 'N/A'),
              const SizedBox(height: 6),
              _buildPopupDetailRow('Pincode', data['pincode'] ?? 'N/A'),
              if (data['issue'] != null && data['issue'].isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildPopupDetailRow('Issue', data['issue']),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: hasLocation ? () => _openMap(data) : null,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text(
                    hasLocation ? 'Get Direction' : 'No location',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: BorderSide(
                      color: hasLocation
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _isPopupShowing = false;
                Navigator.pop(context);
                setState(() {
                  _highlightedRequestId = null;
                  _shouldHighlight = false;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _isPopupShowing = false;
                Navigator.pop(context);

                setState(() {
                  _highlightedRequestId = requestId;
                  _shouldHighlight = true;
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToHighlightedCard();
                });

                Future.delayed(const Duration(seconds: 30), () {
                  if (mounted) {
                    setState(() {
                      _highlightedRequestId = null;
                      _shouldHighlight = false;
                    });
                  }
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔍 New task highlighted in green!'),
                    backgroundColor: Color(0xFF2563EB),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Now',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _isPopupShowing = false;
    });
  }

  void _scrollToHighlightedCard() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
        print('📜 Scrolled to highlighted card');
      }
    });
  }

  Widget _buildPopupDetailRow(String label, String value,
      {bool isLocked = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isLocked ? Colors.red : const Color(0xFF0C1B4D),
            ),
          ),
        ),
      ],
    );
  }

  // ================= 🔥 ACCEPT REQUEST =================
  Future<void> _acceptRequest(
      String requestId, Map<String, dynamic> requestData) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      );

      final techDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!techDoc.exists) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Technician profile not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final techData = techDoc.data() as Map<String, dynamic>;

      String technicianName = techData['name'] ?? 'Technician';
      String technicianPhone =
          techData['phone'] ?? techData['phoneNumber'] ?? user.phoneNumber ?? '';
      String technicianProfileImage = techData['profileImageUrl'] ?? '';
      String technicianEmail = techData['email'] ?? user.email ?? '';

      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'technicianId': user.uid,
        'technicianName': technicianName,
        'technicianPhone': technicianPhone,
        'technicianProfileImage': technicianProfileImage,
        'technicianEmail': technicianEmail,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 🔥 Record acceptance for cooldown
      await TaskCooldownService.recordTaskAcceptance();
      _checkCooldownStatus();

      final pendingDoc = await FirebaseFirestore.instance
          .collection('technician_pending_requests')
          .doc('${user.uid}_$requestId')
          .get();

      if (pendingDoc.exists) {
        await pendingDoc.reference.delete();
      }

      await _createConversation(
        requestId: requestId,
        customerId: requestData['userId'] ?? '',
        customerName: requestData['userName'] ?? 'Customer',
        technicianId: user.uid,
        technicianName: technicianName,
      );

      await OneSignalNotificationService.sendRequestAcceptedNotification(
        customerId: requestData['userId'],
        technicianName: technicianName,
        technicianPhone: technicianPhone,
        requestId: requestId,
        serviceName: requestData['serviceName'] ?? 'Service',
      );

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': requestData['userId'],
        'userRole': 'customer',
        'title': '✅ Request Accepted!',
        'body': '$technicianName has accepted your service request.',
        'type': 'request_accepted',
        'requestId': requestId,
        'technicianName': technicianName,
        'technicianPhone': technicianPhone,
        'technicianProfileImage': technicianProfileImage,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': user.uid,
        'userRole': 'technician',
        'title': '✅ Request Accepted Successfully!',
        'body':
        'You have accepted the service request from ${requestData['userName']}.',
        'type': 'task_accepted',
        'requestId': requestId,
        'customerName': requestData['userName'],
        'customerPhone': requestData['userPhone'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Service request accepted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TechnicianMyServicesScreen(),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('❌ Error accepting request: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createConversation({
    required String requestId,
    required String customerId,
    required String customerName,
    required String technicianId,
    required String technicianName,
  }) async {
    try {
      if (customerId.isEmpty || technicianId.isEmpty) {
        print('⚠️ Cannot create conversation: Missing customerId or technicianId');
        return;
      }

      final conversationId = _generateConversationId(
        customerId,
        technicianId,
        requestId,
      );

      final conversationRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId);

      final conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        await conversationRef.set({
          'conversationId': conversationId,
          'requestId': requestId,
          'customerId': customerId,
          'customerName': customerName,
          'technicianId': technicianId,
          'technicianName': technicianName,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'customerUnreadCount': 0,
          'technicianUnreadCount': 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Conversation created: $conversationId');
      } else {
        await conversationRef.update({
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Conversation already exists: $conversationId');
      }
    } catch (e) {
      print('❌ Error creating conversation: $e');
    }
  }

  String _generateConversationId(
      String userId1, String userId2, String requestId) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}_$requestId';
  }

  // ================= REJECT REQUEST =================
  Future<void> _rejectRequest(String requestId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await OneSignalNotificationService.sendRequestRejectedNotification(
        customerId: requestData['userId'],
        requestId: requestId,
        serviceName: requestData['serviceName'] ?? 'Service',
      );

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': requestData['userId'],
        'userRole': 'customer',
        'title': '❌ Request Rejected',
        'body':
        'Your service request has been rejected. You can post a new request.',
        'type': 'request_rejected',
        'requestId': requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!_isActive || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('❌ Error rejecting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= TOGGLE AVAILABILITY =================
  Future<void> _toggleAvailability(bool value) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!_isActive || !mounted) return;

      setState(() {
        isAvailable = value;
      });

      if (value) {
        _setupRealTimeStream();
      } else {
        setState(() {
          _requestsStream = null;
          totalPending = 0;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? '✅ You are now available for service'
              : 'You are now offline'),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      print('❌ Error toggling availability: $e');
    }
  }

  // ================= SHOW DIALOGS =================
  void _showIncompleteProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Profile Incomplete'),
        content: const Text(
          'Please complete your technician profile with categories and pincodes to start receiving service requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TechnicianProfileScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog(String requestId, Map<String, dynamic> data) {
    bool showVisitingCharges = _shouldShowVisitingChargesText(data);
    bool hasLocation = _hasLocation(data);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to accept this service request?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service: ${_getDisplayServiceName(data)}'),
                  const SizedBox(height: 4),
                  Text('Approx Budget: ₹${data['budget']}'),
                  if (showVisitingCharges) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        '199 INR Visiting Charges',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('Customer: ${data['userName']}'),
                  const SizedBox(height: 4),
                  const Text('Phone: Visible after accepting',
                      style: TextStyle(
                          color: Colors.grey, fontStyle: FontStyle.italic)),
                  Text('Location: ${data['location'] ?? 'N/A'}'),

                  if (hasLocation) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openMap(data),
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text(
                          'View on Map',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptRequest(requestId, data);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: const Text('Are you sure you want to reject this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectRequest(requestId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> data) {
    bool showVisitingCharges = _shouldShowVisitingChargesText(data);
    final String videoId = data['videoId'] ?? '';
    final bool hasVideo = videoId.isNotEmpty;
    final bool hasLocation = _hasLocation(data);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getDisplayServiceName(data)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasVideo)
                GestureDetector(
                  onTap: () {
                    if (_isAssetVideo(videoId)) {
                      _openAssetVideo(videoId);
                    } else {
                      _openYouTubeVideo(videoId);
                    }
                  },
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _isAssetVideo(videoId)
                              ? _AssetVideoPreviewWidget(videoPath: videoId)
                              : Image.network(
                            'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Text('Video not available'),
                              ),
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 35,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              _buildDetailRow('Customer Name', data['userName'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Phone', 'Visible after accepting request'),
              const SizedBox(height: 8),
              _buildDetailRow('Email', data['userEmail'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Service Type', data['serviceType'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Location', data['location'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Pincode', data['pincode'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildDetailRow('Approx Budget', '₹${data['budget'] ?? 0}'),
              if (showVisitingCharges) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    '199 INR Visiting Charges',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildDetailRow('Issue', data['issue'] ?? 'N/A'),
              if (data['additionalNote'] != null &&
                  data['additionalNote'].isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Additional Note', data['additionalNote']),
              ],
              if (hasLocation) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMap(data),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text(
                      'View Location on Map',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (hasVideo)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (_isAssetVideo(videoId)) {
                  _openAssetVideo(videoId);
                } else {
                  _openYouTubeVideo(videoId);
                }
              },
              icon: const Icon(Icons.play_circle, size: 18),
              label: const Text('Watch Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OPEN YOUTUBE VIDEO
  // ═══════════════════════════════════════════════════════
  void _openYouTubeVideo(String videoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YouTubeVideoPlayerScreen(videoId: videoId),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ OPEN ASSET VIDEO (Fullscreen)
  // ═══════════════════════════════════════════════════════
  void _openAssetVideo(String assetPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AssetVideoPlayerScreen(videoPath: assetPath),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ YOUTUBE THUMBNAIL
  // ═══════════════════════════════════════════════════════
  Widget _buildYouTubeThumbnail(String videoId) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.network(
          'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 120,
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 120,
              color: Colors.grey.shade200,
              child: const Center(
                child: Text('Video not available'),
              ),
            );
          },
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow,
            size: 28,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // ✅ ASSET VIDEO PREVIEW (with auto-play muted)
  // ═══════════════════════════════════════════════════════
  Widget _buildAssetVideoPreview(String assetPath) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: _AssetVideoPreviewWidget(videoPath: assetPath),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow,
            size: 28,
            color: Colors.white,
          ),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, size: 10, color: Colors.white),
                SizedBox(width: 3),
                Text(
                  'VIDEO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= VIDEO THUMBNAIL (Card) =================
  Widget _buildVideoThumbnail(String videoId) {
    return GestureDetector(
      onTap: () {
        if (_isAssetVideo(videoId)) {
          _openAssetVideo(videoId);
        } else {
          _openYouTubeVideo(videoId);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isAssetVideo(videoId)
              ? _buildAssetVideoPreview(videoId)
              : _buildYouTubeThumbnail(videoId),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLocked = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isLocked ? Colors.red : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDataDirectly();
        await _checkCooldownStatus();
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            TechnicianInBetweenBanner(height: 240),
            TechnicianWelcomeBanner(technicianName: technicianName),

            const SizedBox(height: 8),

            // ✅ SERVICE CATEGORIES & SERVICE AREAS CARDS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TechnicianCustomCard(
                    imagePath: 'assets/AppLogoo/catagory.png',
                    title: 'Service Categories',
                    subtitle: 'Select the services you can provide',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TechnicianCategoriesScreen(),
                        ),
                      );
                      _fetchTechnicianData();
                    },
                  ),
                  const SizedBox(height: 8),
                  TechnicianCustomCard(
                    imagePath: 'assets/AppLogoo/pincode.png',
                    title: 'Service Areas',
                    subtitle: 'Manage your service locations',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TechnicianAreasScreen(),
                        ),
                      );
                      _fetchTechnicianData();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildAvailabilityToggle(),
            const SizedBox(height: 2),
            _buildStatsCards(),
            _buildPendingRequests(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return TechnicianAvailabilityToggle(
      isAvailable: isAvailable,
      onChanged: _toggleAvailability,
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Pending Tasks',
              totalPending.toString(),
              Icons.pending_actions,
              totalPending > 0 ? Colors.orange : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Categories',
              technicianCategories.length.toString(),
              Icons.category,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Areas',
              technicianPincodes.length.toString(),
              Icons.location_on,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  // ================= PENDING REQUESTS =================
  Widget _buildPendingRequests() {
    if (technicianCategories.isEmpty || technicianPincodes.isEmpty) {
      return _buildIncompleteProfileWidget();
    }

    if (!isAvailable) {
      return _buildOfflineWidget();
    }

    if (_isOnCooldown) {
      return _buildCooldownWidget();
    }

    if (_requestsStream == null) {
      return _buildEmptyWidget();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Service Requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks matching your categories and service areas (auto-refresh)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _requestsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 40, color: Colors.red[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _setupRealTimeStream,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyWidget();
              }

              final pendingRequests = snapshot.data!;

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pendingRequests.length,
                separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var request = pendingRequests[index];
                  return _buildRequestCard(request);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= REQUEST CARD (Screenshot UI) =================
  Widget _buildRequestCard(
      QueryDocumentSnapshot<Map<String, dynamic>> request) {
    Map<String, dynamic> data = request.data();
    bool showVisitingCharges = _shouldShowVisitingChargesText(data);
    final createdAt = (data['createdAt'] as Timestamp).toDate();

    final bool isHighlighted = _highlightedRequestId != null &&
        _shouldHighlight &&
        _highlightedRequestId == request.id;

    final String videoId = data['videoId'] ?? '';
    final bool hasVideo = videoId.isNotEmpty;
    final bool hasLocation = _hasLocation(data);

    // Colors matching the screenshot
    const tealColor = Color(0xFF00BFA5); // Dark Teal
    const lightBgColor = Color(0xFFF0F8FF); // Very light blue
    const redTextColor = Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? Colors.green : Colors.grey.shade200,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // TOP HEADER BAR (Teal, Visit In, Accept In)
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: lightBgColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // NEW REQUEST Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tealColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'NEW REQUEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const VerticalDivider(thickness: 1, color: Colors.grey),
                const SizedBox(width: 8),

                // Visit In Timer
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: Colors.black54),
                        SizedBox(width: 4),
                        Text('Visit in', style: TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                    Text('40 minutes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),

                const Spacer(),

                // Countdown Timer (Accept in)
                _buildCountdownTimer(createdAt),
              ],
            ),
          ),

          // ==========================================
          // BODY CONTENT
          // ==========================================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Name & Budget
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _getDisplayServiceName(data),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF0C1B4D),
                        ),
                      ),
                    ),
                    Text(
                      '₹${data['budget']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32), // Green color
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 6),

                // Visiting Charges Note (if any)
                if (showVisitingCharges) ...[
                  _buildVisitingChargesNote(data),
                  const SizedBox(height: 8),
                ],

                // Customer Info List
                _buildInfoRow(Icons.person_outline, data['userName'] ?? 'Customer'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone_outlined, data['userPhone'] ?? 'No phone'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_on_outlined, data['location'] ?? 'Location not specified'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.location_city, 'Pincode: ${data['pincode'] ?? 'N/A'}'),

                const SizedBox(height: 12),

                // View on Map Button (Teal Outline)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: hasLocation ? () => _openMap(data) : null,
                    icon: const Icon(Icons.map_outlined, size: 18, color: tealColor),
                    label: const Text(
                      'View on Map',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: tealColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Issue Box (Grey Background)
                if (data['issue'] != null && data['issue'].isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issue:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0C1B4D)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['issue'],
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Video Thumbnail (if any)
                if (hasVideo) ...[
                  _buildVideoThumbnail(videoId),
                  const SizedBox(height: 12),
                ],

                // Action Buttons (View Details, Accept, Reject)
                Row(
                  children: [
                    // View Details
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRequestDetails(request.id, data),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0C1B4D),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Accept
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showAcceptDialog(request.id, data),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reject
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showRejectDialog(request.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: redTextColor,
                          side: const BorderSide(color: redTextColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Helper Widget for Info Rows
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ================= COUNTDOWN TIMER =================
  Widget _buildCountdownTimer(DateTime createdAt) {
    return StatefulBuilder(
      builder: (context, setStateTimer) {
        final expiryTime = createdAt.add(const Duration(minutes: _expireMinutes));

        return StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final remaining = expiryTime.difference(now);

            if (remaining.isNegative) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Expired',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              );
            }

            final minutes = remaining.inMinutes;
            final seconds = remaining.inSeconds.remainder(60);
            final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

            // Screenshot jaisa red timer box
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE), // Light Red Background
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)), // Red Border
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE53935)),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Accept in', style: TextStyle(fontSize: 9, color: Color(0xFFE53935))),
                      Text(
                        timeString,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE53935)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= EMPTY STATE WIDGETS =================
  Widget _buildIncompleteProfileWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 64, color: Colors.orange[400]),
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

  Widget _buildOfflineWidget() {
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

  Widget _buildEmptyWidget() {
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
            'Tasks matching your categories and pincode will appear here automatically',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🔥 COOLDOWN WIDGET
  Widget _buildCooldownWidget() {
    int mins = _remainingCooldownSeconds ~/ 60;
    int secs = _remainingCooldownSeconds % 60;

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
          Icon(Icons.timer_outlined, size: 64, color: Colors.blue[400]),
          const SizedBox(height: 16),
          const Text(
            'Take a Short Break!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You have just accepted a task. Please wait for $mins:${secs.toString().padLeft(2, '0')} minutes before accepting new ones.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: 1 - (_remainingCooldownSeconds / (10 * 60)),
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ ASSET VIDEO PREVIEW WIDGET
// ═══════════════════════════════════════════════════════════
class _AssetVideoPreviewWidget extends StatefulWidget {
  final String videoPath;

  const _AssetVideoPreviewWidget({required this.videoPath});

  @override
  State<_AssetVideoPreviewWidget> createState() =>
      _AssetVideoPreviewWidgetState();
}

class _AssetVideoPreviewWidgetState extends State<_AssetVideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller!.initialize();

      if (mounted) {
        setState(() => _initialized = true);
        _controller!.setVolume(0);
        _controller!.setLooping(true);
        _controller!.play();
      }
    } catch (e) {
      print('❌ Asset video init error: $e');
      if (mounted) setState(() => _initialized = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ ASSET VIDEO FULLSCREEN SCREEN
// ═══════════════════════════════════════════════════════════
class _AssetVideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const _AssetVideoPlayerScreen({required this.videoPath});

  @override
  State<_AssetVideoPlayerScreen> createState() =>
      _AssetVideoPlayerScreenState();
}

class _AssetVideoPlayerScreenState extends State<_AssetVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((e) {
        print('❌ Asset video fullscreen init error: $e');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Video'),
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF2563EB),
                    bufferedColor: Colors.white54,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}