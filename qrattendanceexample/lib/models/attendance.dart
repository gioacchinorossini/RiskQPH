class Attendance {
  final String id;
  final String eventId;
  final String studentId;
  final String studentName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String status; // 'present', 'late', 'absent'
  final String? notes;

  Attendance({
    required this.id,
    required this.eventId,
    required this.studentId,
    required this.studentName,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.notes,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      eventId: json['eventId'],
      studentId: json['studentId'],
      studentName: json['studentName'],
      checkInTime: DateTime.parse(json['checkInTime']),
      checkOutTime: json['checkOutTime'] != null 
          ? DateTime.parse(json['checkOutTime']) 
          : null,
      status: json['status'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'studentId': studentId,
      'studentName': studentName,
      'checkInTime': checkInTime.toString(),
      'checkOutTime': checkOutTime?.toString(),
      'status': status,
      'notes': notes,
    };
  }

  Attendance copyWith({
    String? id,
    String? eventId,
    String? studentId,
    String? studentName,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? status,
    String? notes,
  }) {
    return Attendance(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
} 