import 'achievement.dart';

class ImpactScenario {
  ImpactScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
  }) {
    if (!Achievement.categories.contains(category)) {
      throw ArgumentError.value(category, 'category', 'Unknown category');
    }
  }

  final String id;
  final String title;
  final String description;
  final String category;

  static final examples = List<ImpactScenario>.unmodifiable([
    ImpactScenario(
      id: 'olympiad',
      title: 'Олимпиадаға қатысу',
      description: 'Біліміңізді сынап, оқу дағдыңызды дамытыңыз.',
      category: 'Academic',
    ),
    ImpactScenario(
      id: 'conference',
      title: 'Ғылыми баяндама',
      description: 'Зерттеу нәтижесін студенттік конференцияда таныстырыңыз.',
      category: 'Academic',
    ),
    ImpactScenario(
      id: 'hackathon',
      title: 'Хакатонда жеңу',
      description: 'Код жазып, жұмыс істейтін шешім ұсыныңыз.',
      category: 'Programming',
    ),
    ImpactScenario(
      id: 'coding',
      title: 'Код жарысына қатысу',
      description: 'Алгоритмдік есептерді шешу тәжірибесін жинаңыз.',
      category: 'Programming',
    ),
    ImpactScenario(
      id: 'it-project',
      title: 'IT-жоба жасау',
      description: 'Идеяңызды дайын өнімге айналдырыңыз.',
      category: 'Projects',
    ),
    ImpactScenario(
      id: 'team-project',
      title: 'Топтық жобаны аяқтау',
      description: 'Топпен бірге ортақ нәтижеге жетіңіз.',
      category: 'Projects',
    ),
    ImpactScenario(
      id: 'sport-victory',
      title: 'Спорт жарысында жеңу',
      description: 'Жаттығудың нәтижесін жарыста көрсетіңіз.',
      category: 'Sport',
    ),
    ImpactScenario(
      id: 'tournament',
      title: 'Турнирге қатысу',
      description: 'Спорт пен топтық әрекетті дамытыңыз.',
      category: 'Sport',
    ),
    ImpactScenario(
      id: 'volunteer',
      title: 'Еріктілік қызмет',
      description: 'Қоғамға пайдалы іске үлес қосыңыз.',
      category: 'Volunteering',
    ),
    ImpactScenario(
      id: 'charity',
      title: 'Қайырымдылық шарасы',
      description: 'Көмекті ұйымдастыруға атсалысыңыз.',
      category: 'Volunteering',
    ),
    ImpactScenario(
      id: 'student-event',
      title: 'Студенттік шара',
      description: 'Университет өміріне белсенді қатысыңыз.',
      category: 'Other',
    ),
    ImpactScenario(
      id: 'club',
      title: 'Клуб жұмысына қатысу',
      description: 'Ортақ қызығушылық арқылы бірге жұмыс істеңіз.',
      category: 'Other',
    ),
  ]);

  static String categoryLabel(String category) => switch (category) {
    'Academic' => 'Оқу',
    'Programming' => 'Бағдарламалау',
    'Projects' => 'Жобалар',
    'Sport' => 'Спорт',
    'Volunteering' => 'Еріктілік',
    _ => 'Басқа',
  };
}
