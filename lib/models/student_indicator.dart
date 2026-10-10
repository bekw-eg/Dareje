enum StudentIndicatorType {
  academic,
  programming,
  projects,
  teamwork,
  sport,
  volunteering,
}

class StudentIndicator {
  StudentIndicator({
    required this.type,
    required this.name,
    required this.value,
  }) {
    RangeError.checkValueInInterval(value, 0, 100, 'value');
  }

  final StudentIndicatorType type;
  final String name;
  final int value;
}
