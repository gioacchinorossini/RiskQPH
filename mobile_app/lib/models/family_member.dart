class FamilyMember {
  final String id;
  final String? userId; // Linked registered user ID
  final String headId;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String relationship;
  final DateTime? birthdate;
  final String? gender;
  final String? medicalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyMember({
    required this.id,
    this.userId,
    required this.headId,
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.relationship,
    this.birthdate,
    this.gender,
    this.medicalNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'],
      userId: json['userId'],
      headId: json['headId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      middleName: json['middleName'],
      relationship: json['relationship'] ?? 'Member',
      birthdate: json['birthdate'] != null ? DateTime.parse(json['birthdate']) : null,
      gender: json['gender'],
      medicalNotes: json['medicalNotes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'headId': headId,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'relationship': relationship,
      'birthdate': birthdate?.toIso8601String(),
      'gender': gender,
      'medicalNotes': medicalNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get fullName => '$firstName $lastName';
}
