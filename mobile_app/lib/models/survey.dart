class Survey {
  final String id;
  final String title;
  final bool isActive;
  final bool hasSubmitted;

  Survey({
    required this.id,
    required this.title,
    required this.isActive,
    this.hasSubmitted = false,
  });
}

