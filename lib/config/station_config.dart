import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../data/database_helper.dart';

class StationConfig {
  static final ValueNotifier<String> stationNameNotifier =
      ValueNotifier<String>('محطة الوقود النموذجية');

  static String get stationName => stationNameNotifier.value;

  static Future<void> loadStationName({DatabaseHelper? dbHelper}) async {
    try {
      final db = await (dbHelper ?? DatabaseHelper.instance).database;
      final maps = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['station_name'],
      );
      if (maps.isNotEmpty && maps.first['value'] != null) {
        final name = maps.first['value'].toString().trim();
        if (name.isNotEmpty) {
          stationNameNotifier.value = name;
        }
      }
    } catch (_) {}
  }

  static Future<void> setStationName(String newName, {DatabaseHelper? dbHelper}) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    stationNameNotifier.value = trimmed;
    try {
      final db = await (dbHelper ?? DatabaseHelper.instance).database;
      await db.insert(
        'settings',
        {'key': 'station_name', 'value': trimmed},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
