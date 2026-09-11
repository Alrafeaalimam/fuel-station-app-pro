import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/backup_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';
import 'package:fuel_station_app_pro/utils/permission_guard.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Backup & Restore System Comprehensive Tests', () {
    late Directory tempDir;
    late String dbFilePath;
    late DatabaseHelper dbHelper;
    late BackupRepository backupRepo;

    const adminUser = UserModel(
      id: 1,
      name: 'مدير المحطة',
      username: 'admin',
      passwordHash: 'admin123',
      role: 'manager',
    );

    const accountantUser = UserModel(
      id: 2,
      name: 'محاسب المحطة',
      username: 'accountant',
      passwordHash: 'acc123',
      role: 'accountant',
    );

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('fuel_station_backup_test_');
      dbFilePath = p.join(tempDir.path, 'fuel_station_pro.db');

      // Create physical test DB file
      final initialDb = await databaseFactoryFfi.openDatabase(
        dbFilePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
        ),
      );
      await initialDb.close();

      dbHelper = DatabaseHelper.withFile(dbFilePath);
      backupRepo = BackupRepository(dbHelper: dbHelper);
    });

    tearDown(() async {
      await dbHelper.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('1. RBAC: Non-manager is rejected from creating or restoring backups', () async {
      final destPath = p.join(tempDir.path, 'unauthorized_backup.db');

      // Attempt manual backup as accountant
      expect(
        () => backupRepo.createManualBackup(destPath, user: accountantUser),
        throwsA(isA<UnauthorizedException>()),
      );

      // Attempt getDatabaseBytes as accountant
      expect(
        () => backupRepo.getDatabaseBytes(user: accountantUser),
        throwsA(isA<UnauthorizedException>()),
      );

      // Attempt restore as accountant
      expect(
        () => backupRepo.restoreBackup(destPath, user: accountantUser),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('2. Manual Backup Creation and Reminder Logic', () async {
      // Initially no manual backup recorded, reminder should be needed
      expect(await backupRepo.isManualBackupReminderNeeded(), isTrue);
      expect(await backupRepo.getLastManualBackupDate(), isNull);

      // Create manual backup as Manager
      final backupPath = p.join(tempDir.path, 'manual_backups', 'fuel_station_backup_2026-09-09_12-00.db');
      final createdPath = await backupRepo.createManualBackup(backupPath, user: adminUser);

      expect(createdPath, equals(backupPath));
      final backupFile = File(backupPath);
      expect(await backupFile.exists(), isTrue);
      expect(await backupFile.length(), greaterThan(100));

      // Check last manual backup date updated and reminder no longer needed
      final lastDate = await backupRepo.getLastManualBackupDate();
      expect(lastDate, isNotNull);
      expect(await backupRepo.isManualBackupReminderNeeded(), isFalse);

      // Verify getDatabaseBytes works and matches file length
      final bytes = await backupRepo.getDatabaseBytes(user: adminUser);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.length, equals(await File(dbFilePath).length()));
    });

    test('3. End-to-End Disaster Recovery: Backup -> Modify/Wipe -> Restore -> Verify', () async {
      final db = await dbHelper.database;

      // 1. Insert a known baseline record into customers
      final customerId = await db.insert('customers', {
        'name': 'شركة الأمل للنقليات',
        'type': 'company',
        'phone': '0912345678',
        'credit_limit': 150000.0,
        'current_balance': 45000.0,
      });
      expect(customerId, greaterThan(0));

      // Verify customer exists in database
      var checkCust = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      expect(checkCust.length, equals(1));
      expect(checkCust.first['name'], equals('شركة الأمل للنقليات'));

      // 2. Take manual snapshot of the database state
      final snapshotPath = p.join(tempDir.path, 'snapshots', 'pre_disaster_snapshot.db');
      await backupRepo.createManualBackup(snapshotPath, user: adminUser);
      expect(File(snapshotPath).existsSync(), isTrue);

      // 3. Simulate disaster: customer is deleted and table is wiped
      await db.delete('customers', where: 'id = ?', whereArgs: [customerId]);
      checkCust = await db.query('customers', where: 'id = ?', whereArgs: [customerId]);
      expect(checkCust.isEmpty, isTrue);

      // 4. Restore database from snapshot
      await backupRepo.restoreBackup(snapshotPath, user: adminUser);

      // 5. Re-query database and verify customer is completely recovered!
      final restoredDb = await dbHelper.database;
      final recoveredCust = await restoredDb.query('customers', where: 'id = ?', whereArgs: [customerId]);
      expect(recoveredCust.length, equals(1));
      expect(recoveredCust.first['name'], equals('شركة الأمل للنقليات'));
      expect(recoveredCust.first['current_balance'], equals(45000.0));
    });

    test('4. Automatic Backup on Shift Close', () async {
      final shiftRepo = ShiftRepository(dbHelper: dbHelper, backupRepo: backupRepo);

      final closeShift = ShiftModel(
        closedByUserId: 1,
        closeDatetime: '2026-09-09T16:00:00',
        status: 'closed',
        notes: 'وردية تجريبية لاختبار النسخ التلقائي',
      );

      final summary = SalesSummaryModel(
        shiftId: 0,
        cashAmount: 500.0,
        bankTransferAmount: 0.0,
        creditAmount: 0.0,
        totalAmount: 500.0,
      );

      // Close the shift (this triggers automatic backup silently)
      final closedShiftId = await shiftRepo.closeShift(
        shift: closeShift,
        readings: [],
        summary: summary,
      );
      expect(closedShiftId, greaterThan(0));

      // Verify that auto backup file was created
      final autoBackups = await backupRepo.getAutoBackups();
      expect(autoBackups.isNotEmpty, isTrue);
      final latestAuto = autoBackups.first;
      expect(p.basename(latestAuto.path), startsWith('fuel_station_auto_'));
      expect(await latestAuto.length(), greaterThan(100));
    });

    test('5. Automatic Backup Pruning: Max 14 backups retained', () async {
      final autoDir = Directory(await backupRepo.getAutoBackupsDirectoryPath());
      expect(await autoDir.exists(), isTrue);

      // Create 18 dummy auto backup files with sequential date tags
      for (int i = 1; i <= 18; i++) {
        final dayStr = i.toString().padLeft(2, '0');
        final dummyFile = File(p.join(autoDir.path, 'fuel_station_auto_2026-08-$dayStr.db'));
        await dummyFile.writeAsString('Dummy SQLite backup content for day $dayStr');
      }

      var currentBackups = await backupRepo.getAutoBackups();
      expect(currentBackups.length, equals(18));

      // Trigger prune keeping max 14
      final deletedCount = await backupRepo.pruneAutoBackups(maxKeep: 14);
      expect(deletedCount, equals(4));

      final remainingBackups = await backupRepo.getAutoBackups();
      expect(remainingBackups.length, equals(14));

      // Verify that the newest 14 (days 05 through 18) remain, and oldest (days 01 to 04) were removed
      final remainingNames = remainingBackups.map((f) => p.basename(f.path)).toList();
      expect(remainingNames.contains('fuel_station_auto_2026-08-18.db'), isTrue);
      expect(remainingNames.contains('fuel_station_auto_2026-08-05.db'), isTrue);
      expect(remainingNames.contains('fuel_station_auto_2026-08-01.db'), isFalse);
      expect(remainingNames.contains('fuel_station_auto_2026-08-04.db'), isFalse);
    });
  });
}
