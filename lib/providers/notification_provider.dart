import 'dart:async';

import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Manages notification state — listing, read/unread status, and unread count.
class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<NotificationModel>>? _subscription;

  NotificationProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  // ─── Getters ───────────────────────────────────

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Number of unread notifications (used for badge count).
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // ─── Stream Management ─────────────────────────

  /// Start listening to this user's notifications.
  void listenToNotifications(String userId) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _firestoreService
        .notificationsStream(userId)
        .listen(
          (notifications) {
            _notifications = notifications;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (e, st) {
            AppLogger.error('Failed to load notifications stream', e, st);
            _error = ErrorHandler.getErrorMessage(e);
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Stop listening (call on sign-out).
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _notifications = [];
    _error = null;
    notifyListeners();
  }

  // ─── Actions ───────────────────────────────────

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestoreService.markNotificationAsRead(notificationId);
      // The stream will auto-update the list
    } catch (e, st) {
      AppLogger.error('Failed to mark notification as read', e, st);
      _error = ErrorHandler.getErrorMessage(e);
      notifyListeners();
    }
  }

  /// Mark ALL notifications as read.
  Future<void> markAllAsRead() async {
    try {
      final unreadIds = _notifications.where((n) => !n.isRead).map((n) => n.id).toList();
      if (unreadIds.isEmpty) return;
      await _firestoreService.markNotificationsAsReadBatch(unreadIds);
    } catch (e, st) {
      AppLogger.error('Failed to mark all as read', e, st);
      _error = ErrorHandler.getErrorMessage(e);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
