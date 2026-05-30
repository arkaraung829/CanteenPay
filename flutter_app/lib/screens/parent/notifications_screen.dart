import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/notification_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

/// Notification list screen with tabs for Notifications and Announcements.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _announcements = [];
  bool _announcementsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnnouncements();
    // Clear app icon badge when user opens notifications screen
    NotificationService.instance.clearBadge();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get user's school_id from profile
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('school_id')
          .eq('id', user.id)
          .maybeSingle();

      final schoolId = profile?['school_id'];
      if (schoolId == null) {
        setState(() => _announcementsLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('announcements')
          .select('id, title, title_my, body, body_my, target_audience, published_at, created_at, schools(name)')
          .eq('school_id', schoolId)
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _announcements = List<Map<String, dynamic>>.from(response);
        _announcementsLoading = false;
      });
    } catch (e) {
      debugPrint('NotificationsScreen: failed to load announcements: $e');
      setState(() => _announcementsLoading = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'purchase':
        return Icons.shopping_cart;
      case 'deposit':
        return Icons.account_balance_wallet;
      case 'low_balance':
        return Icons.warning_amber;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'purchase':
        return AppTheme.error;
      case 'deposit':
        return AppTheme.success;
      case 'low_balance':
        return AppTheme.secondary;
      case 'announcement':
        return AppTheme.primary;
      default:
        return AppTheme.primary;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Activity', style: TextStyle(fontWeight: FontWeight.w600)),
                  if (provider.unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(child: Text('Announcements', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(provider),
          _buildAnnouncementsTab(),
        ],
      ),
    );
  }

  Widget _buildActivityTab(NotificationProvider provider) {
    final notifications = provider.notifications;

    if (provider.isLoading) {
      return ListView(
        children: [for (int i = 0; i < 6; i++) ShimmerLoading.listTile()],
      );
    }

    if (notifications.isEmpty) {
      return EmptyStateWidget.noNotifications();
    }

    return AnimatedFadeIn(
      child: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final color = _colorForType(notif.type ?? 'system');
          return ListTile(
            tileColor:
                notif.isRead ? null : AppTheme.primary.withValues(alpha: 0.06),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                _iconForType(notif.type ?? 'system'),
                color: color,
                size: 20,
              ),
            ),
            title: Text(
              notif.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    notif.isRead ? FontWeight.w500 : FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              notif.body,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _timeAgo(notif.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => provider.markAsRead(notif.id),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    if (_announcementsLoading) {
      return ListView(
        children: [for (int i = 0; i < 4; i++) ShimmerLoading.listTile()],
      );
    }

    if (_announcements.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 48, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('No announcements yet',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _announcements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final a = _announcements[index];
          final publishedAt = a['published_at'] ?? a['created_at'];
          final date = publishedAt != null
              ? DateTime.tryParse(publishedAt)
              : null;
          final schools = a['schools'];
          final schoolName = schools is Map ? schools['name'] : null;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.campaign, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          if (schoolName != null || date != null)
                            Row(
                              children: [
                                if (schoolName != null)
                                  Flexible(
                                    child: Text(
                                      schoolName,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                if (schoolName != null && date != null)
                                  Text(' · ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                if (date != null)
                                  Text(
                                    _timeAgo(date),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  a['body'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                ),
                if (a['body_my'] != null && (a['body_my'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    a['body_my'],
                    style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
