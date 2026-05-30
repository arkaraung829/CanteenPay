import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Messages list screen showing all parent-school conversations.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _error;

  SupabaseClient get _supabase => Supabase.instance.client;
  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _supabase
          .from('chat_conversations')
          .select(
              '*, chat_messages(content, created_at, is_from_school, sender_id)')
          .eq('parent_id', _userId!)
          .order('last_message_at', ascending: false);

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversations: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewConversation() async {
    if (_userId == null) return;

    try {
      // Get user's school_id from profile
      final profile = await _supabase
          .from('profiles')
          .select('school_id')
          .eq('id', _userId!)
          .maybeSingle();

      final schoolId = profile?['school_id'];
      if (schoolId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No school linked to your account')),
          );
        }
        return;
      }

      // Show subject dialog
      final subject = await _showSubjectDialog();
      if (subject == null) return;

      final created = await _supabase
          .from('chat_conversations')
          .insert({
            'parent_id': _userId!,
            'school_id': schoolId,
            'title': subject,
          })
          .select()
          .single();

      if (mounted) {
        context.push('/parent/chat/${created['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create conversation: $e')),
        );
      }
    }
  }

  Future<String?> _showSubjectDialog() async {
    final controller = TextEditingController(text: 'General');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Subject',
            hintText: 'e.g. General, Billing, Menu',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(context, text.isEmpty ? 'General' : text);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _lastMessagePreview(Map<String, dynamic> conversation) {
    final messages = conversation['chat_messages'] as List?;
    if (messages == null || messages.isEmpty) return 'No messages yet';

    // Sort by created_at descending to get the latest
    final sorted = List<Map<String, dynamic>>.from(messages)
      ..sort((a, b) {
        final aTime = a['created_at'] as String? ?? '';
        final bTime = b['created_at'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

    final latest = sorted.first;
    final content = latest['content'] as String? ?? '';
    final isFromSchool = latest['is_from_school'] == true;
    final isMine = latest['sender_id'] == _userId;

    String prefix = '';
    if (isMine) {
      prefix = 'You: ';
    } else if (isFromSchool) {
      prefix = 'School: ';
    }

    final truncated =
        content.length > 50 ? '${content.substring(0, 50)}...' : content;
    return '$prefix$truncated';
  }

  String _timeAgo(Map<String, dynamic> conversation) {
    final lastAt = conversation['last_message_at'] as String?;
    final createdAt = conversation['created_at'] as String?;
    final dateStr = lastAt ?? createdAt;
    if (dateStr == null) return '';

    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to start a conversation with your school',
              style: TextStyle(color: AppTheme.textHint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _ConversationTile(
            title: conversation['title'] as String? ?? 'General',
            preview: _lastMessagePreview(conversation),
            timeAgo: _timeAgo(conversation),
            status: conversation['status'] as String? ?? 'open',
            onTap: () async {
              await context.push('/parent/chat/${conversation['id']}');
              // Refresh after returning from chat
              _loadConversations();
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String title;
  final String preview;
  final String timeAgo;
  final String status;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.title,
    required this.preview,
    required this.timeAgo,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed = status == 'closed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isClosed
              ? Colors.grey[200]
              : AppTheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.school,
            size: 22,
            color: isClosed ? Colors.grey : AppTheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              timeAgo,
              style: const TextStyle(
                color: AppTheme.textHint,
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
