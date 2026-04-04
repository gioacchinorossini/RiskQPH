class SurveyOption {
  final String? id; // present when loaded from backend details
  final String text;

  SurveyOption({this.id, required this.text});

  factory SurveyOption.fromJson(dynamic json) {
    if (json is String) return SurveyOption(text: json);
    return SurveyOption(
      id: json['id']?.toString(),
      text: json['option_text'] ?? json['text'] ?? '',
    );
  }

  dynamic toJson() => text;
}

class SurveyQuestion {
  final String? id;
  final String? surveyId;
  final String text;
  final String type; // single_choice, multiple_choice, text
  final List<SurveyOption> options;
  final int sortOrder;

  SurveyQuestion({
    this.id,
    this.surveyId,
    required this.text,
    this.type = 'single_choice',
    this.options = const [],
    this.sortOrder = 0,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawOptions = json['options'] ?? [];
    return SurveyQuestion(
      id: json['id']?.toString(),
      surveyId: json['survey_id']?.toString(),
      text: json['question_text'] ?? json['text'] ?? '',
      type: json['question_type'] ?? json['type'] ?? 'single_choice',
      options: rawOptions.map((o) => SurveyOption.fromJson(o)).toList(),
      sortOrder: json['sort_order'] is int ? json['sort_order'] : int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toPayloadJson() {
    return {
      'text': text,
      'type': type,
      if (type != 'text') 'options': options.map((o) => o.toJson()).toList(),
    };
  }

  SurveyQuestion copyWith({
    String? id,
    String? surveyId,
    String? text,
    String? type,
    List<SurveyOption>? options,
    int? sortOrder,
  }) {
    return SurveyQuestion(
      id: id ?? this.id,
      surveyId: surveyId ?? this.surveyId,
      text: text ?? this.text,
      type: type ?? this.type,
      options: options ?? this.options,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class Survey {
  final String id;
  final String eventId;
  final String title;
  final String? description;
  final bool isActive;
  final String createdBy;
  final DateTime? createdAt;
  final List<SurveyQuestion> questions;
  final bool hasSubmitted;

  Survey({
    required this.id,
    required this.eventId,
    required this.title,
    this.description,
    this.isActive = true,
    required this.createdBy,
    this.createdAt,
    this.questions = const [],
    this.hasSubmitted = false,
  });

  factory Survey.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawQuestions = json['questions'] ?? [];
    return Survey(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      questions: rawQuestions.map((q) => SurveyQuestion.fromJson(q as Map<String, dynamic>)).toList(),
      hasSubmitted: json['has_submitted'] ?? json['hasSubmitted'] ?? false,
    );
  }
}

