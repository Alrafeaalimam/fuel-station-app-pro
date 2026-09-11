import '../database_helper.dart';
import '../../models/models.dart';

class ExpenseRepository {
  final DatabaseHelper dbHelper;

  ExpenseRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<ExpenseModel>> getExpenses({String? date}) async {
    final db = await dbHelper.database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (date != null) {
      whereClause = 'date LIKE ?';
      whereArgs = ['$date%'];
    }

    final maps = await db.query(
      'expenses',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC, id DESC',
    );
    return maps.map((e) => ExpenseModel.fromMap(e)).toList();
  }

  Future<int> addExpense(ExpenseModel expense) async {
    final db = await dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return await db.transaction((txn) async {
      // 1. Insert expense
      final id = await txn.insert('expenses', expense.toMap());

      // 2. Update cash box
      final cashBoxMaps = await txn.query('cash_box', where: 'date = ?', whereArgs: [today]);
      if (cashBoxMaps.isNotEmpty) {
        final box = cashBoxMaps.first;
        final cashOut = (box['cash_out'] as num?)?.toDouble() ?? 0.0;
        final closing = (box['closing_balance'] as num?)?.toDouble() ?? 0.0;
        await txn.update(
          'cash_box',
          {
            'cash_out': cashOut + expense.amount,
            'closing_balance': closing - expense.amount,
          },
          where: 'date = ?',
          whereArgs: [today],
        );
      } else {
        final lastBoxes = await txn.query('cash_box', orderBy: 'date DESC', limit: 1);
        final opening = lastBoxes.isNotEmpty
            ? ((lastBoxes.first['closing_balance'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        await txn.insert('cash_box', {
          'date': today,
          'opening_balance': opening,
          'cash_in': 0.0,
          'cash_out': expense.amount,
          'closing_balance': opening - expense.amount,
          'notes': 'مصروف: ${expense.description}',
        });
      }

      return id;
    });
  }

  Future<Map<String, double>> getExpensesByCategory({String? fromDate, String? toDate}) async {
    final db = await dbHelper.database;
    String query = 'SELECT category, SUM(amount) as total FROM expenses';
    List<dynamic> args = [];

    if (fromDate != null && toDate != null) {
      query += ' WHERE date >= ? AND date <= ?';
      args.addAll([fromDate, toDate]);
    }

    query += ' GROUP BY category';
    final result = await db.rawQuery(query, args);

    final Map<String, double> summary = {};
    for (final row in result) {
      final cat = row['category'] as String? ?? 'أخرى';
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      summary[cat] = total;
    }
    return summary;
  }
}
