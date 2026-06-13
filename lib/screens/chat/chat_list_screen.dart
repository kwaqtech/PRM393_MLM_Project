import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/helpers.dart';
import '../../utils/theme.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final FirestoreService? firestoreService;
  
  const ChatListScreen({super.key, this.firestoreService});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final FirestoreService _firestoreService;
  final Map<String, UserModel> _userCache = {};

  Future<UserModel?> _getUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final user = await _firestoreService.getUser(userId);
    if (user != null) {
      _userCache[userId] = user;
    }
    return user;
  }

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<ChatProvider>().listenToChatRooms(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _buildBody(context, auth, chatProvider),
      floatingActionButton: !auth.isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAdminPicker(context, auth),
              tooltip: 'New Chat',
              child: const Icon(Icons.chat_bubble_outline),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AuthProvider auth,
    ChatProvider chatProvider,
  ) {
    if (chatProvider.isLoadingRooms) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chatProvider.error != null) {
      return Center(
        child: Text(
          chatProvider.error!,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    if (chatProvider.chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 56,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Conversations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              auth.isAdmin
                  ? 'Students will appear here when they message you'
                  : 'Tap + to start a conversation',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chatProvider.chatRooms.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final room = chatProvider.chatRooms[index];
        return _ChatRoomTile(
          room: room,
          currentUserId: auth.currentUser!.id,
          getUser: _getUser,
          onTap: () {
            final otherUserId = room.participants.firstWhere(
              (id) => id != auth.currentUser!.id,
              orElse: () => '',
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChatScreen(chatRoomId: room.id, otherUserId: otherUserId),
              ),
            );
          },
        );
      },
    );
  }

  void _showAdminPicker(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StreamBuilder<List<UserModel>>(
          stream: _firestoreService.adminUsersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final admins = snapshot.data ?? [];
            if (admins.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('No librarians available')),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Start a conversation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ...admins.map(
                  (admin) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accentColor.withAlpha(38),
                      child: Text(
                        AppHelpers.initials(admin.fullName),
                        style: const TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(admin.fullName),
                    subtitle: Text(
                      admin.email,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final chatProvider = context.read<ChatProvider>();
                      final room = await chatProvider.getOrCreateChatRoom(
                        auth.currentUser!.id,
                        admin.id,
                      );
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatRoomId: room.id,
                              otherUserId: admin.id,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChatRoomTile extends StatefulWidget {
  final ChatRoomModel room;
  final String currentUserId;
  final VoidCallback onTap;
  final Future<UserModel?> Function(String) getUser;

  const _ChatRoomTile({
    required this.room,
    required this.currentUserId,
    required this.onTap,
    required this.getUser,
  });

  @override
  State<_ChatRoomTile> createState() => _ChatRoomTileState();
}

class _ChatRoomTileState extends State<_ChatRoomTile> {
  UserModel? _otherUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didUpdateWidget(_ChatRoomTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.participants != widget.room.participants) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    final otherUserId = widget.room.participants.firstWhere(
      (id) => id != widget.currentUserId,
      orElse: () => 'Unknown',
    );
    final user = await widget.getUser(otherUserId);
    if (mounted) {
      setState(() {
        _otherUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ListTile(
        title: Text('Loading...'),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      );
    }

    final name = _otherUser?.fullName ?? 'User';
    return ListTile(
      onTap: widget.onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      leading: CircleAvatar(
        backgroundColor: AppTheme.secondaryColor.withAlpha(38),
        child: Text(
          AppHelpers.initials(name),
          style: const TextStyle(
            color: AppTheme.secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          widget.room.lastMessage ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
      trailing: widget.room.lastMessageAt != null
          ? Text(
              _formatTime(widget.room.lastMessageAt!),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textHint,
              ),
            )
          : null,
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
