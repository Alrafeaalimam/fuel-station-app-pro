import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/permission_guard.dart';
import '../../config/station_config.dart';

class BackupRepository {
  final DatabaseHelper dbHelper;

  BackupRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<String> getDatabasePath() async {
    return await dbHelper.getDatabasePath();
  }

  Future<int> getDatabaseSize() async {
    try {
      final path = await getDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  Future<DateTime?> getLastManualBackupDate() async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['last_manual_backup_date'],
      );
      if (maps.isNotEmpty && maps.first['value'] != null) {
        final val = maps.first['value'].toString();
        return DateTime.tryParse(val);
      }
    } catch (_) {}
    return null;
  }

  Future<void> setLastManualBackupDate(DateTime date) async {
    try {
      final db = await dbHelper.database;
      await db.insert(
        'settings',
        {
          'key': 'last_manual_backup_date',
          'value': date.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<bool> isManualBackupReminderNeeded() async {
    final lastDate = await getLastManualBackupDate();
    if (lastDate == null) return true;
    final diff = DateTime.now().difference(lastDate).inDays;
    return diff >= 7;
  }

  Future<String> getAutoBackupsDirectoryPath() async {
    final dbPath = await getDatabasePath();
    final parentDir = dirname(dbPath);
    final autoDir = Directory(join(parentDir, 'auto_backups'));
    if (!await autoDir.exists()) {
      await autoDir.create(recursive: true);
    }
    return autoDir.path;
  }

  /// Retrieves database bytes for direct file picker saving
  Future<Uint8List> getDatabaseBytes({UserModel? user}) async {
    PermissionGuard.check(user, AppPermission.manageBackup);

    // Flush any pending WAL data before reading
    try {
      final db = await dbHelper.database;
      await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');
    } catch (_) {}

    final srcPath = await getDatabasePath();
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      throw Exception('ملف قاعدة البيانات الأصلي غير موجود: $srcPath');
    }

    return await srcFile.readAsBytes();
  }

  /// Create manual backup to a user-chosen destination
  Future<String> createManualBackup(String destinationPath, {UserModel? user}) async {
    PermissionGuard.check(user, AppPermission.manageBackup);

    // Flush any pending WAL data before copying
    try {
      final db = await dbHelper.database;
      await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');
    } catch (_) {}

    final srcPath = await getDatabasePath();
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      throw Exception('ملف قاعدة البيانات الأصلي غير موجود: $srcPath');
    }

    final destDir = Directory(dirname(destinationPath));
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    await srcFile.copy(destinationPath);
    await setLastManualBackupDate(DateTime.now());

    return destinationPath;
  }

  /// Silent automatic backup triggered on shift close
  Future<String> createAutomaticBackup({String? customDateTag}) async {
    try {
      // Flush any pending WAL data
      try {
        final db = await dbHelper.database;
        await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');
      } catch (_) {}

      final srcPath = await getDatabasePath();
      final srcFile = File(srcPath);
      if (!await srcFile.exists()) return '';

      final autoDir = await getAutoBackupsDirectoryPath();
      final dateTag = customDateTag ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final targetPath = join(autoDir, 'fuel_station_auto_$dateTag.db');

      await srcFile.copy(targetPath);

      // Keep only up to 14 latest automatic backups
      await pruneAutoBackups(maxKeep: 14);

      return targetPath;
    } catch (_) {
      return '';
    }
  }

  /// Prunes automatic backups in the auto_backups folder, keeping only the most recent [maxKeep] files
  Future<int> pruneAutoBackups({int maxKeep = 14}) async {
    try {
      final autoDir = Directory(await getAutoBackupsDirectoryPath());
      if (!await autoDir.exists()) return 0;

      final files = await getAutoBackups();
      if (files.length <= maxKeep) return 0;

      int deletedCount = 0;
      for (int i = maxKeep; i < files.length; i++) {
        try {
          await files[i].delete();
          deletedCount++;
        } catch (_) {}
      }
      return deletedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Returns all automatic backup files sorted descending by modification time / name
  Future<List<File>> getAutoBackups() async {
    try {
      final autoDir = Directory(await getAutoBackupsDirectoryPath());
      if (!await autoDir.exists()) return [];

      final entities = await autoDir.list().toList();
      final files = entities
          .whereType<File>()
          .where((f) => basename(f.path).startsWith('fuel_station_auto_') && f.path.endsWith('.db'))
          .toList();

      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Restores database from a selected backup file
  Future<void> restoreBackup(String backupFilePath, {UserModel? user}) async {
    PermissionGuard.check(user, AppPermission.manageBackup);

    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('ملف النسخة الاحتياطية المحدد غير موجود.');
    }

    final fileLength = await backupFile.length();
    if (fileLength < 100) {
      throw Exception('ملف النسخة الاحتياطية فارغ أو تالف وغير صالح للاستعادة.');
    }

    // 1. Close current database connection safely
    await dbHelper.close();

    // 2. Overwrite target db file
    final targetPath = await getDatabasePath();
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await backupFile.copy(targetPath);

    // 3. Verify that restored database can be opened
    try {
      final newDb = await dbHelper.database;
      await newDb.rawQuery('SELECT count(*) FROM users');
    } catch (e) {
      throw Exception('فشل التحقق من صحة قاعدة البيانات المستعادة: $e');
    }

    // 4. Reload station config dynamically
    await StationConfig.loadStationName(dbHelper: dbHelper);
  }
}
