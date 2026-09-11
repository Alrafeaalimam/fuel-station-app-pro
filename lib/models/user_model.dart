import 'package:equatable/equatable.dart';
import '../utils/permission_guard.dart';

class UserModel extends Equatable {
  final int? id;
  final String name;
  final String username;
  final String passwordHash;
  final String role; // 'manager' | 'accountant'

  const UserModel({
    this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.role,
  });

  bool get isManager => role == 'manager';
  bool get isAccountant => role == 'accountant';

  bool can(AppPermission permission) => PermissionGuard.can(this, permission);

  String get roleArabic => isManager ? 'مدير المحطة' : 'محاسب';

  UserModel copyWith({
    int? id,
    String? name,
    String? username,
    String? passwordHash,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'username': username,
      'password_hash': passwordHash,
      'role': role,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      role: map['role'] as String? ?? 'accountant',
    );
  }

  @override
  List<Object?> get props => [id, name, username, passwordHash, role];
}
