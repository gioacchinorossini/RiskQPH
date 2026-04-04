import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/survey.dart';

class SurveyProvider extends ChangeNotifier {
  final Map<String, List<Survey>> _eventIdToSurveys = {};
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _statsCache = {}; // surveyId -> stats json
  Map<String, List<Map<String, dynamic>>> _responsesCache = {}; // surveyId -> responses

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Survey> surveysForEvent(String eventId) => _eventIdToSurveys[eventId] ?? const [];
  Map<String, dynamic>? statsForSurvey(String surveyId) => _statsCache[surveyId];
  List<Map<String, dynamic>> responsesForSurvey(String surveyId) => _responsesCache[surveyId] ?? const [];

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<bool> createSurvey({
    required String eventId,
    required String title,
    String? description,
    required String createdBy,
    required List<SurveyQuestion> questions,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/surveys/create.php');
      final body = {
        'event_id': eventId,
        'title': title,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        'created_by': createdBy,
        'questions': questions.map((q) => q.toPayloadJson()).toList(),
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final created = Survey.fromJson(data['survey'] as Map<String, dynamic>);
        final list = List<Survey>.from(_eventIdToSurveys[eventId] ?? const []);
        list.insert(0, created);
        _eventIdToSurveys[eventId] = list;
        _setLoading(false);
        return true;
      }

      String message = 'Failed to create survey';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['message'] is String) message = data['message'];
      } catch (_) {}
      _setError(message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to create survey: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadSurveysForEvent(String eventId, {String? userId}) async {
    try {
      _setLoading(true);
      _setError(null);
      final qp = 'event_id=' + Uri.encodeQueryComponent(eventId) + (userId != null && userId.isNotEmpty ? ('&user_id=' + Uri.encodeQueryComponent(userId)) : '');
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/surveys/list_by_event.php?' + qp);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['surveys'] ?? [];
        _eventIdToSurveys[eventId] = list.map((e) => Survey.fromJson(e as Map<String, dynamic>)).toList();
        _setLoading(false);
      } else {
        _setError('Failed to load surveys');
        _setLoading(false);
      }
    } catch (e) {
      _setError('Failed to load surveys: $e');
      _setLoading(false);
    }
  }

  Future<Survey?> fetchSurveyDetails({required String surveyId, String? userId}) async {
    try {
      _setLoading(true);
      _setError(null);
      final params = {
        'survey_id': surveyId,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
      };
      final qp = params.entries.map((e) => e.key + '=' + Uri.encodeQueryComponent(e.value)).join('&');
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/surveys/details.php?' + qp);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final surveyJson = data['survey'] as Map<String, dynamic>;
        final survey = Survey.fromJson(surveyJson);
        final list = List<Survey>.from(_eventIdToSurveys[survey.eventId] ?? const []);
        final idx = list.indexWhere((s) => s.id == survey.id);
        if (idx >= 0) {
          list[idx] = survey;
          _eventIdToSurveys[survey.eventId] = list;
        }
        _setLoading(false);
        return survey;
      }
      _setError('Failed to load survey');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to load survey: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> submitSurveyResponses({
    required String surveyId,
    required String userId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/surveys/submit.php');
      final body = {
        'survey_id': surveyId,
        'user_id': userId,
        'answers': answers,
      };
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        _setLoading(false);
        return true;
      }
      _setError('Failed to submit survey');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to submit survey: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchStats(String surveyId) async {
    try {
      _setLoading(true);
      _setError(null);
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/surveys/stats.php?survey_id=' + Uri.encodeQueryComponent(surveyId));
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _statsCache[surveyId] = data;
        _setLoading(false);
        return data;
      }
      _setError('Failed to load stats');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to load stats: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchResponses(String surveyId) async {
    try {
      _setLoading(true);
      _setError(null);
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/surveys/responses.php?survey_id=' + Uri.encodeQueryComponent(surveyId));
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = data['responses'] ?? [];
        _responsesCache[surveyId] = list.map((e) => e as Map<String, dynamic>).toList();
        _setLoading(false);
        return _responsesCache[surveyId]!;
      }
      _setError('Failed to load responses');
      _setLoading(false);
      return null;
    } catch (e) {
      _setError('Failed to load responses: $e');
      _setLoading(false);
      return null;
    }
  }
}

