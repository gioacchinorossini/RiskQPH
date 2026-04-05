import 'package:flutter/material.dart';

class TakeSurveyScreen extends StatelessWidget {
  final String surveyId;
  final String eventTitle;
  const TakeSurveyScreen({super.key, required this.surveyId, required this.eventTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Survey: $eventTitle')),
      body: Center(child: Text('Survey form placeholder ($surveyId)')),
    );
  }
}

