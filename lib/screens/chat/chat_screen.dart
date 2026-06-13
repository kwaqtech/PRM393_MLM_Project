import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';

/// Real-time chat screen between two users.
class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatProvider _chatProvider;
  int _previousMessageCount = 0;
  UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _chatProvider = context.read<ChatProvider>();
    // Open the chat room to start listening to messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider.openChatRoom(widget.chatRoomId);
      _loadOtherUser();
    });
  }

  Future<void> _loadOtherUser() async {
    final user = await FirestoreService().getUser(widget.otherUserId);
    if (mounted) setState(() => _otherUser = user);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Close the chat room when leaving
    _chatProvider.closeChatRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    // Auto-scroll to bottom when new messages arrive
    final currentMessageCount = chatProvider.messages.length;
    if (currentMessageCount > _previousMessageCount) {
      _previousMessageCount = currentMessageCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withAlpha(51),
              child: Text(
                AppHelpers.initials(_otherUser?.fullName ?? 'U'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUser?.fullName ?? 'Loading...',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_otherUser != null)
                    Text(
                      _otherUser!.isAdmin ? 'Librarian' : 'Student',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withAlpha(179),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatProvider.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nSay hello! 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatProvider.messages[index];
                      final isMe = msg.senderId == auth.currentUser!.id;
                      final showDate =
                          index == 0 ||
                          !AppHelpers.isSameDay(
                            chatProvider.messages[index - 1].sentAt,
                            msg.sentAt,
                          );
                      return Column(
                        children: [
                          if (showDate) _DateSeparator(date: msg.sentAt),
                          _MessageBubble(message: msg, isMe: isMe),
                        ],
                      );
                    },
                  ),
          ),

          // Message input
          _MessageInput(
            controller: _messageController,
            isSending: chatProvider.isSending,
            onSend: () => _sendMessage(auth, chatProvider),
          ),
        ],
      ),
    );
  }

  void _sendMessage(AuthProvider auth, ChatProvider chatProvider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    await chatProvider.sendMessage(
      chatRoomId: widget.chatRoomId,
      senderId: auth.currentUser!.id,
      text: text,
      senderName: auth.currentUser!.fullName,
    );
  }
}

/// A chat bubble for a single message.
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.sentAt),
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white.withAlpha(153) : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date separator between messages on different days.
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (AppHelpers.isSameDay(date, now)) {
      label = 'Today';
    } else if (AppHelpers.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// Message input bar at the bottom.
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        8,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primaryColor,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: isSending ? null : onSend,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
