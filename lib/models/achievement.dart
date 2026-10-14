import 'dart:math';

class Achievement {
  Achievement({
    String? id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
  }) : id = id ?? createId();

  const Achievement._({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
  });

  static String createId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static const categories = [
    'Academic',
    'Programming',
    'Projects',
    'Sport',
    'Volunteering',
    'Other',
  ];

  // Старый JSON может быть без ID; хранилище назначает устойчивый ID при чтении.
  final String? id;
  final String title;
  final String description;
  final String category;
  final DateTime date;

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    DateTime? date,
  }) => Achievement._(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    date: date ?? this.date,
  );

  bool hasSameContent(Achievement other) =>
      title == other.title &&
      description == other.description &&
      category == other.category &&
      date == other.date;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement._(
    id: json['id'] as String?,
    title: json['title'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    date: DateTime.parse(json['date'] as String),
  );

  Map<String, String> toJson() => {
    if (id != null) 'id': id!,
    'title': title,
    'description': description,
    'category': category,
    'date': date.toIso8601String(),
  };
}
