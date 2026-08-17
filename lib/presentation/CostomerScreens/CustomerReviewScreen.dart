// lib/presentation/CostomerScreens/ReviewScreen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../Services/TechnicianAvailabilityService.dart';
import '../../model/ServiceRequestModel.dart';
import 'BookingSuccessScreen.dart';
import 'NoTechnicianFoundScreen.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const lightBlue = Color(0xFF7EC8FF);
const yellow = Color(0xFFFFD428);
const background = Color(0xFFFFFFFF);

class ReviewScreen extends StatefulWidget {
  final String serviceName;
  final String serviceType;
  final String pincode;
  final String address;
  final String issueDescription;
  final List<XFile> images;
  final String budget;
  final String? editRequestId; // 🔥 For editing existing requests

  const ReviewScreen({
    super.key,
    required this.serviceName,
    required this.serviceType,
    required this.pincode,
    required this.address,
    required this.issueDescription,
    required this.images,
    required this.budget,
    this.editRequestId, // 🔥 Optional for edit mode
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final FirebaseFirestoreStorageCustomerOrder _firebaseService =
  FirebaseFirestoreStorageCustomerOrder();

  bool _isProcessing = false;
  String additionalNote = '';

  // Dialog State
  bool _termsAccepted = false;
  bool _showTermsError = false;

  // 🔥 Check if in edit mode
  bool get _isEditMode => widget.editRequestId != null && widget.editRequestId!.isNotEmpty;

  // ================= 🔥 MAIN METHOD: Check Availability First =================
  Future<void> _checkAvailabilityAndConfirm() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    // 🔥 Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
            ),
            const SizedBox(height: 16),
            Text(
              'Checking for available technicians...',
              style: TextStyle(
                fontSize: 14,
                color: darkBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pincode: ${widget.pincode}',
              style: TextStyle(
                fontSize: 12,
                color: darkBlue.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // 🔥 STEP 1: Check if technicians available
      final result = await TechnicianAvailabilityService.checkAvailability(
        pincode: widget.pincode,
        serviceType: widget.serviceType,
      );

      // 🔥 Close Loading Dialog
      if (context.mounted) Navigator.pop(context);

      print('📊 Availability Result: ${result.isAvailable}');
      print('📊 Matched Technicians: ${result.count}');

      if (result.isAvailable) {
        // ✅ Technicians Available → Show Terms Dialog
        if (context.mounted) {
          _showConfirmBookingDialog();
        }
      } else {
        // ❌ No Technicians Available → Show Image Screen
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoTechnicianFoundScreen(
                pincode: widget.pincode,
                serviceName: widget.serviceName,
                onRetry: () {
                  Navigator.pop(context);
                  // Retry checking
                  _checkAvailabilityAndConfirm();
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // 🔥 Close Loading Dialog
      if (context.mounted) Navigator.pop(context);

      print('❌ Error checking availability: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ================= SHOW TERMS & CONDITIONS DIALOG =================
  void _showConfirmBookingDialog() {
    setState(() {
      _termsAccepted = false;
      _showTermsError = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                _isEditMode ? 'Update Request' : 'Terms & Conditions',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // 🔥 Available Technicians Count
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '✅ Technicians available in your area!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Terms & Conditions Checkbox
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _termsAccepted,
                            onChanged: (value) {
                              setDialogState(() {
                                _termsAccepted = value ?? false;
                                _showTermsError = false;
                              });
                            },
                            activeColor: primaryCyan,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // TODO: Navigate to Terms & Conditions Screen
                            },
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 14, color: darkBlue),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Terms Error
                    if (_showTermsError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Please accept Terms & Conditions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Disclaimer Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Please Discuss The Issue, Pricing and Timing With The Technician Before Sharing Your Address.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 14, color: darkBlue),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Check if terms accepted
                    if (!_termsAccepted) {
                      setDialogState(() {
                        _showTermsError = true;
                      });
                      return;
                    }

                    // Close dialog and save
                    Navigator.pop(context);
                    _saveServiceRequest();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryCyan,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    _isEditMode ? 'Update Booking' : 'Confirm Booking',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= SAVE OR UPDATE SERVICE REQUEST =================
  Future<void> _saveServiceRequest() async {
    setState(() => _isProcessing = true);

    try {
      if (!_firebaseService.isUserLoggedIn()) {
        throw Exception('Please login to continue');
      }

      final userId = _firebaseService.getCurrentUserId()!;
      final userEmail = _firebaseService.getCurrentUserEmail()!;

      final userData = await _firebaseService.getCurrentUserData();
      final userName = userData?['name'] ?? 'Customer';
      final userPhone = userData?['phone'] ?? '';

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
              ),
              const SizedBox(height: 16),
              Text(
                _isEditMode
                    ? 'Updating your request...'
                    : 'Uploading images and finding technicians...',
                style: TextStyle(color: darkBlue, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );

      List<String> imageUrls = [];
      if (widget.images.isNotEmpty) {
        imageUrls = await _firebaseService.uploadServiceImages(
          images: widget.images,
          userId: userId,
        );
      }

      final serviceRequest = ServiceRequestModel(
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        userPhone: userPhone,
        serviceName: widget.serviceName,
        serviceType: widget.serviceType,
        issue: widget.issueDescription,
        location: widget.address,
        pincode: widget.pincode,
        budget: double.tryParse(widget.budget) ?? 800.0,
        additionalNote: additionalNote,
        imageUrls: imageUrls,
        status: 'pending',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );

      String requestId;

      if (_isEditMode) {
        // 🔥 UPDATE existing request
        await _firebaseService.updateServiceRequest(
          requestId: widget.editRequestId!,
          request: serviceRequest,
        );
        requestId = widget.editRequestId!;
        print('✅ Service request updated with ID: $requestId');
      } else {
        // 🔥 CREATE new request with matching
        requestId = await _firebaseService.saveServiceRequestWithMatching(
          request: serviceRequest,
        );
        print('✅ Service request saved with ID: $requestId');
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? '✅ Service updated successfully!'
                : '✅ Service booked successfully! Technicians will be notified.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSuccessScreen(
              requestId: requestId,
            ),
          ),
        );
      });
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('Error saving service request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${_isEditMode ? 'updating' : 'booking'} service: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit & Confirm' : 'Review & Confirm',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 Edit Mode Banner
            if (_isEditMode)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You are editing this service request. The changes will be updated.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Service Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryCyan.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryCyan,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/revicon/serviceicon.png',
                            height: 20,
                            width: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.build,
                                color: Colors.white,
                                size: 20,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isEditMode ? 'Edit Service Summary' : 'Service Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Service Details
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          imagePath: 'assets/revicon/serviceicon.png',
                          label: 'Service',
                          value: widget.serviceName,
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow(
                          imagePath: 'assets/revicon/issue.png',
                          label: 'Issue',
                          value: widget.issueDescription.isEmpty
                              ? 'No issue description provided'
                              : widget.issueDescription,
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow(
                          imagePath: 'assets/revicon/location.png',
                          label: 'Location',
                          value: widget.address,
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow(
                          imagePath: 'assets/revicon/pincode.png',
                          label: 'Pincode',
                          value: widget.pincode,
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow(
                          imagePath: 'assets/revicon/budget.png',
                          label: 'Your Budget',
                          value: '₹${widget.budget}',
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            _showAdditionalNoteDialog();
                          },
                          child: _buildSummaryRow(
                            imagePath: 'assets/revicon/addnote.png',
                            label: 'Additional Note',
                            value: additionalNote.isEmpty
                                ? 'Tap to add note'
                                : additionalNote,
                            showEditIcon: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // No Service Charge Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade50, Colors.teal.shade50],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Service Charge',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You only pay the technician directly after the work is completed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Uploaded Images (if any)
            if (widget.images.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Images',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: darkBlue.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.images.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: FileImage(
                                  File(widget.images[index].path),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // 🔥 CONFIRM BOOKING BUTTON - Calls check first
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : _checkAvailabilityAndConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryCyan,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                        : Text(
                      _isEditMode ? 'Update Booking' : 'Confirm Booking',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isEditMode
                        ? 'Your request will be updated with new details.'
                        : 'You don\'t have to pay anything now.',
                    style: TextStyle(
                      fontSize: 12,
                      color: darkBlue.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPER WIDGETS =================

  Widget _buildSummaryRow({
    required String imagePath,
    required String label,
    required String value,
    bool showEditIcon = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Image.asset(
            imagePath,
            width: 20,
            height: 20,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  _getFallbackIcon(label),
                  size: 12,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: darkBlue.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: darkBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (showEditIcon) const Icon(Icons.edit, size: 18, color: primaryCyan),
      ],
    );
  }

  IconData _getFallbackIcon(String label) {
    switch (label) {
      case 'Service':
        return Icons.build;
      case 'Issue':
        return Icons.warning_amber_rounded;
      case 'Location':
        return Icons.location_on;
      case 'Pincode':
        return Icons.location_city;
      case 'Your Budget':
        return Icons.currency_rupee;
      case 'Additional Note':
        return Icons.note_add;
      default:
        return Icons.info;
    }
  }

  void _showAdditionalNoteDialog() {
    TextEditingController controller = TextEditingController(
      text: additionalNote,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Additional Note'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Any special instructions or requirements...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  additionalNote = controller.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryCyan),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}