import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';
import 'package:fuel_station_app_pro/utils/security_util.dart';
import 'package:fuel_station_app_pro/utils/permission_guard.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<DatabaseHelper> createIsolatedDbHelper() async {
    final inMemoryDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
      ),
    );
    return DatabaseHelper.withDatabase(inMemoryDb);
  }

  test('Execution Proof: Change Password, Reject Old, Accept New, and Manager Reset', () async {
    final dbHelper = await createIsolatedDbHelper();
    final authRepo = AuthRepository(dbHelper: dbHelper);
    final db = await dbHelper.database;

    // =========================================================================
    // 1. تسجيل الدخول بكلمة المرور الافتراضية للمحاسب
    // =========================================================================
    print('\n================================================================');
    print('1. تسجيل دخول المحاسب بكلمة المرور الافتراضية (acc123)');
    print('================================================================');
    var accountant = await authRepo.login('accountant', 'acc123');
    expect(accountant, isNotNull);
    expect(accountant!.username, equals('accountant'));
    print('-> تم تسجيل الدخول بنجاح للمستخدم: ${accountant.name}');

    // =========================================================================
    // 2. تجربة تغيير كلمة المرور بكلمة مرور حالية خاطئة (يجب أن تفشل)
    // =========================================================================
    print('\n================================================================');
    print('2. محاولة تغيير كلمة المرور بتمرير كلمة مرور حالية خاطئة');
    print('================================================================');
    expect(
      () => authRepo.changePassword(
        userId: accountant!.id!,
        currentPassword: 'wrong_current_password',
        newPassword: 'MySecurePassword#2026',
      ),
      throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('كلمة المرور الحالية غير صحيحة'))),
    );
    print('-> تم رفض العملية بنجاح بسبب عدم تطابق كلمة المرور الحالية!');

    // =========================================================================
    // 3. تغيير كلمة المرور بالقيم الصحيحة (acc123 -> NewPassword#2026)
    // =========================================================================
    print('\n================================================================');
    print('3. تغيير كلمة المرور رسمياً إلى: NewPassword#2026');
    print('================================================================');
    await authRepo.changePassword(
      userId: accountant.id!,
      currentPassword: 'acc123',
      newPassword: 'NewPassword#2026',
    );
    print('-> تم تحديث كلمة المرور وحفظ الـ Hash الجديد في قاعدة البيانات');

    // التحقق من قاعدة البيانات مباشرة أن التخزين مشفر بـ SHA-256
    final checkMaps = await db.query('users', where: 'id = ?', whereArgs: [accountant.id]);
    final storedHash = checkMaps.first['password_hash'] as String;
    final expectedHash = SecurityUtil.hashPassword('NewPassword#2026');
    expect(storedHash, equals(expectedHash));
    print('-> فحص مباشر لقاعدة البيانات: الـ Hash المخزن هو ($storedHash) مطابق لـ SHA-256');

    // =========================================================================
    // 4. تسجيل الخروج ومحاولة الدخول بكلمة المرور القديمة (يجب أن تُرفض)
    // =========================================================================
    print('\n================================================================');
    print('4. إثبات تنفيذي: محاولة الدخول بكلمة المرور القديمة (acc123)');
    print('================================================================');
    final rejectedLogin = await authRepo.login('accountant', 'acc123');
    expect(rejectedLogin, isNull);
    print('-> 🛑 رُفضت كلمة المرور القديمة تماماً (login returned null)');

    // =========================================================================
    // 5. محاولة الدخول بكلمة المرور الجديدة (يجب أن تنجح)
    // =========================================================================
    print('\n================================================================');
    print('5. إثبات تنفيذي: تسجيل الدخول بكلمة المرور الجديدة (NewPassword#2026)');
    print('================================================================');
    final successLogin = await authRepo.login('accountant', 'NewPassword#2026');
    expect(successLogin, isNotNull);
    expect(successLogin!.id, equals(accountant.id));
    print('-> ✅ نجح تسجيل الدخول بكلمة المرور الجديدة!');

    // =========================================================================
    // 6. المدير يقوم بإعادة تعيين كلمة مرور المحاسب مباشرة (Manager Reset)
    // =========================================================================
    print('\n================================================================');
    print('6. المدير يقوم بإعادة تعيين كلمة مرور المحاسب دون معرفة كلمته السابقة');
    print('================================================================');
    final manager = await authRepo.login('admin', 'admin123');
    expect(manager, isNotNull);
    expect(manager!.isManager, isTrue);

    // تجربة: هل يستطيع المحاسب إعادة تعيين كلمة مرور مستخدم آخر؟ (يجب أن يُرفض)
    expect(
      () => authRepo.resetUserPasswordByManager(
        targetUserId: manager.id!,
        newPassword: 'HackedAdminPass123',
        managerUser: successLogin,
      ),
      throwsA(isA<UnauthorizedException>()),
    );
    print('-> 🛑 تم منع المحاسب من إعادة تعيين كلمة مرور مستخدم آخر (UnauthorizedException)');

    // الآن: المدير العام يعيد تعيين كلمة مرور المحاسب إلى ManagerReset#789
    await authRepo.resetUserPasswordByManager(
      targetUserId: accountant.id!,
      newPassword: 'ManagerReset#789',
      managerUser: manager,
    );
    print('-> قام المدير بإعادة تعيين كلمة مرور المحاسب إلى ManagerReset#789');

    // التأكد أن الكلمة السابقة NewPassword#2026 لم تعد تعمل
    final previousPasswordLogin = await authRepo.login('accountant', 'NewPassword#2026');
    expect(previousPasswordLogin, isNull);
    print('-> 🛑 كلمة المرور السابقة NewPassword#2026 رُفضت');

    // والتأكد أن الكلمة الجديدة التي عينها المدير تعمل بنجاح
    final finalLogin = await authRepo.login('accountant', 'ManagerReset#789');
    expect(finalLogin, isNotNull);
    print('-> ✅ نجح تسجيل الدخول بالكلمة المعينة من قِبل المدير (ManagerReset#789)');
    print('\n================================================================');
    print('✅ جميع سيناريوهات تغيير وإعادة تعيين وحماية كلمات المرور أثبتت نجاحها 100%');
    print('================================================================');
  });
}
