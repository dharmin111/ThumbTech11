import 'app_user_model.dart';

class CustomerModel extends AppUserModel {

  CustomerModel({
    required super.lan,
    required super.lat,
    required super.placeName,
    required super.id,
    required super.name,
    required super.email,
    required super.phoneNumber,
    required super.isActive,
    required super.role,
    required super.createdAt,
    required super.pincode,
    super.profileImageUrl,
    super.address,
    super.city,
    super.state,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      lan: map['longitude'],
      lat: map['latitude'],
      placeName: map['placeName'],
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      isActive: map['isActive'] ?? false,
      role: map['role'] ?? 'customer',
      createdAt:
      DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      pincode: map['pincode'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
    );
  }
}