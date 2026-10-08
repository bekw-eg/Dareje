class Achievement {
  const Achievement({
    required this.title,
    required this.description,
    required this.category,
    required this.date,
  });

  static const categories = [
    'Academic',
    'Programming',
    'Projects',
    'Sport',
    'Volunteering',
    'Other',
  ];

  final String title;
  final String description;
  final String category;
  final DateTime date;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    title: json['title'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    date: DateTime.parse(json['date'] as String),
  );

  Map<String, String> toJson() => {
    'title': title,
    'description': description,
    'category': category,
    'date': date.toIso8601String(),
  };
}
