// models/TechnicianModel.dart
import 'app_user_model.dart';

class TechnicianModel extends AppUserModel {
  final List<String> categories;
  final List<String> pincodes; // ✅ MULTIPLE PINCODES for technicians
  final String? introVideoUrl;
  final List<String> workImages;
  final String? idCardImage;
  final String? description;
  final String? status; // 'pending', 'approved', 'rejected'

  TechnicianModel({
    required super.id,
    required super.name,
    required super.email,
    required super.phoneNumber,
    required super.isActive,
    required super.role,
    required super.createdAt,
    required super.pincode, // This is the FIRST pincode (for backward compatibility)
    super.profileImageUrl,
    super.address,
    super.city,
    super.state,
    super.oneSignalId,
    super.fcmToken,
    super.tokenUpdatedAt,
    this.categories = const [],
    this.pincodes = const [], // ✅ Store multiple pincodes here
    this.introVideoUrl,
    this.workImages = const [],
    this.idCardImage,
    this.description,
    this.status,
  });

  @override
  Map<String, dynamic> toMap() {
    final data = super.toMap();
    data['categories'] = categories;
    data['pincodes'] = pincodes; // ✅ Save multiple pincodes
    data['introVideoUrl'] = introVideoUrl;
    data['workImages'] = workImages;
    data['idCardImage'] = idCardImage;
    data['description'] = description;
    data['status'] = status;
    return data;
  }

  factory TechnicianModel.fromMap(Map<String, dynamic> map) {
    // Get pincodes array (for technicians)
    List<String> technicianPincodes = [];
    if (map['pincodes'] != null && (map['pincodes'] as List).isNotEmpty) {
      technicianPincodes = List<String>.from(map['pincodes']);
    } else if (map['pincode'] != null && map['pincode'].toString().isNotEmpty) {
      technicianPincodes = [map['pincode'].toString()];
    }

    return TechnicianModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isActive: map['isActive'] ?? false,
      role: map['role'] ?? 'technician',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      pincode: map['pincode'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      oneSignalId: map['oneSignalId'],
      fcmToken: map['fcmToken'],
      tokenUpdatedAt: map['tokenUpdatedAt'] != null
          ? DateTime.tryParse(map['tokenUpdatedAt'])
          : null,
      categories: List<String>.from(map['categories'] ?? []),
      pincodes: technicianPincodes, // ✅ Multiple pincodes
      introVideoUrl: map['introVideoUrl'],
      workImages: List<String>.from(map['workImages'] ?? []),
      idCardImage: map['idCardImage'],
      description: map['description'],
      status: map['status'],
    );
  }

  // ✅ Helper Methods for Multiple Pincodes
  bool servesPincode(String pincode) => pincodes.contains(pincode);
  String get pincodesString => pincodes.join(', ');
  int get serviceAreasCount => pincodes.length;
  String get primaryPincode => pincodes.isNotEmpty ? pincodes[0] : pincode;

  // Existing helpers
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  String get categoriesString => categories.join(', ');
  int get workImagesCount => workImages.length;
}