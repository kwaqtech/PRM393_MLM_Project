import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a chat message.
class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;

  // Denormalized for display
  final String? senderName;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.senderName,
  });

  /// Create a [MessageModel] from a Firestore document snapshot.
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      senderName: data['senderName'],
    );
  }

  /// Convert this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      'senderName': senderName,
    };
  }

  @override
  String toString() => 'MessageModel(id: $id, senderId: $senderId)';
}

/// Data model for a chat room between two users.
class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  ChatRoomModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageAt,
  });

  /// Create a [ChatRoomModel] from a Firestore document snapshot.
  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : null,
    };
  }

  @override
  String toString() => 'ChatRoomModel(id: $id, participants: $participants)';
}
