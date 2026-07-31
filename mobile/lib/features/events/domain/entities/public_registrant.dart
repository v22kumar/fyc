class PublicRegistrant {
  final String name;
  final int? age;
  final String? classGrade;

  PublicRegistrant({
    required this.name,
    this.age,
    this.classGrade,
  });

  factory PublicRegistrant.fromJson(Map<String, dynamic> json) {
    return PublicRegistrant(
      name: json['name'] as String? ?? 'Unknown',
      age: json['age'] as int?,
      classGrade: json['class_grade'] as String?,
    );
  }
}
