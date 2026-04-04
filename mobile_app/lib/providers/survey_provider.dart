import 'package:flutter/material.dart';
import '../models/survey.dart';

class SurveyProvider extends ChangeNotifier {
  final Map<String, List<Survey>> _eventIdToSurveys = {};

  Future<void> loadSurveysForEvent(String eventId, {String? userId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _eventIdToSurveys[eventId] = _eventIdToSurveys[eventId] ??
        [
          Survey(id: 's1', title: 'Feedback', isActive: true, hasSubmitted: false),
        ];
    notifyListeners();
  }

  List<Survey> surveysForEvent(String eventId) {
    return _eventIdToSurveys[eventId] ?? const [];
  }
}

