class StudentIndicator {
  StudentIndicator({required this.name, required this.value}) {
    RangeError.checkValueInInterval(value, 0, 100, 'value');
  }

  final String name;
  final int value;
}
