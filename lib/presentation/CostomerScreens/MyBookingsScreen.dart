// lib/presentation/CostomerScreens/MyBookingsScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/FirebaseFirestoreStorageCustomerOrder.dart';
import '../../model/ServiceRequestModel.dart';

const primaryCyan = Color(0xFF42D7D7);
const darkBlue = Color(0xFF0C1B4D);
const background = Color(0xFFFFFFFF);

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
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
      return _buildLoginRequiredScreen();
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Completed Bookings',
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
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryCyan),
              ),
            );
          }

          final allBookings = snapshot.data ?? [];

          // Filter ONLY completed bookings
          final completedBookings = allBookings
              .where((booking) => booking.status.toLowerCase() == 'completed')
              .toList();

          if (completedBookings.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedBookings.length,
            itemBuilder: (context, index) {
              final booking = completedBookings[index];
              return _buildCompletedBookingCard(booking);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoginRequiredScreen() {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Completed Bookings',
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

  Widget _buildErrorState(String error) {
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
            error,
            style: const TextStyle(fontSize: 12, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: darkBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No Completed Bookings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed service requests will appear here',
            style: TextStyle(
              fontSize: 14,
              color: darkBlue.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Safe date formatter that handles Timestamp, DateTime, and null values
  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Date not available';
    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return 'Invalid date';
      }

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid date';
    }
  }

  Widget _buildCompletedBookingCard(ServiceRequestModel booking) {
    final statusColor = Colors.blue;
    final statusIcon = Icons.verified;
    final statusText = 'Completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getServiceIcon(booking.serviceType),
                    size: 24,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
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
                        'ID: ${booking.id?.substring(0, booking.id!.length > 8 ? 8 : booking.id!.length)}...',
                        style: TextStyle(
                          fontSize: 11,
                          color: darkBlue.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: Colors.white),
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

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Completion Message
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, size: 18, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🎉 Service completed successfully! Thank you for choosing us.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Technician Info
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
                                'Technician',
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
                      ],
                    ),
                  ),

                // Details - Using safe date formatter
                _buildDetailRow(
                  Icons.calendar_today,
                  'Requested on',
                  _formatDate(booking.createdAt),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.build,
                  'Service Type',
                  booking.serviceType,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.location_on,
                  'Location',
                  booking.location,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.local_post_office,
                  'Pincode',
                  booking.pincode,
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.currency_rupee,
                  'Budget',
                  '₹${booking.budget.toStringAsFixed(0)}',
                ),

                if (booking.estimatedPrice != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.price_change,
                    'Final Price',
                    '₹${booking.estimatedPrice!.toStringAsFixed(0)}',
                  ),
                ],

                if (booking.issue.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.description,
                    'Issue',
                    booking.issue,
                    maxLines: 2,
                  ),
                ],

                if (booking.additionalNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.note_add,
                    'Note',
                    booking.additionalNote,
                    maxLines: 2,
                  ),
                ],

                // Rebook Button
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _rebookService(booking);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Book Again'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryCyan,
                      side: BorderSide(color: primaryCyan),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    int maxLines = 1,
  }) {
    if (value.isEmpty ||
        value == 'Date not available' ||
        value == 'Invalid date') {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: Icon(icon, size: 16, color: primaryCyan)),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
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
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    if (serviceType.contains('AC') || serviceType.contains('Air')) {
      return Icons.ac_unit;
    }
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

  void _rebookService(ServiceRequestModel booking) {
    // Navigate to service detail screen with the same service
    Navigator.pushNamed(
      context,
      '/service-detail',
      arguments: booking.serviceName,
    );
  }
}
