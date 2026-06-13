import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Manages authentication state — login, logout, current user, and role.
///
/// Uses [AuthService] for Firebase Auth operations and maintains
/// the current [UserModel] for role-based access throughout the app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isInitialized = false;
  UserModel? _currentUser;
  String? _errorMessage;

  // ─── Getters ────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentUser != null;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  // Convenience getters matching the old API (used by screens)
  String? get userId => _currentUser?.id;
  String? get userEmail => _currentUser?.email;
  String? get userName => _currentUser?.fullName;
  String? get userRole => _currentUser?.role;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // ─── Initialization ─────────────────────────────

  /// Check if the user is already signed in (e.g. app restart).
  /// Should be called once at app startup.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        // User was previously signed in — fetch their profile
        _currentUser = await _authService.getCurrentUserModel();
      }
    } catch (e, st) {
      // If we can't fetch the user profile, sign them out
      AppLogger.error('Auth init error', e, st);
      await _authService.signOut();
      _currentUser = null;
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  // ─── Sign In ────────────────────────────────────

  /// Sign in with email and password.
  /// Returns `true` on success, `false` on failure (check [errorMessage]).
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e, st) {
      AppLogger.error('Firebase Auth sign in error', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, st) {
      AppLogger.error('Unexpected sign in error', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Register ───────────────────────────────────

  /// Register a new student account.
  /// Returns `true` on success, `false` on failure (check [errorMessage]).
  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e, st) {
      AppLogger.error('Firebase Auth register error', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, st) {
      AppLogger.error('Unexpected register error', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Sign Out ───────────────────────────────────

  /// Sign out the current user and clear all state.
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Profile Update ─────────────────────────────

  /// Update the current user's display name.
  Future<void> updateName(String newName) async {
    if (_currentUser == null) return;

    await _authService.updateUserProfile(
      userId: _currentUser!.id,
      fullName: newName,
    );

    _currentUser = _currentUser!.copyWith(fullName: newName);
    notifyListeners();
  }

  /// Update the current user's avatar URL.
  Future<void> updateAvatar(String avatarUrl) async {
    if (_currentUser == null) return;

    await _authService.updateUserProfile(
      userId: _currentUser!.id,
      avatarUrl: avatarUrl,
    );

    _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
    notifyListeners();
  }

  // ─── Helpers ────────────────────────────────────

  /// Clear any error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
