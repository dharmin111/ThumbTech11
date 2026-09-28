// lib/model/ServiceRequestModel.dart

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'LocationModel.dart';

class ServiceRequestModel {
  String? id;
  String userId;
  String? visitingCharges;
  final String? technicianProfileImage;
  String userEmail;
  String userName;
  String userPhone;
  String serviceName;
  String serviceType;
  String issue;
  final String? videoId;
  String location;
  String pincode;
  final LocationModel? locationModel; // ✅ Location
  double budget;
  String additionalNote;
  List<String> imageUrls;
  String status;
  Timestamp createdAt;
  Timestamp updatedAt;
  String? technicianId;
  String? technicianName;
  String? technicianPhone;
  double? estimatedPrice;
  DateTime? scheduledDate;
  String? preferredTime;
  String? assignedAt;
  Timestamp? completedAt;
  String? cancellationReason;
  final String? profileImageUrl;

  ServiceRequestModel({
    this.id,
    required this.userId,
    this.technicianProfileImage,
    this.videoId,
    this.visitingCharges,
    required this.userEmail,
    this.locationModel, // ✅ Location
    this.profileImageUrl,
    required this.userName,
    required this.userPhone,
    required this.serviceName,
    required this.serviceType,
    required this.issue,
    required this.location,
    required this.pincode,
    required this.budget,
    required this.additionalNote,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.technicianId,
    this.technicianName,
    this.technicianPhone,
    this.estimatedPrice,
    this.scheduledDate,
    this.preferredTime,
    this.assignedAt,
    this.completedAt,
    this.cancellationReason,
  });

  // ✅ From Firestore
  factory ServiceRequestModel.fromFirestore(
      DocumentSnapshot doc,
      SnapshotOptions? options,
      ) {
    final data = doc.data() as Map<String, dynamic>;

    // ✅ Parse locationModel
    LocationModel? locationModel;
    if (data['locationModel'] != null) {
      try {
        locationModel = LocationModel.fromMap(
            data['locationModel'] as Map<String, dynamic>);
      } catch (e) {
        print('❌ Error parsing locationModel: $e');
      }
    }

    return ServiceRequestModel(
      visitingCharges: data['visitingCharges'],
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      technicianProfileImage: data['technicianProfileImage'] ?? '',
      serviceName: data['serviceName'] ?? '',
      videoId: data['videoId'],
      serviceType: data['serviceType'] ?? '',
      locationModel: locationModel, // ✅ Location
      profileImageUrl: data['profileImageUrl'] ?? '',
      issue: data['issue'] ?? '',
      location: data['location'] ?? '',
      pincode: data['pincode'] ?? '',
      budget: (data['budget'] ?? 0).toDouble(),
      additionalNote: data['additionalNote'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      technicianId: data['technicianId'],
      technicianName: data['technicianName'],
      technicianPhone: data['technicianPhone'],
      estimatedPrice: data['estimatedPrice']?.toDouble(),
      scheduledDate: data['scheduledDate'] != null
          ? (data['scheduledDate'] as Timestamp).toDate()
          : null,
      preferredTime: data['preferredTime'],
      assignedAt: data['assignedAt'],
      completedAt: data['completedAt'] != null
          ? data['completedAt'] as Timestamp?
          : null,
      cancellationReason: data['cancellationReason'],
    );
  }

  // ✅ To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'visitingCharges': visitingCharges,
      'userEmail': userEmail,

      // ✅ LOCATION - Save WITHIN document
      'locationModel': locationModel != null
          ? {
        'latitude': locationModel!.latitude,
        'longitude': locationModel!.longitude,
        'address': locationModel!.address ?? '',
        'placeName': locationModel!.placeName ?? '',
      }
          : null,
      'geoPoint': locationModel != null
          ? GeoPoint(locationModel!.latitude, locationModel!.longitude)
          : null,

      'userName': userName,
      'userPhone': userPhone,
      'serviceName': serviceName,
      'technicianProfileImage': technicianProfileImage,
      'serviceType': serviceType,
      'issue': issue,
      'videoId': videoId,
      'location': location,
      'pincode': pincode,
      'profileImageUrl': profileImageUrl ?? '',
      'budget': budget,
      'additionalNote': additionalNote,
      'imageUrls': imageUrls,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'technicianPhone': technicianPhone,
      'estimatedPrice': estimatedPrice,
      'scheduledDate':
      scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'preferredTime': preferredTime,
      'assignedAt': assignedAt,
      'completedAt': completedAt,
      'cancellationReason': cancellationReason,
    };
  }

  // ✅ Copy With - FIXED
  ServiceRequestModel copyWith({
    String? id,
    String? visitingCharges,
    String? userId,
    String? videoId,
    String? userEmail,
    String? userName,
    String? profileImageUrl,
    String? userPhone,
    String? serviceName,
    String? serviceType,
    String? issue,
    String? location,
    String? pincode,
    double? budget,
    String? additionalNote,
    List<String>? imageUrls,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? technicianId,
    String? technicianName,
    String? technicianPhone,
    double? estimatedPrice,
    DateTime? scheduledDate,
    String? preferredTime,
    String? assignedAt,
    Timestamp? completedAt,
    String? cancellationReason,
    LocationModel? locationModel, // ✅ Location param
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      visitingCharges: visitingCharges ?? this.visitingCharges,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      serviceName: serviceName ?? this.serviceName,
      serviceType: serviceType ?? this.serviceType,
      issue: issue ?? this.issue,
      videoId: videoId ?? this.videoId,
      location: location ?? this.location,
      pincode: pincode ?? this.pincode,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      budget: budget ?? this.budget,
      additionalNote: additionalNote ?? this.additionalNote,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      technicianPhone: technicianPhone ?? this.technicianPhone,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      preferredTime: preferredTime ?? this.preferredTime,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      locationModel: locationModel ?? this.locationModel, // ✅ FIXED - Yeh add kiya
    );
  }

  // ✅ Formatted Date
  String getFormattedCompletedDate() {
    if (completedAt == null) return 'Date not available';
    try {
      final date = completedAt!.toDate();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // ✅ Status helpers
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFA726);
      case 'accepted':
        return const Color(0xFF42A5F5);
      case 'in_progress':
        return const Color(0xFFAB47BC);
      case 'completed':
        return const Color(0xFF66BB6A);
      case 'cancelled':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}