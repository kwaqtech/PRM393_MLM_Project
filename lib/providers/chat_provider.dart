import 'dart:async';

import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../services/firestore_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Manages chat state — chat rooms, messages, and sending.
class ChatProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  StreamSubscription<List<ChatRoomModel>>? _roomsSub;
  StreamSubscription<List<MessageModel>>? _messagesSub;

  ChatProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<ChatRoomModel> _chatRooms = [];
  List<MessageModel> _messages = [];
  String? _activeChatRoomId;
  bool _isLoadingRooms = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _error;

  // ─── Getters ───────────────────────────────────

  List<ChatRoomModel> get chatRooms => _chatRooms;
  List<MessageModel> get messages => _messages;
  String? get activeChatRoomId => _activeChatRoomId;
  bool get isLoadingRooms => _isLoadingRooms;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get error => _error;

  // ─── Chat Rooms ────────────────────────────────

  /// Start listening to chat rooms for this user.
  void listenToChatRooms(String userId) {
    _isLoadingRooms = true;
    _error = null;
    notifyListeners();

    _roomsSub?.cancel();
    _roomsSub = _firestoreService
        .chatRoomsStream(userId)
        .listen(
          (rooms) {
            _chatRooms = rooms;
            _isLoadingRooms = false;
            _error = null;
            notifyListeners();
          },
          onError: (e, st) {
            AppLogger.error('Failed to load chat rooms stream', e, st);
            _error = ErrorHandler.getErrorMessage(e);
            _isLoadingRooms = false;
            notifyListeners();
          },
        );
  }

  /// Stop listening to rooms (on sign-out).
  void stopListening() {
    _roomsSub?.cancel();
    _roomsSub = null;
    _messagesSub?.cancel();
    _messagesSub = null;
    _chatRooms = [];
    _messages = [];
    _activeChatRoomId = null;
    _error = null;
    notifyListeners();
  }

  // ─── Messages ──────────────────────────────────

  /// Open a chat room and start listening to its messages.
  void openChatRoom(String chatRoomId) {
    _activeChatRoomId = chatRoomId;
    _isLoadingMessages = true;
    _messages = [];
    notifyListeners();

    _messagesSub?.cancel();
    _messagesSub = _firestoreService
        .messagesStream(chatRoomId)
        .listen(
          (msgs) {
            _messages = msgs;
            _isLoadingMessages = false;
            notifyListeners();
          },
          onError: (e, st) {
            AppLogger.error('Failed to load messages stream', e, st);
            _error = ErrorHandler.getErrorMessage(e);
            _isLoadingMessages = false;
            notifyListeners();
          },
        );
  }

  /// Close the active chat room (stop listening to messages).
  void closeChatRoom() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _messages = [];
    _activeChatRoomId = null;
    notifyListeners();
  }

  // ─── Actions ───────────────────────────────────

  /// Get or create a chat room between two users.
  Future<ChatRoomModel> getOrCreateChatRoom(
    String currentUserId,
    String otherUserId,
  ) async {
    return _firestoreService.getOrCreateChatRoom(currentUserId, otherUserId);
  }

  /// Send a text message in the active chat room.
  Future<bool> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String text,
    String? senderName,
  }) async {
    if (text.trim().isEmpty) return false;

    _isSending = true;
    notifyListeners();

    try {
      final message = MessageModel(
        id: '', // Firestore will generate
        senderId: senderId,
        text: text.trim(),
        sentAt: DateTime.now(),
        senderName: senderName,
      );

      await _firestoreService.sendMessage(
        chatRoomId: chatRoomId,
        message: message,
      );

      _isSending = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to send message', e, st);
      _error = ErrorHandler.getErrorMessage(e);
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }
}
