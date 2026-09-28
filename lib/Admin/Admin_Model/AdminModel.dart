// models/admin_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' | 'super_admin'
  final bool isApproved;
  final bool isActive;
  final String profileImage;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String bio;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final DateTime? lastLogin;
  final Map<String, dynamic> permissions; // For future role-based access
  final List<String> activityLog; // For tracking admin actions
  final String createdBy; // Super admin who created/approved
  final String notes; // Any additional notes

  AdminModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'admin',
    this.isApproved = false,
    this.isActive = true,
    this.profileImage = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.bio = '',
    required this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.lastLogin,
    this.permissions = const {},
    this.activityLog = const [],
    this.createdBy = '',
    this.notes = '',
  });

  // ✅ Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isApproved': isApproved,
      'isActive': isActive,
      'profileImage': profileImage,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'bio': bio,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'permissions': permissions,
      'activityLog': activityLog,
      'createdBy': createdBy,
      'notes': notes,
    };
  }

  // ✅ Create from Firestore Document
  factory AdminModel.fromMap(Map<String, dynamic> data, String docId) {
    return AdminModel(
      uid: data['uid'] ?? docId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'admin',
      isApproved: data['isApproved'] ?? false,
      isActive: data['isActive'] ?? true,
      profileImage: data['profileImage'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      pincode: data['pincode'] ?? '',
      bio: data['bio'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      permissions: data['permissions'] ?? {},
      activityLog: List<String>.from(data['activityLog'] ?? []),
      createdBy: data['createdBy'] ?? '',
      notes: data['notes'] ?? '',
    );
  }

  // ✅ Copy with updates (for partial updates)
  AdminModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? bio,
    bool? isApproved,
    bool? isActive,
    String? role,
    Map<String, dynamic>? permissions,
    List<String>? activityLog,
    DateTime? lastLogin,
    DateTime? approvedAt,
    String? notes,
  }) {
    return AdminModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      isActive: isActive ?? this.isActive,
      profileImage: profileImage ?? this.profileImage,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      bio: bio ?? this.bio,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      approvedAt: approvedAt ?? this.approvedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      permissions: permissions ?? this.permissions,
      activityLog: activityLog ?? this.activityLog,
      createdBy: createdBy,
      notes: notes ?? this.notes,
    );
  }
}