enum UserRole { student, admin, officer, resident, barangay_head, responder }

class User {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String email;
  final String? barangay;
  /// verified | pending | rejected
  final String barangayMemberStatus;
  final String? address;
  final String? studentId;
  final String? yearLevel;
  final String? department;
  final String? course;
  final String? gender;
  final DateTime? birthdate;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => '${firstName ?? ""} ${lastName ?? ""}'.trim();

  User({
    required this.id,
    this.firstName,
    this.lastName,
    this.middleName,
    required this.email,
    this.barangay,
    this.barangayMemberStatus = 'verified',
    this.address,
    this.studentId,
    this.yearLevel,
    this.department,
    this.course,
    this.gender,
    this.birthdate,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      middleName: json['middleName'],
      email: json['email'],
      barangay: json['barangay'],
      barangayMemberStatus: json['barangayMemberStatus'] as String? ?? 'verified',
      address: json['address'],
      studentId: json['studentId'],
      yearLevel: json['yearLevel'],
      department: json['department'],
      course: json['course'],
      gender: json['gender'],
      birthdate: json['birthdate'] != null && (json['birthdate'] as String).isNotEmpty
          ? DateTime.parse(json['birthdate'])
          : null,
      role: UserRole.values.firstWhere(
        (role) => role.toString().split('.').last == json['role'],
        orElse: () => UserRole.resident,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'email': email,
      'barangay': barangay,
      'barangayMemberStatus': barangayMemberStatus,
      'address': address,
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
    String? firstName,
    String? lastName,
    String? middleName,
    String? email,
    String? barangay,
    String? barangayMemberStatus,
    String? address,
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
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      email: email ?? this.email,
      barangay: barangay ?? this.barangay,
      barangayMemberStatus: barangayMemberStatus ?? this.barangayMemberStatus,
      address: address ?? this.address,
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

