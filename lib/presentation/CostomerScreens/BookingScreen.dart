// lib/presentation/CostomerScreens/BookingScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../model/ServiceRequestModel.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const background = Color(0xFFFFFFFF);

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestoreStorageCustomerOrder _firebaseService =
      FirebaseFirestoreStorageCustomerOrder();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _firebaseService.getCurrentUserId();
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text(
            'Accepted Bookings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.login_outlined,
                size: 80,
                color: darkBlue.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Please login to view your bookings',
                style: TextStyle(
                  fontSize: 16,
                  color: darkBlue.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Accepted Bookings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<ServiceRequestModel>>(
        stream: _firebaseService.getUserServiceRequests(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading bookings',
                    style: TextStyle(
                      fontSize: 16,
                      color: darkBlue.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
              ),
            );
          }

          final allBookings = snapshot.data ?? [];

          // Filter ONLY accepted bookings
          final acceptedBookings = allBookings
              .where((booking) => booking.status.toLowerCase() == 'accepted')
              .toList();

          if (acceptedBookings.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: acceptedBookings.length,
            itemBuilder: (context, index) {
              final booking = acceptedBookings[index];
              return _buildBookingCard(booking);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: darkBlue.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No Accepted Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your accepted service requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: darkBlue.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(ServiceRequestModel booking) {
    final statusColor = Colors.green; // Accepted status color
    final statusText = 'Accepted';

    return GestureDetector(
      onTap: () {
        // TODO: Add functionality later
        // Example: Navigate to booking details screen
        print('Tapped on booking: ${booking.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking details for ${booking.serviceName} - Coming Soon!',
            ),
            backgroundColor: primaryCyan,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withValues(alpha: 0.15),
                    statusColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Service Icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _getServiceIcon(booking.serviceType),
                      size: 24,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Service Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.serviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${booking.id?.substring(0, 8) ?? 'N/A'}...',
                          style: TextStyle(
                            fontSize: 11,
                            color: darkBlue.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge with icon
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body with all details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Technician Info Card (highlighted for accepted bookings)
                  if (booking.technicianName != null &&
                      booking.technicianName!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryCyan.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryCyan,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Technician Assigned',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: darkBlue.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  booking.technicianName!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                                if (booking.technicianPhone != null &&
                                    booking.technicianPhone!.isNotEmpty)
                                  Text(
                                    booking.technicianPhone!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryCyan,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Call icon (optional)
                          if (booking.technicianPhone != null &&
                              booking.technicianPhone!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryCyan.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.phone,
                                size: 20,
                                color: primaryCyan,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Date Row
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Accepted on',
                    _formatDate(booking.updatedAt),
                  ),
                  const SizedBox(height: 12),

                  // Service Type Row
                  _buildDetailRow(
                    Icons.build,
                    'Service Type',
                    booking.serviceType,
                  ),
                  const SizedBox(height: 12),

                  // Location Row
                  _buildDetailRow(
                    Icons.location_on,
                    'Location',
                    booking.location,
                  ),
                  const SizedBox(height: 12),

                  // Pincode Row
                  _buildDetailRow(
                    Icons.local_post_office,
                    'Pincode',
                    booking.pincode,
                  ),
                  const SizedBox(height: 12),

                  // Budget Row
                  _buildDetailRow(
                    Icons.currency_rupee,
                    'Budget',
                    '₹${booking.budget.toStringAsFixed(0)}',
                  ),

                  // Estimated Price (if available)
                  if (booking.estimatedPrice != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.price_change,
                      'Estimated Price',
                      '₹${booking.estimatedPrice!.toStringAsFixed(0)}',
                    ),
                  ],

                  // Issue Description (if any)
                  if (booking.issue.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.description,
                      'Issue Description',
                      booking.issue,
                      maxLines: 2,
                    ),
                  ],

                  // Additional Note (if any)
                  if (booking.additionalNote.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.note_add,
                      'Additional Note',
                      booking.additionalNote,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),

            // Tap to view details hint
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 14,
                    color: primaryCyan.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryCyan.withValues(alpha: 0.6),
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

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 28, child: Icon(icon, size: 16, color: primaryCyan)),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: darkBlue.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: darkBlue,
              fontWeight: FontWeight.w500,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year at $hour:$minute';
  }

  IconData _getServiceIcon(String serviceType) {
    if (serviceType.contains('AC') || serviceType.contains('Air'))
      return Icons.ac_unit;
    if (serviceType.contains('Washing')) return Icons.local_laundry_service;
    if (serviceType.contains('Plumbing')) return Icons.plumbing;
    if (serviceType.contains('Electrical')) return Icons.electrical_services;
    if (serviceType.contains('CCTV')) return Icons.videocam;
    if (serviceType.contains('Water')) return Icons.water_drop;
    if (serviceType.contains('Geyser')) return Icons.whatshot;
    if (serviceType.contains('Refrigerator')) return Icons.kitchen;
    if (serviceType.contains('Carpenter')) return Icons.handyman;
    if (serviceType.contains('Painting')) return Icons.brush;
    return Icons.build;
  }
}
