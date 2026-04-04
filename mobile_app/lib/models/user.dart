enum UserRole { student, admin, officer }

class User {
  final String id;
  final String name;
  final String email;
  final String studentId;
  final String yearLevel;
  final String department;
  final String course;
  final String gender;
  final DateTime? birthdate;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.studentId,
    required this.yearLevel,
    required this.department,
    required this.course,
    required this.gender,
    this.birthdate,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      studentId: json['studentId'] ?? '',
      yearLevel: json['yearLevel'] ?? '',
      department: json['department'] ?? '',
      course: json['course'] ?? '',
      gender: json['gender'] ?? '',
      birthdate: json['birthdate'] != null && (json['birthdate'] as String).isNotEmpty
          ? DateTime.parse(json['birthdate'])
          : null,
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == json['role'],
        orElse: () => UserRole.student,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'studentId': studentId,
      'yearLevel': yearLevel,
      'department': department,
      'course': course,
      'gender': gender,
      'birthdate': birthdate?.toIso8601String().substring(0, 10),
      'role': role.toString().split('.').last,
      'createdAt': createdAt.toString(),
      'updatedAt': updatedAt.toString(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? studentId,
    String? yearLevel,
    String? department,
    String? course,
    String? gender,
    DateTime? birthdate,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      yearLevel: yearLevel ?? this.yearLevel,
      department: department ?? this.department,
      course: course ?? this.course,
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

