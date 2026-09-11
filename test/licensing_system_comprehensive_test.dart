import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/services/license_service.dart';
import 'package:fuel_station_app_pro/screens/license/license_screen.dart';
import 'package:fuel_station_app_pro/main.dart';
import 'package:fuel_station_app_pro/config/station_config.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Executive Proof: Comprehensive Licensing & Trial System', () {
    late Directory tempDir;
    late String dbFilePath;
    late DatabaseHelper dbHelper;
    late Database testDb;

    setUp(() async {
      LicenseService.setMockRawDeviceId(null);
      LicenseService.setMockNow(null);

      tempDir = Directory.systemTemp.createTempSync('fuel_licensing_test_');
      dbFilePath = p.join(tempDir.path, 'fuel_station_pro.db');

      testDb = await databaseFactoryFfi.openDatabase(
        dbFilePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
        ),
      );

      dbHelper = DatabaseHelper.withDatabase(testDb, dbPath: dbFilePath);
    });

    tearDown(() async {
      LicenseService.setMockRawDeviceId(null);
      LicenseService.setMockNow(null);
      await testDb.close();
      await dbHelper.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('1. First run on pristine DB sets 7 days trial and records first_run_date in DB', () async {
      print('\n================================================================');
      print('الإثبات 1: أول تشغيل للتطبيق واحتساب 7 أيام تجريبية في قاعدة البيانات');
      print('================================================================');

      final baseNow = DateTime(2026, 9, 11, 10, 0, 0);
      LicenseService.setMockNow(baseNow);
      LicenseService.setMockRawDeviceId('DEVICE_TEST_HARDWARE_001');

      final info = await LicenseService.checkLicenseStatus(customDb: testDb);

      print('-> كود الجهاز المولد: ${info.deviceCode}');
      print('-> حالة الترخيص: ${info.status}');
      print('-> الأيام المتبقية: ${info.daysRemaining} أيام');
      print('-> تاريخ أول تشغيل المسجل: ${info.firstRunDate}');

      expect(info.status, equals(LicenseStatus.trial));
      expect(info.daysRemaining, equals(7));
      expect(info.isOperational, isTrue);

      // Verify records in SQLite settings table directly
      final rows = await testDb.query('settings', where: 'key LIKE ?', whereArgs: ['license_%']);
      final map = {for (var r in rows) r['key'].toString(): r['value'].toString()};

      print('-> سجلات جدول settings في قاعدة البيانات: $map');
      expect(map['license_first_run_date'], isNotNull);
      expect(map['license_last_seen_date'], isNotNull);
      expect(map['license_clock_tampered'], isNull);
      expect(map['license_activation_key'], isNull);
    });

    test('2. Clock Rollback Protection terminates trial immediately on time tamper', () async {
      print('\n================================================================');
      print('الإثبات 2: كشف التلاعب بالساعة (Clock Rollback) وإنهاء الفترة فوراً');
      print('================================================================');

      final baseNow = DateTime(2026, 9, 11, 10, 0, 0);
      LicenseService.setMockNow(baseNow);
      LicenseService.setMockRawDeviceId('DEVICE_TEST_HARDWARE_001');

      // 1. Initial run
      await LicenseService.checkLicenseStatus(customDb: testDb);

      // 2. Simulate user advancing system clock to 2026-09-14 and running app
      final advancedDate = DateTime(2026, 9, 14, 12, 0, 0);
      LicenseService.setMockNow(advancedDate);
      await LicenseService.checkLicenseStatus(customDb: testDb);

      // 3. User attempts to cheat by setting system clock back to 2026-09-11
      print('-> محاولة المستخدم إرجاع تاريخ النظام للخلف إلى: $baseNow');
      LicenseService.setMockNow(baseNow);
      final tamperedInfo = await LicenseService.checkLicenseStatus(customDb: testDb);

      print('-> نتيجة الفحص: حالة الترخيص: ${tamperedInfo.status}');
      print('-> رسالة المنع: ${tamperedInfo.errorMessage}');
      print('-> هل التطبيق متاح للتشغيل: ${tamperedInfo.isOperational}');

      expect(tamperedInfo.status, equals(LicenseStatus.tampered));
      expect(tamperedInfo.daysRemaining, equals(0));
      expect(tamperedInfo.isOperational, isFalse);

      // Verify clock_tampered flag is saved permanently in DB
      final flagRows = await testDb.query('settings', where: 'key = ?', whereArgs: ['license_clock_tampered']);
      expect(flagRows.first['value'], equals('1'));
      print('✅ تم تأكيد تسجيل محاولة التلاعب وقفل التطبيق بصورة قطعية.');
    });

    test('3. Simulated 8 days elapsed marks trial as expired and locks the app', () async {
      print('\n================================================================');
      print('الإثبات 3: محاكاة مرور 8 أيام في قاعدة البيانات وقفل التطبيق بالكامل');
      print('================================================================');

      final now = DateTime(2026, 9, 11, 10, 0, 0);
      LicenseService.setMockNow(now);
      LicenseService.setMockRawDeviceId('DEVICE_TEST_HARDWARE_001');

      // Initialize DB with first_run_date 8 days in past (without tampering clock)
      final pastDate = now.subtract(const Duration(days: 8));
      await testDb.insert(
        'settings',
        {'key': 'license_first_run_date', 'value': pastDate.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await testDb.insert(
        'settings',
        {'key': 'license_last_seen_date', 'value': now.subtract(const Duration(hours: 1)).toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final expiredInfo = await LicenseService.checkLicenseStatus(customDb: testDb);

      print('-> تاريخ أول تشغيل المحاكى: $pastDate (قبل 8 أيام)');
      print('-> حالة الترخيص الحالية: ${expiredInfo.status}');
      print('-> الأيام المتبقية: ${expiredInfo.daysRemaining}');
      print('-> هل التطبيق متاح للعمل: ${expiredInfo.isOperational}');

      expect(expiredInfo.status, equals(LicenseStatus.expired));
      expect(expiredInfo.daysRemaining, equals(0));
      expect(expiredInfo.isOperational, isFalse);
      print('✅ تم تأكيد قفل التطبيق عند انتهاء الأيام السبعة 100%.');
    });

    test('4. Activation with key generated by Python admin_dashboard activates app', () async {
      print('\n================================================================');
      print('الإثبات 4: توليد كود التفعيل عبر Python وتفعيل التطبيق بنجاح');
      print('================================================================');

      LicenseService.setMockRawDeviceId('DEVICE_TEST_HARDWARE_001');
      final deviceCode = await LicenseService.getDeviceCode();
      print('-> معرف الجهاز الفعلي: $deviceCode');

      // Run Python script to generate key via admin_dashboard logic
      final result = await Process.run('python3', [
        '-c',
        '''
import sys
sys.path.append('/data/data/com.termux/files/home/fuel_station_app_pro/license_keygen_tool')
import admin_dashboard

key = admin_dashboard.generate_activation_key("$deviceCode")
print(key)
        '''
      ]);

      expect(result.exitCode, equals(0));
      final generatedKey = result.stdout.toString().trim();
      print('-> كود التفعيل المستخرج من admin_dashboard.py: $generatedKey');

      // Verify Dart validation matches Python generation
      final isValid = LicenseService.validateActivationKey(
        deviceCode: deviceCode,
        inputKey: generatedKey,
      );
      expect(isValid, isTrue);
      print('-> مطابقة خوارزمية SHA-256 بين بايثون وفلاتر: متطابقة 100%');

      // Activate in app
      final activated = await LicenseService.activateLicense(
        inputKey: generatedKey,
        customDb: testDb,
      );
      expect(activated, isTrue);

      final statusAfter = await LicenseService.checkLicenseStatus(customDb: testDb);
      print('-> حالة الترخيص بعد التفعيل: ${statusAfter.status}');
      print('-> كود التفعيل المسجل في DB: ${statusAfter.activationKey}');
      print('-> تاريخ التفعيل: ${statusAfter.activatedAt}');
      print('-> هل التطبيق متاح للعمل: ${statusAfter.isOperational}');

      expect(statusAfter.status, equals(LicenseStatus.active));
      expect(statusAfter.isOperational, isTrue);
      expect(statusAfter.activationKey, equals(generatedKey));
      print('✅ تم تأكيد نجاح التفعيل وفتح كافة وظائف التطبيق.');
    });

    test('5. Cross-device attack simulation rejects copying DB to different machine', () async {
      print('\n================================================================');
      print('الإثبات 5: محاكاة نقل قاعدة البيانات لجهاز كمبيوتر آخر ورفض الترخيص');
      print('================================================================');

      // 1. Activate on original device
      LicenseService.setMockRawDeviceId('DEVICE_ORIGINAL_PC_001');
      final originalDeviceCode = await LicenseService.getDeviceCode();
      final keyForOriginal = LicenseService.generateActivationKey(originalDeviceCode);

      await LicenseService.activateLicense(inputKey: keyForOriginal, customDb: testDb);
      final originalInfo = await LicenseService.checkLicenseStatus(customDb: testDb);
      expect(originalInfo.status, equals(LicenseStatus.active));
      print('-> تم تفعيل الجهاز الأصلي [$originalDeviceCode] بنجاح.');

      // 2. Simulate transferring the DB file to a different computer (different hardware ID)
      LicenseService.setMockRawDeviceId('DEVICE_PIRATE_PC_999');
      final newDeviceCode = await LicenseService.getDeviceCode();
      print('-> تم تشغيل نفس قاعدة البيانات على جهاز مختلف بمعرف: [$newDeviceCode]');

      final crossDeviceInfo = await LicenseService.checkLicenseStatus(customDb: testDb);
      print('-> نتيجة فحص الترخيص على الجهاز الجديد: ${crossDeviceInfo.status}');
      print('-> رسالة الخطأ: ${crossDeviceInfo.errorMessage}');
      print('-> هل التطبيق متاح للعمل: ${crossDeviceInfo.isOperational}');

      expect(crossDeviceInfo.status, equals(LicenseStatus.mismatchedDevice));
      expect(crossDeviceInfo.isOperational, isFalse);

      // Verify entering original key for new device fails
      final wrongValidation = LicenseService.validateActivationKey(
        deviceCode: newDeviceCode,
        inputKey: keyForOriginal,
      );
      expect(wrongValidation, isFalse);
      print('✅ تم تأكيد الحماية ضد نقل ونسخ ملفات التطخيص لأجهزة أخرى.');
    });

    test('6. Admin Dashboard Reset Device issues new key and saves audit history', () async {
      print('\n================================================================');
      print('الإثبات 6: إعادة تعيين الترخيص لجهاز جديد من admin_dashboard مع سجل التدقيق');
      print('================================================================');

      final oldDevice = 'A3F9-K2M1';
      final newDevice = 'B7C4-M9X2';

      final pyScript = '''
import sys
sys.path.append('/data/data/com.termux/files/home/fuel_station_app_pro/license_keygen_tool')
import admin_dashboard

admin_dashboard.init_db()
conn = admin_dashboard.get_db_connection()
cursor = conn.cursor()

# 1. Insert original fuel station license
old_key = admin_dashboard.generate_activation_key("$oldDevice")
cursor.execute("""
  INSERT INTO licenses (
    merchant_name, phone, device_code, activation_key, product_type, status, created_at, updated_at
  ) VALUES ('محطة بشائر الخرطوم', '0911223344', "$oldDevice", ?, 'fuel_station', 'active', datetime('now'), datetime('now'))
""", (old_key,))
lic_id = cursor.lastrowid
conn.commit()

# 2. Execute reset device logic
new_key = admin_dashboard.generate_activation_key("$newDevice")
cursor.execute("""
  INSERT INTO license_device_history (
    license_id, merchant_name, product_type, old_device_code, old_activation_key, new_device_code, new_activation_key, reason, reset_at
  ) VALUES (?, 'محطة بشائر الخرطوم', 'fuel_station', "$oldDevice", ?, "$newDevice", ?, 'استبدال اللوحة الأم للجهاز', datetime('now'))
""", (lic_id, old_key, new_key))

cursor.execute("""
  UPDATE licenses SET device_code = ?, activation_key = ?, updated_at = datetime('now') WHERE id = ?
""", ("$newDevice", new_key, lic_id))
conn.commit()

# 3. Query history
cursor.execute("SELECT old_device_code, new_device_code, reason FROM license_device_history WHERE license_id = ?", (lic_id,))
hist = cursor.fetchone()

print(f"NEW_KEY:{new_key}")
print(f"HIST_OLD:{hist['old_device_code']}")
print(f"HIST_NEW:{hist['new_device_code']}")
print(f"HIST_REASON:{hist['reason']}")
conn.close()
''';

      final res = await Process.run('python3', ['-c', pyScript]);
      expect(res.exitCode, equals(0));
      final output = res.stdout.toString();
      print(output);

      expect(output, contains('NEW_KEY:'));
      expect(output, contains('HIST_OLD:A3F9-K2M1'));
      expect(output, contains('HIST_NEW:B7C4-M9X2'));

      final newKey = output.split('NEW_KEY:')[1].split('\n')[0].trim();

      // Verify the new device accepts this new key in Dart app
      final validForNew = LicenseService.validateActivationKey(
        deviceCode: newDevice,
        inputKey: newKey,
      );
      expect(validForNew, isTrue);

      // Verify the old device is rejected with the new key
      final invalidForOld = LicenseService.validateActivationKey(
        deviceCode: oldDevice,
        inputKey: newKey,
      );
      expect(invalidForOld, isFalse);

      print('✅ تم تأكيد نجاح إعادة تعيين الترخيص وتسجيل السجل التاريخي للأجهزة.');
    });

    testWidgets('7. UI verification: Expired trial locks screen and displays LicenseScreen', (WidgetTester tester) async {
      print('\n================================================================');
      print('الإثبات 7: فحص واجهة المستخدم (UI) والتأكد من قفل الشاشات عند انتهاء الفترة');
      print('================================================================');

      LicenseService.setMockRawDeviceId('UI_TEST_HARDWARE_123');
      final code = await LicenseService.getDeviceCode();

      // Force expired trial state in notifier
      LicenseService.licenseNotifier.value = LicenseInfo(
        status: LicenseStatus.expired,
        deviceCode: code,
        daysRemaining: 0,
        errorMessage: 'انتهت الفترة التجريبية (7 أيام). يرجى تفعيل الترخيص.',
      );

      await tester.pumpWidget(const FuelStationApp());
      await tester.pump();

      // Check that LicenseScreen is displayed and LoginScreen is blocked
      expect(find.byType(LicenseScreen), findsOneWidget);
      expect(find.text('انتهت الفترة التجريبية - يرجى التفعيل'), findsOneWidget);
      expect(find.text(code), findsOneWidget);
      expect(find.text('تواصل مع المطوّر للحصول على الترخيص (واتساب)'), findsOneWidget);
      expect(find.text('تسجيل الدخول للنظام (مدير المحطة / محاسب)'), findsNothing);

      print('✅ تم تأكيد قفل كافة شاشات التطبيق وعرض شاشة التفعيل الحصرية.');
    });
  });
}
