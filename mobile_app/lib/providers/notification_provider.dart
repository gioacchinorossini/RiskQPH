import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'dart:io';

enum AppNotificationType {
  Alert,
  Update,
  Rescue,
  Barangay,
  Proximity
}

class AppNotification {
  final String id;
  final String type;
  final AppNotificationType category;
  final String title;
  final String desc;
  final DateTime time;
  final IconData icon;
  final Color color;
  final double? latitude;
  final double? longitude;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.desc,
    required this.time,
    required this.icon,
    required this.color,
    this.latitude,
    this.longitude,
    this.isRead = false,
  });
}

class NotificationProvider with ChangeNotifier {
  final List<AppNotification> _notifications = [];
  AppNotification? _latestIncoming;

  AppNotification? get latestIncoming => _latestIncoming;

  void clearLatest() {
    _latestIncoming = null;
    notifyListeners();
  }

  List<AppNotification> get notifications {
    final list = [..._notifications];
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  HttpClient? _sseClient;
  bool _isConnecting = false;

  void connect() {
    _startNotificationStream();
  }

  void _startNotificationStream() {
    if (_isConnecting) return;
    _isConnecting = true;

    final url = Uri.parse('${ApiConfig.baseUrl}/api/notifications/events');

    _sseClient?.close(force: true);
    _sseClient = HttpClient();

    Future.microtask(() async {
      try {
        final request = await _sseClient!.getUrl(url);
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        request.headers.set('ngrok-skip-browser-warning', 'true');

        final response = await request.close();
        response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            if (line.trim().isEmpty) return;
            if (line.startsWith('data: ')) {
              try {
                final data = jsonDecode(line.substring(6));
                final n = _parseWSNotification(data);
                addNotification(n);
                
                // Trigger a global alert signal for proximity filtering
                _latestIncoming = n;
                notifyListeners();
              } catch (e) {
                debugPrint('Error parsing notification SSE: $e');
              }
            }
          },
          onDone: () {
            _isConnecting = false;
            Future.delayed(const Duration(seconds: 10), _startNotificationStream);
          },
          onError: (e) {
            _isConnecting = false;
            Future.delayed(const Duration(seconds: 10), _startNotificationStream);
          },
        );
      } catch (e) {
        _isConnecting = false;
        Future.delayed(const Duration(seconds: 15), _startNotificationStream);
      }
    });
  }

  AppNotification _parseWSNotification(Map<String, dynamic> data) {
    final String type = data['type'] ?? 'Alert';
    return AppNotification(
      id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      category: _mapCategory(data['category']),
      title: data['title'] ?? 'Emergency Update',
      desc: data['desc'] ?? 'A new situational report has been logged.',
      time: DateTime.now(),
      icon: _mapIcon(type),
      color: _mapColor(type),
      latitude: data['latitude'] != null ? double.tryParse(data['latitude'].toString()) : null,
      longitude: data['longitude'] != null ? double.tryParse(data['longitude'].toString()) : null,
    );
  }

  AppNotificationType _mapCategory(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'alert': return AppNotificationType.Alert;
      case 'update': return AppNotificationType.Update;
      case 'rescue': return AppNotificationType.Rescue;
      case 'barangay': return AppNotificationType.Barangay;
      case 'proximity': return AppNotificationType.Proximity;
      default: return AppNotificationType.Update;
    }
  }

  IconData _mapIcon(String type) {
    switch (type) {
      case 'Flooding': return Icons.water;
      case 'Fire': return Icons.local_fire_department;
      case 'Rescue Request': return Icons.medical_services_outlined;
      case 'Heavy Rain Warning': return Icons.warning_amber_rounded;
      default: return Icons.notification_important_outlined;
    }
  }

  Color _mapColor(String type) {
    if (type.contains('Fire')) return Colors.red;
    if (type.contains('Flood')) return Colors.blue;
    if (type.contains('Rescue')) return Colors.orange;
    return Colors.red;
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void addNotification(AppNotification n) {
    if (_notifications.any((existing) => existing.id == n.id)) return;
    _notifications.add(n);
    notifyListeners();
  }

  void addDummyData() {
    if (_notifications.isNotEmpty) return;
    addNotification(AppNotification(
        id: 'dummy1',
        type: 'Alert',
        category: AppNotificationType.Alert,
        title: 'Heavy Rain Warning',
        desc: 'Severe flooding expected in Brgy. 630. Evacuate if necessary.',
        time: DateTime.now().subtract(const Duration(minutes: 15)),
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
      ));
    addNotification(AppNotification(
        id: 'dummy2',
        type: 'Update',
        category: AppNotificationType.Update,
        title: 'Evacuation Center Full',
        desc: 'Multi-Purpose Hall has reached maximum capacity.',
        time: DateTime.now().subtract(const Duration(hours: 1)),
        icon: Icons.info_outline,
        color: Colors.orange,
      ));
    notifyListeners();
  }

  void markAllRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }
}
