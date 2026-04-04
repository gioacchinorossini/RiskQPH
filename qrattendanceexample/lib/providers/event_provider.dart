import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/event.dart';
import '../config/api_config.dart';

class EventProvider extends ChangeNotifier {
  List<Event> _events = [];
  bool _isLoading = false;
  String? _error;
  static const String _eventsCacheKey = 'cached_events_v1';
  Stream<List<ConnectivityResult>>? _connectivityStream;
  DateTime? _lastSuccessfulSync;

  // Memoization cache
  List<Event>? _cachedActiveEvents;
  List<Event>? _cachedUpcomingEvents;
  DateTime? _cachedUpcomingEventsTime;
  List<Event>? _cachedPastEvents;
  DateTime? _cachedPastEventsTime;
  List<Event>? _cachedCurrentEvents;
  DateTime? _cachedCurrentEventsTime;
  List<Event>? _cachedStudentVisibleEvents;
  DateTime? _cachedStudentVisibleEventsTime;
  
  // Cache TTL for time-sensitive queries (30 seconds)
  static const Duration _timeSensitiveCacheTTL = Duration(seconds: 30);

  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Invalidate all memoized caches
  void _invalidateMemoCache() {
    _cachedActiveEvents = null;
    _cachedUpcomingEvents = null;
    _cachedUpcomingEventsTime = null;
    _cachedPastEvents = null;
    _cachedPastEventsTime = null;
    _cachedCurrentEvents = null;
    _cachedCurrentEventsTime = null;
    _cachedStudentVisibleEvents = null;
    _cachedStudentVisibleEventsTime = null;
  }

  Future<void> loadEvents({bool offlineMode = false}) async {
    setLoading(true);
    setError(null);

    // If in offline mode, load from cache first
    if (offlineMode) {
      final cached = await _loadEventsFromStorage();
      if (cached != null) {
        _events = cached;
        setLoading(false);
        return;
      } else {
        setError('No cached events available');
        setLoading(false);
        return;
      }
    }

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/events/list.php');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['events'] ?? [];
        _events = list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
        await _saveEventsToStorage(_events);
        _invalidateMemoCache();
        setLoading(false);
      } else {
        final cached = await _loadEventsFromStorage();
        if (cached != null) {
          _events = cached;
          _invalidateMemoCache();
          setLoading(false);
        } else {
          setError('Failed to load events');
          setLoading(false);
        }
      }
    } catch (e) {
      final cached = await _loadEventsFromStorage();
      if (cached != null) {
        _events = cached;
        _invalidateMemoCache();
        setLoading(false);
      } else {
        setError('Failed to load events: $e');
        setLoading(false);
      }
    }
  }

  /// Load events directly from cache without attempting server request
  Future<void> loadEventsFromCache() async {
    setLoading(true);
    setError(null);

    final cached = await _loadEventsFromStorage();
    if (cached != null) {
      _events = cached;
      _invalidateMemoCache();
      setLoading(false);
    } else {
      setError('No cached events available');
      setLoading(false);
    }
  }

  Future<void> refreshEventsSilently() async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/events/list.php');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['events'] ?? [];
        _events = list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
        await _saveEventsToStorage(_events);
        _invalidateMemoCache();
        _lastSuccessfulSync = DateTime.now();
        notifyListeners();
      }
    } catch (_) {
      // silent fail
    }
  }

  void startConnectivityMonitoring() {
    _connectivityStream ??= Connectivity().onConnectivityChanged;
    _connectivityStream!.listen((results) async {
      final latest = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final isOnline = latest != ConnectivityResult.none;
      if (isOnline) {
        // Avoid spamming: refresh at most every 60s
        final now = DateTime.now();
        if (_lastSuccessfulSync == null || now.difference(_lastSuccessfulSync!).inSeconds > 60) {
          await refreshEventsSilently();
        }
      }
    });
  }

  Future<bool> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    String? organizer,
    required String createdBy,
  }) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/events/create.php');
      final body = {
        'title': title,
        'description': description,
        'start_time': startTime.toString(),
        'end_time': endTime.toString(),
        'location': location,
        'created_by': createdBy,
      };
      if (organizer != null && organizer.trim().isNotEmpty) {
        body['organizer'] = organizer.trim();
      }
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final eventJson = data['event'] as Map<String, dynamic>;
        final created = Event.fromJson(eventJson);
        _events.add(created);
        await _saveEventsToStorage(_events);
        _invalidateMemoCache();
        setLoading(false);
        return true;
      }

      String message = 'Failed to create event';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['message'] is String) message = data['message'];
      } catch (_) {}
      setError(message);
      setLoading(false);
      return false;
    } catch (e) {
      setError('Failed to create event: $e');
      setLoading(false);
      return false;
    }
  }

  Future<bool> updateEvent(Event event) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/events/update.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(event.toJson()),
      );

      if (response.statusCode == 200) {
        final index = _events.indexWhere((e) => e.id == event.id);
        if (index != -1) {
          _events[index] = event;
        }
        await _saveEventsToStorage(_events);
        _invalidateMemoCache();
        setLoading(false);
        return true;
      }

      setError('Failed to update event');
      setLoading(false);
      return false;
    } catch (e) {
      setError('Failed to update event: $e');
      setLoading(false);
      return false;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/events/delete.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': eventId}),
      );

      if (response.statusCode == 200) {
        _events.removeWhere((event) => event.id == eventId);
        await _saveEventsToStorage(_events);
        _invalidateMemoCache();
        setLoading(false);
        return true;
      }

      setError('Failed to delete event');
      setLoading(false);
      return false;
    } catch (e) {
      setError('Failed to delete event: $e');
      setLoading(false);
      return false;
    }
  }

  Future<void> _saveEventsToStorage(List<Event> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = events.map((e) => e.toJson()).toList();
      await prefs.setString(_eventsCacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<Event>?> _loadEventsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_eventsCacheKey);
      if (raw == null) return null;
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Event? getEventById(String eventId) {
    try {
      return _events.firstWhere((event) => event.id == eventId);
    } catch (e) {
      return null;
    }
  }

  List<Event> getActiveEvents() {
    if (_cachedActiveEvents != null) {
      return _cachedActiveEvents!;
    }
    final list = _events.where((event) => event.isActive).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cachedActiveEvents = list;
    return list;
  }

  List<Event> getUpcomingEvents() {
    final now = DateTime.now();
    if (_cachedUpcomingEvents != null && 
        _cachedUpcomingEventsTime != null &&
        now.difference(_cachedUpcomingEventsTime!) < _timeSensitiveCacheTTL) {
      return _cachedUpcomingEvents!;
    }
    final list = _events.where((event) =>
      event.isActive && 
      (event.startTime.isAfter(now) || 
       (event.startTime.isBefore(now) && event.endTime.isAfter(now)))
    ).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by latest created first
    _cachedUpcomingEvents = list;
    _cachedUpcomingEventsTime = now;
    return list;
  }

  List<Event> getPastEvents() {
    final now = DateTime.now();
    if (_cachedPastEvents != null && 
        _cachedPastEventsTime != null &&
        now.difference(_cachedPastEventsTime!) < _timeSensitiveCacheTTL) {
      return _cachedPastEvents!;
    }
    final list = _events.where((event) =>
      event.endTime.isBefore(now)
    ).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by latest created first
    _cachedPastEvents = list;
    _cachedPastEventsTime = now;
    return list;
  }

  List<Event> getCurrentEvents() {
    final now = DateTime.now();
    if (_cachedCurrentEvents != null && 
        _cachedCurrentEventsTime != null &&
        now.difference(_cachedCurrentEventsTime!) < _timeSensitiveCacheTTL) {
      return _cachedCurrentEvents!;
    }
    final list = _events.where((event) =>
      event.isActive && 
      event.startTime.isBefore(now) && 
      event.endTime.isAfter(now)
    ).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by latest created first
    _cachedCurrentEvents = list;
    _cachedCurrentEventsTime = now;
    return list;
  }

  /// Get events that students should see (upcoming + currently ongoing)
  List<Event> getStudentVisibleEvents() {
    final now = DateTime.now();
    if (_cachedStudentVisibleEvents != null && 
        _cachedStudentVisibleEventsTime != null &&
        now.difference(_cachedStudentVisibleEventsTime!) < _timeSensitiveCacheTTL) {
      return _cachedStudentVisibleEvents!;
    }
    final list = _events.where((event) =>
      event.isActive && 
      (event.startTime.isAfter(now) || 
       (event.startTime.isBefore(now) && event.endTime.isAfter(now)))
    ).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by latest created first
    _cachedStudentVisibleEvents = list;
    _cachedStudentVisibleEventsTime = now;
    return list;
  }
} 