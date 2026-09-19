
//3966b6b9-330c-492c-aa2b-a88e88b07a6d

class AppUserModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final bool isActive;
  final String role;
  final DateTime createdAt;
  final String pincode;
  final String? profileImageUrl;
  final String? address;
  final String? city;
  final String? lan;
  final String? lat;
  final String? placeName;
  final String? state;
  final String? oneSignalId;

  // FCM Token fields
  final String? fcmToken;
  final DateTime? tokenUpdatedAt;

  AppUserModel({
    required this.id,
    required this.name,
    this.oneSignalId,
    this.lan,
    this.lat,
    this.placeName,
    required this.email,
    required this.phoneNumber,
    required this.isActive,
    required this.role,
    required this.createdAt,
    required this.pincode,
    this.profileImageUrl,
    this.address,
    this.city,
    this.state,
    this.fcmToken,
    this.tokenUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude':lat,
      'longitude':lan,
      'email': email,
      'placeName':placeName,
      'phoneNumber': phoneNumber,
      'isActive': isActive,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'pincode': pincode,
      'profileImageUrl': profileImageUrl,
      'address': address,
      'city': city,
      'oneSignalId': oneSignalId,
      'state': state,
      'fcmToken': fcmToken,
      'tokenUpdatedAt': tokenUpdatedAt?.toIso8601String(),
    };
  }

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      lat:map['latitude']??'',
      lan:map['longitude']??'',
      placeName: map['placeName']??'',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isActive: map['isActive'] ?? false,
      role: map['role'] ?? 'customer',
      oneSignalId: map['oneSignalId'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      pincode: map['pincode'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      fcmToken: map['fcmToken'],
      tokenUpdatedAt: map['tokenUpdatedAt'] != null
          ? DateTime.tryParse(map['tokenUpdatedAt'])
          : null,
    );
  }

  // Helper method to check if user has valid FCM token
  bool get hasValidFCMToken => fcmToken != null && fcmToken!.isNotEmpty;

  // Helper method to get user display name
  String get displayName => name.isNotEmpty ? name : email.split('@').first;

  // Helper method to get user role display
  String get roleDisplay => role == 'technician' ? 'Technician' : 'Customer';
}