import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Parent-school chat screen with real-time messaging.
///
/// If [conversationId] is provided, loads that conversation.
/// Otherwise, loads or creates a default conversation with the school.
class ChatScreen extends StatefulWidget {
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  String _title = 'School Chat';
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      _loadConversation();
    } else {
      _loadOrCreateConversation();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Load an existing conversation by ID.
  Future<void> _loadConversation() async {
    if (_conversationId == null || _userId == null) return;

    try {
      final conv = await _supabase
          .from('chat_conversations')
          .select()
          .eq('id', _conversationId!)
          .maybeSingle();

      if (conv != null) {
        _title = conv['title'] as String? ?? 'School Chat';
      }

      await _loadMessages();
      _markMessagesAsRead();
      _subscribeToMessages();
    } catch (e) {
      debugPrint('ChatScreen: load conversation failed: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  /// Legacy: load or create a default conversation (when no ID provided).
  Future<void> _loadOrCreateConversation() async {
    if (_userId == null) return;

    try {
      // Get user's school_id
      final profile = await _supabase
          .from('profiles')
          .select('school_id')
          .eq('id', _userId!)
          .maybeSingle();

      final schoolId = profile?['school_id'];
      if (schoolId == null) {
        setState(() => _loading = false);
        return;
      }

      // Find existing open conversation
      final existing = await _supabase
          .from('chat_conversations')
          .select()
          .eq('parent_id', _userId!)
          .eq('school_id', schoolId)
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        _conversationId = existing['id'];
        _title = existing['title'] as String? ?? 'School Chat';
      } else {
        // Create new conversation
        final created = await _supabase
            .from('chat_conversations')
            .insert({
              'school_id': schoolId,
              'parent_id': _userId!,
              'title': 'Chat with School',
            })
            .select()
            .single();
        _conversationId = created['id'];
        _title = 'Chat with School';
      }

      await _loadMessages();
      _markMessagesAsRead();
      _subscribeToMessages();
    } catch (e) {
      debugPrint('ChatScreen: init failed: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    final data = await _supabase
        .from('chat_messages')
        .select('id, sender_id, content, is_from_school, read_at, created_at')
        .eq('conversation_id', _conversationId!)
        .order('created_at', ascending: true)
        .limit(100);

    if (mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data);
      });
      _scrollToBottom();
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_conversationId == null || _userId == null) return;

    try {
      // Mark messages from school as read
      await _supabase
          .from('chat_messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', _conversationId!)
          .eq('is_from_school', true)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('ChatScreen: mark read failed: $e');
    }
  }

  void _subscribeToMessages() {
    if (_conversationId == null) return;

    _channel = _supabase
        .channel('chat-$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId!,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (mounted) {
              setState(() => _messages.add(newMsg));
              _scrollToBottom();
              // Mark as read if from school
              if (newMsg['is_from_school'] == true) {
                _markMessagesAsRead();
              }
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || _userId == null) return;

    _messageController.clear();
    setState(() => _sending = true);

    // Optimistic: add message to list immediately
    final optimisticMsg = {
      'id': 'temp-${DateTime.now().millisecondsSinceEpoch}',
      'conversation_id': _conversationId,
      'sender_id': _userId,
      'content': text,
      'is_from_school': false,
      'read_at': null,
      'created_at': DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(optimisticMsg));
    _scrollToBottom();

    try {
      await _supabase.from('chat_messages').insert({
        'conversation_id': _conversationId!,
        'sender_id': _userId!,
        'content': text,
        'is_from_school': false,
      });

      // Update conversation last_message_at
      await _supabase
          .from('chat_conversations')
          .update({'last_message_at': DateTime.now().toIso8601String()})
          .eq('id', _conversationId!);
    } catch (e) {
      debugPrint('ChatScreen: send failed: $e');
      // Remove optimistic message on failure
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == optimisticMsg['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _sending = false);
  }

  String _timeLabel(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateSeparator(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) return 'Today';
    if (msgDate == yesterday) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final current = _messages[index]['created_at'] as String?;
    final previous = _messages[index - 1]['created_at'] as String?;
    if (current == null || previous == null) return false;

    final currentDt = DateTime.tryParse(current)?.toLocal();
    final previousDt = DateTime.tryParse(previous)?.toLocal();
    if (currentDt == null || previousDt == null) return false;

    return currentDt.day != previousDt.day ||
        currentDt.month != previousDt.month ||
        currentDt.year != previousDt.year;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.school, size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? _buildLoadingState()
          : Column(
              children: [
                // Messages
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48, color: AppTheme.textHint),
                              SizedBox(height: 12),
                              Text('No messages yet',
                                  style:
                                      TextStyle(color: AppTheme.textSecondary)),
                              SizedBox(height: 4),
                              Text('Send a message to the school',
                                  style: TextStyle(
                                      color: AppTheme.textHint, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender_id'] == _userId;
                            final isSchool = msg['is_from_school'] == true;
                            final showDate = _shouldShowDateSeparator(index);

                            return Column(
                              children: [
                                if (showDate)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDateSeparator(
                                            msg['created_at'] as String?),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                _MessageBubble(
                                  content: msg['content'] as String? ?? '',
                                  time: _timeLabel(
                                      msg['created_at'] as String?),
                                  isMe: isMe,
                                  isSchool: isSchool,
                                  isRead: msg['read_at'] != null,
                                ),
                              ],
                            );
                          },
                        ),
                ),

                // Input bar
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, i) => Align(
        alignment: i % 3 == 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65),
          decoration: BoxDecoration(
            color: i % 3 == 0 ? Colors.grey.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _sendMessage,
            icon: _sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final String time;
  final bool isMe;
  final bool isSchool;
  final bool isRead;

  const _MessageBubble({
    required this.content,
    required this.time,
    required this.isMe,
    required this.isSchool,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Icon(
                isSchool ? Icons.school : Icons.person,
                size: 16,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary : Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead ? Colors.blue : Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
