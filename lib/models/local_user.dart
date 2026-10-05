class LocalUser {
  const LocalUser({
    required this.login,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.passwordHash,
    required this.salt,
  });

  final String login;
  final String firstName;
  final String lastName;
  final String email;
  final String passwordHash;
  final String salt;

  factory LocalUser.fromJson(Map<String, dynamic> json) => LocalUser(
    login: json['login'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    passwordHash: json['passwordHash'] as String,
    salt: json['salt'] as String,
  );

  Map<String, String> toJson() => {
    'login': login,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'passwordHash': passwordHash,
    'salt': salt,
  };
}
