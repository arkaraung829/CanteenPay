import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Parent-school chat screen with real-time messaging.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadOrCreateConversation();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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
      }

      await _loadMessages();
      _subscribeToMessages();
    } catch (e) {
      debugPrint('ChatScreen: init failed: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    final data = await _supabase
        .from('chat_messages')
        .select('id, sender_id, content, is_from_school, read_at, created_at')
        .eq('conversation_id', _conversationId!)
        .order('created_at', ascending: true)
        .limit(100);

    setState(() {
      _messages = List<Map<String, dynamic>>.from(data);
    });

    _scrollToBottom();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }

    setState(() => _sending = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with School'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textHint),
                              SizedBox(height: 12),
                              Text('No messages yet', style: TextStyle(color: AppTheme.textSecondary)),
                              SizedBox(height: 4),
                              Text('Send a message to the school', style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender_id'] == _userId;
                            final isSchool = msg['is_from_school'] == true;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
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
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppTheme.primary
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                                          bottomRight: Radius.circular(isMe ? 4 : 16),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            msg['content'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isMe ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _timeLabel(msg['created_at']),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) const SizedBox(width: 8),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Input bar
                Container(
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
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                ),
              ],
            ),
    );
  }
}
