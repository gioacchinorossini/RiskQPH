import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationsTabSliver extends StatelessWidget {
  const NotificationsTabSliver({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy notifications for UI demonstration
    final List<Map<String, dynamic>> notifications = [
      {
        'type': 'Alert',
        'title': 'Heavy Rain Warning',
        'desc': 'Severe flooding expected in Brgy. 630. Evacuate if necessary.',
        'time': DateTime.now().subtract(const Duration(minutes: 15)),
        'isRead': false,
        'icon': Icons.warning_amber_rounded,
        'color': Colors.red,
      },
      {
        'type': 'Update',
        'title': 'Evacuation Center Full',
        'desc': 'Multi-Purpose Hall has reached maximum capacity.',
        'time': DateTime.now().subtract(const Duration(hours: 1)),
        'isRead': true,
        'icon': Icons.info_outline,
        'color': Colors.orange,
      },
      {
        'type': 'Rescue',
        'title': 'Rescue Success',
        'desc': '3 residents were successfully extracted from Zone 4.',
        'time': DateTime.now().subtract(const Duration(hours: 3)),
        'isRead': true,
        'icon': Icons.check_circle_outline,
        'color': Colors.green,
      },
      {
        'type': 'Barangay',
        'title': 'Relief Goods Distribution',
        'desc': 'Distribution starts tomorrow, 8:00 AM at the Barangay Hall.',
        'time': DateTime.now().subtract(const Duration(days: 1)),
        'isRead': true,
        'icon': Icons.inventory_2_outlined,
        'color': Colors.blue,
      },
    ];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Mark all as read'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            ...notifications.map((n) => _buildNotificationCard(context, n)),
        ]),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> n) {
    final bool isRead = n['isRead'] as bool;
    final Color color = n['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(n['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          n['type'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          _formatTime(n['time'] as DateTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['title'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['desc'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, top: 24),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM dd').format(dt);
  }
}
