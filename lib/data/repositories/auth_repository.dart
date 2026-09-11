import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/security_util.dart';
import '../../utils/permission_guard.dart';

class AuthRepository {
  final DatabaseHelper dbHelper;

  AuthRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<UserModel?> login(String username, String password) async {
    final db = await dbHelper.database;
    final hashedPassword = SecurityUtil.hashPassword(password);

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username.trim(), hashedPassword],
    );

    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<UserModel>> getUsers() async {
    final db = await dbHelper.database;
    final maps = await db.query('users', orderBy: 'id ASC');
    return maps.map((e) => UserModel.fromMap(e)).toList();
  }

  Future<int> addUser(UserModel user) async {
    final db = await dbHelper.database;
    final secureUser = user.copyWith(
      passwordHash: SecurityUtil.hashPassword(user.passwordHash),
    );
    return await db.insert('users', secureUser.toMap());
  }

  /// Change user's own password with current password verification
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await dbHelper.database;
    final userMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (userMaps.isEmpty) {
      throw Exception('المستخدم غير موجود.');
    }

    final storedHash = userMaps.first['password_hash'] as String;
    if (!SecurityUtil.verifyPassword(currentPassword, storedHash)) {
      throw Exception('كلمة المرور الحالية غير صحيحة.');
    }

    if (newPassword.trim().isEmpty) {
      throw Exception('كلمة المرور الجديدة لا يمكن أن تكون فارغة.');
    }

    if (newPassword.trim().length < 4) {
      throw Exception('كلمة المرور الجديدة يجب ألا تقل عن 4 أحرف.');
    }

    final newHash = SecurityUtil.hashPassword(newPassword);
    await db.update(
      'users',
      {'password_hash': newHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Manager reset password for any user directly without knowing old password
  Future<void> resetUserPasswordByManager({
    required int targetUserId,
    required String newPassword,
    required UserModel? managerUser,
  }) async {
    PermissionGuard.check(managerUser, AppPermission.manageUsers);
    final db = await dbHelper.database;
    final userMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [targetUserId],
    );

    if (userMaps.isEmpty) {
      throw Exception('المستخدم المراد تعديل حسابه غير موجود.');
    }

    if (newPassword.trim().isEmpty) {
      throw Exception('كلمة المرور الجديدة لا يمكن أن تكون فارغة.');
    }

    if (newPassword.trim().length < 4) {
      throw Exception('كلمة المرور الجديدة يجب ألا تقل عن 4 أحرف.');
    }

    final newHash = SecurityUtil.hashPassword(newPassword);
    await db.update(
      'users',
      {'password_hash': newHash},
      where: 'id = ?',
      whereArgs: [targetUserId],
    );
  }
}
