import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload a single image to Firebase Storage
  Future<String?> uploadImage({
    required File imageFile,
    required String userId,
    required String folderName,
    required String fileName,
  }) async {
    try {
      String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      Reference ref = _storage
          .ref()
          .child('technicians/$userId/$folderName/$uniqueFileName');

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Image uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Upload multiple images
  Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    required String userId,
    required String folderName,
  }) async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      String? url = await uploadImage(
        imageFile: imageFiles[i],
        userId: userId,
        folderName: folderName,
        fileName: 'work_image_$i.jpg',
      );
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  /// Upload ID Card Image
  Future<String?> uploadIdCardImage({
    required File idCardFile,
    required String userId,
  }) async {
    return await uploadImage(
      imageFile: idCardFile,
      userId: userId,
      folderName: 'id_card',
      fileName: 'id_card.jpg',
    );
  }

  /// Delete an image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Delete multiple images
  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (String url in imageUrls) {
      await deleteImage(url);
    }
  }
}