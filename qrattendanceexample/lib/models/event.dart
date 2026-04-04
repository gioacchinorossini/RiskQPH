import 'dart:convert';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? organizer;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;
  final String? qrCode;
  final String? thumbnail;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.organizer,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
    this.qrCode,
    this.thumbnail,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      startTime: DateTime.parse(json['start_time'] ?? json['startTime']),
      endTime: DateTime.parse(json['end_time'] ?? json['endTime']),
      location: json['location'],
      organizer: json['organizer'],
      createdBy: json['created_by'] ?? json['createdBy'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      qrCode: json['qr_code'] ?? json['qrCode'],
      thumbnail: json['thumbnail'] ?? json['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.toString(),
      'end_time': endTime.toString(),
      'location': location,
      'organizer': organizer,
      'created_by': createdBy,
      'created_at': createdAt.toString(),
      'is_active': isActive,
      'qr_code': qrCode,
      'thumbnail': thumbnail,
    };
  }

  String generateQRCode({required String studentId}) {
    final eventData = {
      'eventId': id,
      'studentId': studentId,
    };
    return base64Encode(utf8.encode(jsonEncode(eventData)));
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? createdBy,
    DateTime? createdAt,
    bool? isActive,
    String? qrCode,
    String? thumbnail,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      qrCode: qrCode ?? this.qrCode,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }
} 