import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../model/customer_model.dart';
import '../model/technician_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// ============================
  /// SAVE CUSTOMER
  /// ============================
  Future<void> saveCustomer({
    required CustomerModel customer,
  }) async {
    await _firestore
        .collection("users")
        .doc(customer.id)
        .set({
      ...customer.toMap(),
      "role": "customer",
    });
  }

  /// ============================
  /// SAVE TECHNICIAN (Text only)
  /// ============================
  Future<void> saveTechnician({
    required TechnicianModel technician,
  }) async {
    await _firestore
        .collection("users")
        .doc(technician.id)
        .set({
      ...technician.toMap(),
      "role": "technician",
    });
  }

  /// ============================
  /// COMPLETE TECHNICIAN REGISTRATION WITH ALL FILES
  /// ============================
  Future<Map<String, dynamic>> registerTechnician({
    required String id,
    required String name,
    required String email,
    required String phoneNumber,
    required String pincode,
    required List<String> categories,
    required String? address,
    required String? city,
    required String? state,
    // Files
    required File? profileImage,
    required List<File> workImages,
    required File? introVideo,
  }) async {
    try {
      String? profileImageUrl;
      List<String> workImageUrls = [];
      String? introVideoUrl;

      // Upload Profile Image
      if (profileImage != null) {
        profileImageUrl = await _uploadFile(
          file: profileImage,
          path: 'technicians/$id/profile',
          fileName: 'profile.jpg',
        );
        print('Profile image uploaded successfully');
      }

      // Upload Work Images (Multiple)
      if (workImages.isNotEmpty) {
        for (int i = 0; i < workImages.length; i++) {
          String imageUrl = await _uploadFile(
            file: workImages[i],
            path: 'technicians/$id/work_images',
            fileName: 'work_$i.jpg',
          );
          workImageUrls.add(imageUrl);
        }
        print('${workImageUrls.length} work images uploaded successfully');
      }

      // Upload Intro Video
      if (introVideo != null) {
        introVideoUrl = await _uploadFile(
          file: introVideo,
          path: 'technicians/$id/intro_video',
          fileName: 'intro_video.mp4',
        );
        print('Intro video uploaded successfully');
      }

      // Create Technician Model
      TechnicianModel technician = TechnicianModel(
        id: id,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        isActive: true,
        role: 'technician',
        createdAt: DateTime.now(),
        pincode: pincode,
        profileImageUrl: profileImageUrl,
        address: address,
        city: city,
        state: state,
        categories: categories,
        introVideoUrl: introVideoUrl,
        workImages: workImageUrls,
      );

      // Save to Firestore
      await saveTechnician(technician: technician);

      return {
        'success': true,
        'message': 'Technician registered successfully',
        'technicianId': id,
      };
    } catch (e) {
      print('Error registering technician: $e');
      return {
        'success': false,
        'message': 'Failed to register technician: $e',
      };
    }
  }

  /// ============================
  /// UPDATE TECHNICIAN PROFILE IMAGE
  /// ============================
  Future<String?> updateTechnicianProfileImage({
    required String technicianId,
    required File newProfileImage,
  }) async {
    try {
      // Delete old profile image if exists
      TechnicianModel? technician = await getTechnician(technicianId);
      if (technician?.profileImageUrl != null) {
        await _deleteFile(technician!.profileImageUrl!);
      }

      // Upload new profile image
      String newImageUrl = await _uploadFile(
        file: newProfileImage,
        path: 'technicians/$technicianId/profile',
        fileName: 'profile.jpg',
      );

      // Update Firestore
      await _firestore.collection("users").doc(technicianId).update({
        'profileImageUrl': newImageUrl,
      });

      return newImageUrl;
    } catch (e) {
      print('Error updating profile image: $e');
      return null;
    }
  }

  // Add to FirestoreService class
  Future<String?> uploadProfileImage({
    required String technicianId,
    required File profileImage,
  }) async {
    try {
      String fileName = 'technician_${technicianId}_profile.jpg';
      Reference ref = _storage
          .ref()
          .child('technicians/$technicianId/profile/$fileName');

      UploadTask uploadTask = ref.putFile(profileImage);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with profile image URL
      await _firestore.collection("users").doc(technicianId).update({
        'profileImageUrl': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  /// ============================
  /// ADD NEW WORK IMAGES
  /// ============================

  Future<List<String>> addWorkImages({
    required String technicianId,
    required List<File> newWorkImages,
  }) async {
    try {
      List<String> newImageUrls = [];
      TechnicianModel? technician = await getTechnician(technicianId);

      // Get existing work images
      List<String> existingImages = technician?.workImages ?? [];

      // Upload new images
      for (int i = 0; i < newWorkImages.length; i++) {
        String imageUrl = await _uploadFile(
          file: newWorkImages[i],
          path: 'technicians/$technicianId/work_images',
          fileName: 'work_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        newImageUrls.add(imageUrl);
      }

      // Combine existing and new images
      List<String> allImages = [...existingImages, ...newImageUrls];

      // Update Firestore
      await _firestore.collection("users").doc(technicianId).update({
        'workImages': allImages,
      });

      return newImageUrls;
    } catch (e) {
      print('Error adding work images: $e');
      return [];
    }
  }

  /// ============================
  /// REMOVE WORK IMAGE
  /// ============================
  Future<bool> removeWorkImage({
    required String technicianId,
    required String imageUrl,
  }) async {
    try {
      TechnicianModel? technician = await getTechnician(technicianId);
      if (technician == null) return false;

      // Remove from storage
      await _deleteFile(imageUrl);

      // Remove from Firestore array
      List<String> updatedImages = technician.workImages
          .where((url) => url != imageUrl)
          .toList();

      await _firestore.collection("users").doc(technicianId).update({
        'workImages': updatedImages,
      });

      return true;
    } catch (e) {
      print('Error removing work image: $e');
      return false;
    }
  }

  /// ============================
  /// UPDATE INTRO VIDEO
  /// ============================
  Future<String?> updateIntroVideo({
    required String technicianId,
    required File newVideo,
  }) async {
    try {
      // Delete old video if exists
      TechnicianModel? technician = await getTechnician(technicianId);
      if (technician?.introVideoUrl != null) {
        await _deleteFile(technician!.introVideoUrl!);
      }

      // Upload new video
      String videoUrl = await _uploadFile(
        file: newVideo,
        path: 'technicians/$technicianId/intro_video',
        fileName: 'intro_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // Update Firestore
      await _firestore.collection("users").doc(technicianId).update({
        'introVideoUrl': videoUrl,
      });

      return videoUrl;
    } catch (e) {
      print('Error updating intro video: $e');
      return null;
    }
  }

  /// ============================
  /// UPDATE TECHNICIAN CATEGORIES
  /// ============================
  Future<bool> updateTechnicianCategories({
    required String technicianId,
    required List<String> categories,
  }) async {
    try {
      await _firestore.collection("users").doc(technicianId).update({
        'categories': categories,
      });
      return true;
    } catch (e) {
      print('Error updating categories: $e');
      return false;
    }
  }

  /// ============================
  /// UPDATE TECHNICIAN BASIC INFO
  /// ============================
  Future<bool> updateTechnicianInfo({
    required String technicianId,
    String? name,
    String? phoneNumber,
    String? address,
    String? city,
    String? state,
    String? pincode,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;
      if (state != null) updates['state'] = state;
      if (pincode != null) updates['pincode'] = pincode;

      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection("users").doc(technicianId).update(updates);
      return true;
    } catch (e) {
      print('Error updating technician info: $e');
      return false;
    }
  }

  /// ============================
  /// GET ALL TECHNICIANS (with filters)
  /// ============================
  Future<List<TechnicianModel>> getAllTechnicians({
    String? category,
    String? pincode,
    bool onlyActive = true,
  }) async {
    try {
      Query query = _firestore
          .collection("users")
          .where("role", isEqualTo: "technician");

      if (onlyActive) {
        query = query.where("isActive", isEqualTo: true);
      }

      if (category != null) {
        query = query.where("categories", arrayContains: category);
      }

      if (pincode != null) {
        query = query.where("pincode", isEqualTo: pincode);
      }

      QuerySnapshot snapshot = await query.get();

      return snapshot.docs
          .map((doc) => TechnicianModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting technicians: $e');
      return [];
    }
  }

  /// ============================
  /// GET TECHNICIANS BY CATEGORY
  /// ============================
  Future<List<TechnicianModel>> getTechniciansByCategory(String category) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("users")
          .where("role", isEqualTo: "technician")
          .where("categories", arrayContains: category)
          .where("isActive", isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => TechnicianModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting technicians by category: $e');
      return [];
    }
  }

  /// ============================
  /// DELETE TECHNICIAN (Soft delete)
  /// ============================
  Future<bool> deactivateTechnician(String technicianId) async {
    try {
      await _firestore.collection("users").doc(technicianId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error deactivating technician: $e');
      return false;
    }
  }

  /// ============================
  /// PERMANENTLY DELETE TECHNICIAN
  /// ============================
  Future<bool> permanentlyDeleteTechnician(String technicianId) async {
    try {
      TechnicianModel? technician = await getTechnician(technicianId);
      if (technician != null) {
        // Delete all files from storage
        if (technician.profileImageUrl != null) {
          await _deleteFile(technician.profileImageUrl!);
        }

        for (String imageUrl in technician.workImages) {
          await _deleteFile(imageUrl);
        }

        if (technician.introVideoUrl != null) {
          await _deleteFile(technician.introVideoUrl!);
        }

        // Delete Firestore document
        await _firestore.collection("users").doc(technicianId).delete();
      }

      return true;
    } catch (e) {
      print('Error deleting technician: $e');
      return false;
    }
  }

  /// ============================
  /// PRIVATE HELPER: UPLOAD FILE
  /// ============================
  Future<String> _uploadFile({
    required File file,
    required String path,
    required String fileName,
  }) async {
    try {
      Reference ref = _storage.ref().child('$path/$fileName');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  /// ============================
  /// PRIVATE HELPER: DELETE FILE
  /// ============================
  Future<void> _deleteFile(String fileUrl) async {
    try {
      Reference ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      print('File deleted successfully');
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  /// ============================
  /// GET USER ROLE
  /// ============================
  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();

    if (doc.exists) {
      return doc.data()?['role'];
    }

    return null;
  }

  /// ============================
  /// GET CUSTOMER DATA
  /// ============================
  Future<CustomerModel?> getCustomer(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();

    if (doc.exists && doc.data()?['role'] == "customer") {
      return CustomerModel.fromMap(doc.data()!);
    }

    return null;
  }

  /// ============================
  /// GET TECHNICIAN DATA
  /// ============================
  Future<TechnicianModel?> getTechnician(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();

    if (doc.exists && doc.data()?['role'] == "technician") {
      return TechnicianModel.fromMap(doc.data()!);
    }

    return null;
  }
}