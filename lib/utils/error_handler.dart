import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message ?? 'An authentication error occurred.';
      }
    } else if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
        case 'network-request-failed':
          return 'Service unavailable. Please check your internet connection.';
        case 'not-found':
          return 'The requested resource was not found.';
        default:
          return error.message ?? 'A database error occurred.';
      }
    } else if (error is PlatformException) {
      return error.message ?? 'A platform error occurred.';
    }
    
    return error.toString();
  }
}
