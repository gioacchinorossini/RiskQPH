import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
// Removed unused imports
import '../config/api_config.dart';

class AttendanceProvider extends ChangeNotifier {
  List<Attendance> _attendances = [];
  bool _isLoading = false;
  String? _error;
  static const String _attCacheKey = 'cached_attendances_v1';

  List<Attendance> get attendances => _attendances;
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

  Future<void> loadAttendances() async {
    setLoading(true);
    setError(null);

    try {
      // Try backend recent list; fall back to cache
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/attendance/list_recent.php?limit=200');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['attendances'] ?? [];
        _attendances = list.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
        await _saveAttendancesToStorage(_attendances);
        setLoading(false);
      } else {
        final cached = await _loadAttendancesFromStorage();
        _attendances = cached ?? [];
        setLoading(false);
      }
    } catch (e) {
      setError('Failed to load attendances: $e');
      setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> markAttendance({
    required String eventId,
    required String studentId,
    required String studentName,
    required String qrCodeData,
  }) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/attendance/mark.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'qrCodeData': qrCodeData,
          'eventId': int.tryParse(eventId) ?? eventId,
          'studentId': int.tryParse(studentId) ?? studentId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final att = Attendance.fromJson(data['attendance'] as Map<String, dynamic>);
        final action = data['action'] as String? ?? 'check_in';
        
        // Update existing attendance or add new one
        final existingIndex = _attendances.indexWhere((a) => a.id == att.id);
        if (existingIndex != -1) {
          _attendances[existingIndex] = att;
        } else {
          _attendances.add(att);
        }
        
        await _saveAttendancesToStorage(_attendances);
        setLoading(false);
        
        return {
          'success': true,
          'action': action,
          'attendance': att,
        };
      }

      String message = 'Failed to mark attendance';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['message'] is String) message = data['message'];
      } catch (_) {}
      setError(message);
      setLoading(false);
      return null;
    } catch (e) {
      setError('Failed to mark attendance: $e');
      setLoading(false);
      return null;
    }
  }

  // Validation moved to backend

  List<Attendance> getAttendancesByEvent(String eventId) {
    return _attendances.where((a) => a.eventId == eventId).toList();
  }

  List<Attendance> getAttendancesByStudent(String studentId) {
    return _attendances.where((a) => a.studentId == studentId).toList();
  }

  Attendance? getAttendanceByEventAndStudent(String eventId, String studentId) {
    try {
      return _attendances.firstWhere((a) => 
        a.eventId == eventId && a.studentId == studentId
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateAttendance(Attendance attendance) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/attendance/update.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': attendance.id,
          'status': attendance.status,
          'notes': attendance.notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        if (data['success'] == true) {
          // Update local state
          final index = _attendances.indexWhere((a) => a.id == attendance.id);
          if (index != -1) {
            _attendances[index] = attendance;
            await _saveAttendancesToStorage(_attendances);
            notifyListeners();
          }
          
          setLoading(false);
          return true;
        } else {
          setError(data['error'] ?? 'Failed to update attendance');
          setLoading(false);
          return false;
        }
      } else {
        setError('Server error: ${response.statusCode}');
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('Failed to update attendance: $e');
      setLoading(false);
      return false;
    }
  }

  int getAttendanceCountForEvent(String eventId) {
    return _attendances.where((a) => a.eventId == eventId).length;
  }

  Future<List<Attendance>> loadAttendancesByEvent(String eventId) async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/attendance/list_by_event.php?eventId=$eventId');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['attendances'] ?? [];
        return list.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    // fallback to local filtered
    return getAttendancesByEvent(eventId);
  }

  Map<String, int> getAttendanceStatsForEvent(String eventId) {
    final eventAttendances = _attendances.where((a) => a.eventId == eventId);
    
    int present = 0;
    int late = 0;
    int absent = 0;
    int leftEarly = 0;

    for (final attendance in eventAttendances) {
      switch (attendance.status) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'absent':
          absent++;
          break;
        case 'left_early':
          leftEarly++;
          break;
      }
    }

    return {
      'present': present,
      'late': late,
      'absent': absent,
      'left_early': leftEarly,
    };
  }

  // Fetch aggregated counts per department for an event (backend aggregation)
  Future<List<Map<String, dynamic>>> fetchDepartmentCounts(String eventId) async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/attendance/department_counts.php?eventId=$eventId');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['data'] ?? [];
        return list
            .map((raw) {
              final map = raw as Map<String, dynamic>;
              final dep = map['department'] ?? 'Unknown';
              final att = map['attended'];
              final attended = att is int ? att : int.tryParse('$att') ?? 0;
              return {
                'department': '$dep',
                'attended': attended,
              };
            })
            .toList();
      }
    } catch (e) {
      // ignore and fall back below
    }
    // Fallback: derive from loaded attendances if API unavailable
    final Map<String, int> counts = {};
    for (final _ in _attendances.where((x) => x.eventId == eventId && x.status != 'absent')) {
      // Department info not present in Attendance model; cannot derive reliably without user join
      // Mark as Unknown for fallback visualization
      counts['Unknown'] = (counts['Unknown'] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => {'department': e.key, 'attended': e.value})
        .toList();
  }

  // Get current attendance status for a student at an event
  String getCurrentAttendanceStatus(String eventId, String studentId) {
    final attendance = getAttendanceByEventAndStudent(eventId, studentId);
    if (attendance == null) return 'not_checked_in';
    if (attendance.checkOutTime != null) return 'checked_out';
    return 'checked_in';
  }

  // Refresh attendance data from server for a specific event
  Future<void> refreshAttendanceForEvent(String eventId) async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/attendance/list_by_event.php?eventId=$eventId');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['attendances'] ?? [];
        final freshAttendances = list.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
        
        // Remove old attendances for this event and add fresh ones
        _attendances.removeWhere((a) => a.eventId == eventId);
        _attendances.addAll(freshAttendances);
        
        // Update cache
        await _saveAttendancesToStorage(_attendances);
        notifyListeners();
      }
    } catch (e) {
      print('Failed to refresh attendance for event $eventId: $e');
    }
  }

  // Get current attendance status with server refresh
  Future<String> getCurrentAttendanceStatusWithRefresh(String eventId, String studentId) async {
    // First refresh attendance data from server
    await refreshAttendanceForEvent(eventId);
    
    // Then check the current status
    return getCurrentAttendanceStatus(eventId, studentId);
  }

  Future<void> _saveAttendancesToStorage(List<Attendance> attendances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = attendances.map((a) => a.toJson()).toList();
      await prefs.setString(_attCacheKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<Attendance>?> _loadAttendancesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_attCacheKey);
      if (raw == null) return null;
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }
} 