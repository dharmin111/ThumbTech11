import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// SIGN UP - Returns UserCredential
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Signup failed");
    }
  }
  Future<void> savePhoneNumber(String userId, String phoneNumber) async {
    await _firestore.collection('users').doc(userId).set({
      'phone': phoneNumber,
      'phoneNumber': phoneNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// SIGN UP - Simplified version that returns User? (optional)
  Future<User?> signUpAndGetUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Signup failed");
    }
  }

  /// LOGIN
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    }
  }

  /// LOGIN - Simplified version that returns User?
  Future<User?> loginAndGetUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? "Login failed");
    }
  }
  Future<void> saveUserRole({
    required String userId,
    required String email,
    required String role,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'id': userId,
      'email': email,
      'role': role,
      'isMerchant': role == 'merchant',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// FIRESTORE ACCESS
  FirebaseFirestore get firestore => _firestore;

  /// FORGOT PASSWORD
  Future<void> forgotPassword({
    required String email,
  }) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// CURRENT USER
  User? get currentUser => _auth.currentUser;

  /// AUTH STREAM
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}