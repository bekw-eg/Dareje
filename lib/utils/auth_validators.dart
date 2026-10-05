class AuthValidators {
  static String? login(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Логинді енгізіңіз';
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(text)) {
      return 'Тек латын әріптері, сандар және дефис (-) рұқсат етіледі';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Бұл өрісті толтырыңыз';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Электрондық поштаны енгізіңіз';
    // Проверяем привычный адрес: имя@домен.зона, без пробелов.
    if (!RegExp(
          r'^[a-zA-Z0-9](?:[a-zA-Z0-9._%+-]*[a-zA-Z0-9])?@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
        ).hasMatch(text) ||
        text.split('@').first.contains('..')) {
      return 'Дұрыс пошта мекенжайын енгізіңіз: name@example.com';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Құпия сөзді енгізіңіз';
    if (value.runes.length < 8) {
      return 'Құпия сөз кемінде 8 таңбадан тұруы керек';
    }
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value)) {
      return 'Құпия сөзге әріптер немесе сандар қосыңыз';
    }
    return null;
  }
}
