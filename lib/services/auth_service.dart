import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../utils/constants.dart';

/// Wrapper around Firebase Authentication.
/// Handles sign-in, registration, sign-out, and user profile management.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The currently signed-in Firebase user, or null.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (sign-in / sign-out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  /// Returns the [UserModel] on success.
  Future<UserModel> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final userId = credential.user!.uid;
    return _getUserModel(userId);
  }

  /// Register a new student account.
  /// Creates both the Firebase Auth user and a Firestore user document.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final userId = credential.user!.uid;

    // Create the user document in Firestore
    final user = UserModel(
      id: userId,
      email: email.trim(),
      fullName: name.trim(),
      role: AppConstants.roleStudent, // new users are always students
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .set(user.toFirestore());

    return user;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetch the [UserModel] for the given [userId] from Firestore.
  Future<UserModel> _getUserModel(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (!doc.exists) {
      throw Exception('User document not found for id: $userId');
    }

    return UserModel.fromFirestore(doc);
  }

  /// Fetch the [UserModel] for the currently signed-in user.
  /// Throws if no user is signed in.
  Future<UserModel> getCurrentUserModel() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }
    return _getUserModel(user.uid);
  }

  /// Update the user profile (name, avatar) in Firestore.
  Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['fullName'] = fullName;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(updates);
    }
  }
}
