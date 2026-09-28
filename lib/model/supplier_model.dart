class SupplierModel {
  final String id;
  final String storeName;
  final String ownerName;
  final String contactNumber;
  final String? whatsappNumber;
  final String googleMapsLink;
  final List<String> categories;
  final String shortDescription;
  final List<String> storePhotoUrls;
  final String status; // pending, approved, rejected, blocked
  final bool isVerified;
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const SupplierModel({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.status, // ✅ Add status
    required this.contactNumber,
    this.whatsappNumber,
    required this.googleMapsLink,
    required this.categories,
    required this.shortDescription,
    this.storePhotoUrls = const [],
    this.isVerified = false,
    this.isActive = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    return SupplierModel(
      id: map['id'] ?? '',
      storeName: map['storeName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      status: map['status'] ?? 'pending',
      whatsappNumber: map['whatsappNumber'],
      googleMapsLink: map['googleMapsLink'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      shortDescription: map['shortDescription'] ?? '',
      storePhotoUrls: List<String>.from(
        map['storePhotoUrls'] ?? [],
      ),
      isVerified: map['isVerified'] ?? false,
      isActive: map['isActive'] ?? false,
      createdAt: DateTime.tryParse(
        map['createdAt']?.toString() ?? '',
      ) ??
          DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeName': storeName,
      'ownerName': ownerName,
      'status': status, // ✅ Status field
      'contactNumber': contactNumber,
      'whatsappNumber': whatsappNumber,
      'googleMapsLink': googleMapsLink,
      'categories': categories,
      'shortDescription': shortDescription,
      'storePhotoUrls': storePhotoUrls,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}