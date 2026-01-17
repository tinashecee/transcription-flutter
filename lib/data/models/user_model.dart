import '../../domain/entities/user.dart';

class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
  });

  final String id;
  final String name;
  final String role;
  final String email;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  User toEntity() => User(id: id, name: name, role: role, email: email);
}
