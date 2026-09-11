import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/permission_guard.dart';

class CashBoxRepository {
  final DatabaseHelper dbHelper;

  CashBoxRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<CashBoxModel> getOrCreateTodayCashBox() async {
    final db = await dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final maps = await db.query('cash_box', where: 'date = ?', whereArgs: [today]);
    if (maps.isNotEmpty) {
      return CashBoxModel.fromMap(maps.first);
    }

    // Fetch yesterday's closing balance
    final lastBoxes = await db.query(
      'cash_box',
      where: 'date < ?',
      whereArgs: [today],
      orderBy: 'date DESC',
      limit: 1,
    );

    double openingBalance = 0.0;
    if (lastBoxes.isNotEmpty) {
      openingBalance = (lastBoxes.first['closing_balance'] as num?)?.toDouble() ?? 0.0;
    }

    final newBox = CashBoxModel(
      date: today,
      openingBalance: openingBalance,
      cashIn: 0.0,
      cashOut: 0.0,
      closingBalance: openingBalance,
      notes: 'رصيد افتتاحي من إغلاق اليوم السابق',
    );

    final id = await db.insert('cash_box', newBox.toMap());
    return newBox.copyWith(id: id);
  }

  Future<CashBoxModel?> getCashBoxForDate(String date) async {
    final db = await dbHelper.database;
    final maps = await db.query('cash_box', where: 'date = ?', whereArgs: [date]);
    if (maps.isNotEmpty) {
      return CashBoxModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<CashBoxModel>> getCashBoxHistory() async {
    final db = await dbHelper.database;
    final maps = await db.query('cash_box', orderBy: 'date DESC');
    return maps.map((e) => CashBoxModel.fromMap(e)).toList();
  }

  Future<void> updateTodayCashBox({
    required double cashInDelta,
    required double cashOutDelta,
    String? notes,
    UserModel? user,
  }) async {
    PermissionGuard.check(user, AppPermission.adjustCashBoxManually);
    final db = await dbHelper.database;
    final todayBox = await getOrCreateTodayCashBox();
    final newCashIn = todayBox.cashIn + cashInDelta;
    final newCashOut = todayBox.cashOut + cashOutDelta;
    final newClosing = todayBox.openingBalance + newCashIn - newCashOut;

    await db.update(
      'cash_box',
      {
        'cash_in': newCashIn,
        'cash_out': newCashOut,
        'closing_balance': newClosing,
        ...?notes != null ? {'notes': notes} : null,
      },
      where: 'id = ?',
      whereArgs: [todayBox.id],
    );
  }
}
