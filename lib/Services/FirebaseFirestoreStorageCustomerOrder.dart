// Services/FirebaseFirestoreStorageCustomerOrder.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../model/ServiceRequestModel.dart';
import 'oneSignalNotificationService.dart';

class FirebaseFirestoreStorageCustomerOrder {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // ==================== IMAGE UPLOAD METHODS ====================

  /// Upload multiple images to Firebase Storage
  Future<List<String>> uploadServiceImages({
    required List<XFile> images,
    required String userId,
  }) async {
    List<String> imageUrls = [];

    for (int i = 0; i < images.length; i++) {
      try {
        final XFile image = images[i];
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final Reference storageRef = _storage.ref().child(
            'service_requests/$userId/$fileName'
        );

        await storageRef.putFile(File(image.path));
        final String downloadUrl = await storageRef.getDownloadURL();
        imageUrls.add(downloadUrl);

        print('✅ Image $i uploaded successfully');
      } catch (e) {
        print('❌ Error uploading image $i: $e');
        rethrow;
      }
    }

    return imageUrls;
  }

  /// Upload a single image
  Future<String?> uploadSingleImage({
    required XFile image,
    required String userId,
    required String folder,
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child(
          '$folder/$userId/$fileName'
      );

      await storageRef.putFile(File(image.path));
      final String downloadUrl = await storageRef.getDownloadURL();
      print('✅ Image uploaded successfully');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Delete images from storage
  Future<void> deleteImages(List<String> imageUrls) async {
    for (String url in imageUrls) {
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
        print('✅ Image deleted: $url');
      } catch (e) {
        print('❌ Error deleting image: $e');
      }
    }
  }

  // ==================== SERVICE REQUEST METHODS ====================

  /// Save service request with automatic technician matching and notifications
  Future<String> saveServiceRequestWithMatching({
    required ServiceRequestModel request,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get complete user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      // Update request with user details
      final updatedRequest = request.copyWith(
        userId: user.uid,
        userEmail: user.email ?? '',
        userName: userData?['name'] ?? 'Customer',
        userPhone: userData?['phone'] ?? '',
      );

      // Save to Firestore
      final docRef = await _firestore.collection('service_requests').add(updatedRequest.toFirestore());
      final requestId = docRef.id;

      print('📝 Service request saved. ID: $requestId');

      // Send notifications to matching technicians
      await _sendNotificationsToMatchingTechnicians(requestId, updatedRequest);

      // Send confirmation to customer
      await _sendCustomerConfirmation(user.uid, requestId, updatedRequest);

      print('✅ Service request saved successfully. ID: $requestId');
      return requestId;

    } catch (e) {
      print('❌ Error saving service request: $e');
      rethrow;
    }
  }

  /// Save service request without matching (direct booking)
  Future<String> saveServiceRequest({
    required ServiceRequestModel request,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final updatedRequest = request.copyWith(
        userId: user.uid,
        userEmail: user.email ?? '',
        userName: userData?['name'] ?? 'Customer',
        userPhone: userData?['phone'] ?? '',
      );

      final docRef = await _firestore.collection('service_requests').add(updatedRequest.toFirestore());
      final requestId = docRef.id;

      print('✅ Service request saved. ID: $requestId');
      return requestId;

    } catch (e) {
      print('❌ Error saving service request: $e');
      rethrow;
    }
  }

  /// Update existing service request
  Future<void> updateServiceRequest({
    required String requestId,
    required ServiceRequestModel request,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final docRef = _firestore.collection('service_requests').doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      // Only update if the request belongs to the current user
      final data = doc.data()!;
      if (data['userId'] != user.uid) {
        throw Exception('You are not authorized to update this request');
      }

      await docRef.update({
        ...request.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Service request updated: $requestId');

    } catch (e) {
      print('❌ Error updating service request: $e');
      rethrow;
    }
  }

  /// Cancel service request
  Future<void> cancelRequest(String requestId) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final docRef = _firestore.collection('service_requests').doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      // Only cancel if the request belongs to the current user
      final data = doc.data()!;
      if (data['userId'] != user.uid) {
        throw Exception('You are not authorized to cancel this request');
      }

      await docRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Request cancelled: $requestId');

    } catch (e) {
      print('❌ Error cancelling request: $e');
      rethrow;
    }
  }

  /// Re-post a rejected or expired service request
  Future<String> rePostRequest({
    required String requestId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final docRef = _firestore.collection('service_requests').doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      final data = doc.data()!;

      // Check if user owns this request
      if (data['userId'] != user.uid) {
        throw Exception('You are not authorized to repost this request');
      }

      // Update request status back to pending
      await docRef.update({
        'status': 'pending',
        'technicianId': null,
        'technicianName': null,
        'technicianPhone': null,
        'rejectedAt': null,
        'expiredAt': null,
        'repostedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'repostCount': FieldValue.increment(1),
      });

      // Send notification to matching technicians again
      final request = ServiceRequestModel.fromFirestore(doc, null);
      await _sendNotificationsToMatchingTechnicians(requestId, request);

      // Send confirmation to customer
      await _sendCustomerConfirmation(user.uid, requestId, request);

      print('✅ Request re-posted successfully: $requestId');
      return requestId;
    } catch (e) {
      print('❌ Error re-posting request: $e');
      rethrow;
    }
  }

  /// Permanently delete a request
  Future<void> permanentlyDeleteRequest(String requestId) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final docRef = _firestore.collection('service_requests').doc(requestId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw Exception('Request not found');
      }

      // Check if user owns this request
      final data = doc.data()!;
      if (data['userId'] != user.uid) {
        throw Exception('You are not authorized to delete this request');
      }

      // Delete any associated images
      if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) {
        await deleteImages(List<String>.from(data['imageUrls']));
      }

      await docRef.delete();
      print('✅ Request permanently deleted: $requestId');
    } catch (e) {
      print('❌ Error deleting request: $e');
      rethrow;
    }
  }

  // ==================== NOTIFICATION METHODS ====================

  /// Send notifications to matching technicians using OneSignal
  Future<void> _sendNotificationsToMatchingTechnicians(
      String requestId,
      ServiceRequestModel request,
      ) async {
    try {
      print('📤 Sending notifications to matching technicians...');

      await OneSignalNotificationService.notifyMatchingTechnicians(
        serviceType: request.serviceType,
        pincode: request.pincode,
        requestId: requestId,
        serviceName: request.serviceName,
        customerName: request.userName,
      );

      print('✅ Notifications sent to matching technicians');
    } catch (e) {
      print('❌ Error sending notifications: $e');
    }
  }

  /// Send confirmation to customer
  Future<void> _sendCustomerConfirmation(
      String userId,
      String requestId,
      ServiceRequestModel request,
      ) async {
    try {
      await OneSignalNotificationService.sendRequestPostedNotification(
        customerId: userId,
        serviceName: request.serviceName,
        requestId: requestId,
      );

      print('✅ Customer confirmation sent');
    } catch (e) {
      print('❌ Error sending customer confirmation: $e');
    }
  }

  /// Send notification when no technicians available
  Future<void> _sendNoTechniciansNotification(
      String userId,
      String requestId,
      ServiceRequestModel request,
      ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'userRole': 'customer',
        'title': 'No Technicians Available',
        'body': 'Currently no technicians available in your area for ${request.serviceName}. We will notify you when someone is available.',
        'type': 'no_technicians',
        'requestId': requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending no technicians notification: $e');
    }
  }

  // ==================== REQUEST ACCEPTANCE METHODS ====================

  /// Accept service request by technician
  Future<void> acceptServiceRequest({
    required String requestId,
    required String technicianId,
    required String technicianName,
    required String technicianPhone,
    double? estimatedPrice,
    String? estimatedTime,
  }) async {
    try {
      final requestDoc = await _firestore.collection('service_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Service request not found');
      }

      final requestData = requestDoc.data()!;

      // Update service request status
      await _firestore.collection('service_requests').doc(requestId).update({
        'technicianId': technicianId,
        'technicianName': technicianName,
        'technicianPhone': technicianPhone,
        'estimatedPrice': estimatedPrice,
        'estimatedTime': estimatedTime,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove from technician's pending requests
      final pendingDoc = await _firestore
          .collection('technician_pending_requests')
          .doc('${technicianId}_$requestId')
          .get();

      if (pendingDoc.exists) {
        await pendingDoc.reference.delete();
      }

      // Send notification to customer using OneSignal
      await OneSignalNotificationService.sendNotificationToUser(
        userId: requestData['userId'],
        title: '🎉 Service Request Accepted!',
        body: 'Your request has been accepted by $technicianName. They will contact you soon.',
        data: {
          'type': 'request_accepted',
          'requestId': requestId,
          'technicianId': technicianId,
          'technicianName': technicianName,
          'technicianPhone': technicianPhone,
          'estimatedPrice': estimatedPrice,
        },
      );

      // Send confirmation to technician using OneSignal
      await OneSignalNotificationService.sendNotificationToUser(
        userId: technicianId,
        title: '✅ Request Accepted!',
        body: 'You have accepted the service request from ${requestData['userName']}.',
        data: {
          'type': 'offer_accepted',
          'requestId': requestId,
          'customerName': requestData['userName'],
          'customerPhone': requestData['userPhone'],
        },
      );

      print('✅ Technician $technicianName accepted request $requestId');

    } catch (e) {
      print('❌ Error accepting request: $e');
      rethrow;
    }
  }

  /// Reject service request by technician
  Future<void> rejectServiceRequest({
    required String requestId,
    required String technicianId,
    String? reason,
  }) async {
    try {
      final requestDoc = await _firestore.collection('service_requests').doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Service request not found');
      }

      final requestData = requestDoc.data()!;

      // Update service request status
      await _firestore.collection('service_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason ?? 'Technician rejected the request',
        'rejectedBy': technicianId,
        'rejectedByName': requestData['technicianName'] ?? 'Technician',
      });

      // Remove from technician's pending requests
      final pendingDoc = await _firestore
          .collection('technician_pending_requests')
          .doc('${technicianId}_$requestId')
          .get();

      if (pendingDoc.exists) {
        await pendingDoc.reference.delete();
      }

      // Send notification to customer
      await OneSignalNotificationService.sendNotificationToUser(
        userId: requestData['userId'],
        title: '❌ Request Rejected',
        body: 'Your request has been rejected by ${requestData['technicianName'] ?? 'Technician'}. Reason: ${reason ?? "Not specified"}',
        data: {
          'type': 'request_rejected',
          'requestId': requestId,
          'reason': reason,
        },
      );

      print('✅ Request $requestId rejected by technician');

    } catch (e) {
      print('❌ Error rejecting request: $e');
      rethrow;
    }
  }

  /// Complete service request (mark as completed)
  Future<void> completeServiceRequest({
    required String requestId,
    String? feedback,
    double? rating,
  }) async {
    try {
      final updates = {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (feedback != null) {
        updates['feedback'] = feedback;
      }

      if (rating != null) {
        updates['rating'] = rating;
      }

      await _firestore.collection('service_requests').doc(requestId).update(updates);
      print('✅ Service request $requestId completed');

    } catch (e) {
      print('❌ Error completing request: $e');
      rethrow;
    }
  }

  // ==================== UPDATE STATUS METHODS ====================

  /// Update service request status
  Future<void> updateServiceRequestStatus({
    required String requestId,
    required String status,
    String? cancellationReason,
  }) async {
    try {
      final updates = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (cancellationReason != null) {
        updates['cancellationReason'] = cancellationReason;
      }

      if (status == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      if (status == 'expired') {
        updates['expiredAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('service_requests').doc(requestId).update(updates);
      print('✅ Service request $requestId status updated to $status');

    } catch (e) {
      print('❌ Error updating status: $e');
      rethrow;
    }
  }

  /// Mark request as expired
  Future<void> markRequestAsExpired(String requestId) async {
    try {
      await _firestore.collection('service_requests').doc(requestId).update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Request $requestId marked as expired');
    } catch (e) {
      print('❌ Error marking request as expired: $e');
    }
  }

  // ==================== FETCH METHODS ====================

  /// Get all service requests for current user
  Stream<List<ServiceRequestModel>> getUserServiceRequests() {
    final user = currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('service_requests')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get service request by ID
  Future<ServiceRequestModel?> getServiceRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection('service_requests').doc(requestId).get();
      if (doc.exists) {
        return ServiceRequestModel.fromFirestore(doc, null);
      }
      return null;
    } catch (e) {
      print('❌ Error getting service request: $e');
      return null;
    }
  }

  /// Get all pending service requests (for technicians)
  Stream<List<ServiceRequestModel>> getPendingServiceRequests() {
    return _firestore
        .collection('service_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get pending requests for a specific technician
  Stream<List<ServiceRequestModel>> getTechnicianPendingRequests(String technicianId) {
    return _firestore
        .collection('service_requests')
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get technician's accepted requests
  Stream<List<ServiceRequestModel>> getTechnicianAcceptedRequests(String technicianId) {
    return _firestore
        .collection('service_requests')
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'accepted')
        .orderBy('acceptedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get technician's completed requests
  Stream<List<ServiceRequestModel>> getTechnicianCompletedRequests(String technicianId) {
    return _firestore
        .collection('service_requests')
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get requests by status for current user
  Future<List<ServiceRequestModel>> getRequestsByStatus(String status) async {
    final user = currentUser;
    if (user == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('service_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    } catch (e) {
      print('❌ Error getting requests by status: $e');
      return [];
    }
  }

  /// Get requests by pincode (for technicians)
  Stream<List<ServiceRequestModel>> getRequestsByPincode(String pincode) {
    return _firestore
        .collection('service_requests')
        .where('pincode', isEqualTo: pincode)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get requests by service type
  Stream<List<ServiceRequestModel>> getRequestsByServiceType(String serviceType) {
    return _firestore
        .collection('service_requests')
        .where('serviceType', isEqualTo: serviceType)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  /// Get matching requests for technician
  Stream<List<ServiceRequestModel>> getMatchingRequestsForTechnician({
    required String technicianId,
    required String pincode,
    required String serviceType,
  }) {
    return _firestore
        .collection('service_requests')
        .where('pincode', isEqualTo: pincode)
        .where('serviceType', isEqualTo: serviceType)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromFirestore(doc, null))
          .toList();
    });
  }

  // ==================== TECHNICIAN PENDING REQUESTS ====================

  /// Add request to technician's pending requests
  Future<void> addTechnicianPendingRequest({
    required String technicianId,
    required String requestId,
    required String serviceName,
    required String customerName,
    required String customerPincode,
  }) async {
    try {
      await _firestore
          .collection('technician_pending_requests')
          .doc('${technicianId}_$requestId')
          .set({
        'technicianId': technicianId,
        'requestId': requestId,
        'serviceName': serviceName,
        'customerName': customerName,
        'customerPincode': customerPincode,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Added pending request for technician: $technicianId');
    } catch (e) {
      print('❌ Error adding pending request: $e');
    }
  }

  /// Remove request from technician's pending requests
  Future<void> removeTechnicianPendingRequest({
    required String technicianId,
    required String requestId,
  }) async {
    try {
      await _firestore
          .collection('technician_pending_requests')
          .doc('${technicianId}_$requestId')
          .delete();
      print('✅ Removed pending request for technician: $technicianId');
    } catch (e) {
      print('❌ Error removing pending request: $e');
    }
  }

  /// Get technician's pending requests
  Stream<List<Map<String, dynamic>>> getTechnicianPendingRequestsList(String technicianId) {
    return _firestore
        .collection('technician_pending_requests')
        .where('technicianId', isEqualTo: technicianId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ==================== RATINGS AND REVIEWS ====================

  /// Add rating and review for technician
  Future<void> addTechnicianRating({
    required String technicianId,
    required double rating,
    required String review,
    required String requestId,
  }) async {
    try {
      // Add rating to technician's profile
      final techRef = _firestore.collection('users').doc(technicianId);

      await _firestore.runTransaction((transaction) async {
        final techDoc = await transaction.get(techRef);
        if (techDoc.exists) {
          final data = techDoc.data()!;
          final currentRating = data['rating'] ?? 0.0;
          final currentReviews = data['totalReviews'] ?? 0;
          final newTotal = currentReviews + 1;
          final newRating = ((currentRating * currentReviews) + rating) / newTotal;

          transaction.update(techRef, {
            'rating': newRating,
            'totalReviews': newTotal,
          });
        }
      });

      // Add review to reviews collection
      await _firestore.collection('reviews').add({
        'technicianId': technicianId,
        'requestId': requestId,
        'rating': rating,
        'review': review,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': currentUser?.uid,
        'userName': currentUser?.displayName ?? 'Customer',
      });

      // Update request with rating
      await _firestore.collection('service_requests').doc(requestId).update({
        'rating': rating,
        'review': review,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Rating added for technician: $technicianId');
    } catch (e) {
      print('❌ Error adding rating: $e');
      rethrow;
    }
  }

  /// Get technician ratings
  Future<Map<String, dynamic>> getTechnicianRatings(String technicianId) async {
    try {
      final reviews = await _firestore
          .collection('reviews')
          .where('technicianId', isEqualTo: technicianId)
          .get();

      final totalReviews = reviews.docs.length;
      double averageRating = 0.0;

      if (totalReviews > 0) {
        double sum = 0.0;
        for (var doc in reviews.docs) {
          sum += (doc.data()['rating'] ?? 0.0) as double;
        }
        averageRating = sum / totalReviews;
      }

      return {
        'averageRating': averageRating,
        'totalReviews': totalReviews,
        'reviews': reviews.docs.map((doc) => doc.data()).toList(),
      };
    } catch (e) {
      print('❌ Error getting technician ratings: $e');
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'reviews': [],
      };
    }
  }

  // ==================== HELPER METHODS ====================

  bool isUserLoggedIn() {
    return currentUser != null;
  }

  String? getCurrentUserId() {
    return currentUser?.uid;
  }

  String? getCurrentUserEmail() {
    return currentUser?.email;
  }

  String? getCurrentUserPhone() {
    return currentUser?.phoneNumber;
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Get user data by ID
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Check if technician is available for service
  Future<bool> isTechnicianAvailable({
    required String technicianId,
    required String serviceType,
    required String pincode,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(technicianId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;

      // Check if technician is active
      if (data['isActive'] != true) return false;

      // Check categories
      final categories = List<String>.from(data['categories'] ?? []);
      if (!categories.contains(serviceType)) return false;

      // Check pincodes
      List<String> pincodes = [];
      if (data['pincodes'] != null && (data['pincodes'] as List).isNotEmpty) {
        pincodes = List<String>.from(data['pincodes']);
      } else if (data['pincode'] != null && data['pincode'].toString().isNotEmpty) {
        pincodes = [data['pincode'].toString()];
      }

      return pincodes.contains(pincode);
    } catch (e) {
      print('❌ Error checking technician availability: $e');
      return false;
    }
  }
}