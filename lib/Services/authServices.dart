import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// GOOGLE SIGN IN (Opens Google Account Chooser popup showing all emails)
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '988985361848-c94os6upofc6jej5l4s3g91q28k7i6aq.apps.googleusercontent.com',
      );

      // Force Account Chooser popup dialog to open showing all email accounts
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("Google Sign-In canceled by user");
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception("Google Sign-In error: $e");
    }
  }

  /// APPLE SIGN IN
  Future<UserCredential> signInWithApple() async {
    try {
      final AppleAuthProvider appleProvider = AppleAuthProvider();
      return await _auth.signInWithProvider(appleProvider);
    } catch (e) {
      throw Exception("Apple Sign-In error: $e");
    }
  }

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
    String? email,
    String? phoneNumber,
    String? name,
    required String role,
  }) async {
    final Map<String, dynamic> data = {
      'id': userId,
      'role': role,
      'isMerchant': role == 'merchant',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }
    if (name != null && name.isNotEmpty) {
      data['name'] = name;
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      data['phoneNumber'] = phoneNumber;
      data['phone'] = phoneNumber;
    }

    final docRef = _firestore.collection('users').doc(userId);
    final doc = await docRef.get();
    if (!doc.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(data, SetOptions(merge: true));
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
