import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/permission_guard.dart';

class CustomerRepository {
  final DatabaseHelper dbHelper;

  CustomerRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<CustomerModel>> getCustomers() async {
    final db = await dbHelper.database;
    final maps = await db.query('customers', orderBy: 'name ASC');
    return maps.map((e) => CustomerModel.fromMap(e)).toList();
  }

  Future<CustomerModel?> getCustomerById(int id) async {
    final db = await dbHelper.database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return CustomerModel.fromMap(maps.first);
    }
    return null;
  }

  Future<int> addCustomer(CustomerModel customer, {UserModel? user}) async {
    // تحديد السقف الائتماني للعميل الجديد يتطلب صلاحية المدير
    if (customer.creditLimit > 0) {
      PermissionGuard.check(user, AppPermission.editCustomerCreditLimit);
    }
    final db = await dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<int> updateCustomer(CustomerModel customer, {UserModel? user}) async {
    final db = await dbHelper.database;
    // التحقق هل تم تعديل السقف الائتماني
    final oldMaps = await db.query('customers', where: 'id = ?', whereArgs: [customer.id]);
    if (oldMaps.isNotEmpty) {
      final oldLimit = (oldMaps.first['credit_limit'] as num?)?.toDouble() ?? 0.0;
      if (oldLimit != customer.creditLimit) {
        PermissionGuard.check(user, AppPermission.editCustomerCreditLimit);
      }
    }
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> recordPayment({
    required int customerId,
    required double amount,
    String? notes,
    int? shiftId,
  }) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final today = now.substring(0, 10);

    await db.transaction((txn) async {
      // 1. Insert credit transaction
      await txn.insert('credit_transactions', {
        'customer_id': customerId,
        'shift_id': shiftId,
        'amount': amount,
        'type': 'payment',
        'transaction_date': now,
        'notes': notes ?? 'سداد دفعة نقدية من العميل',
        'settled': 1,
      });

      // 2. Reduce customer balance
      final customerMaps = await txn.query('customers', where: 'id = ?', whereArgs: [customerId]);
      if (customerMaps.isNotEmpty) {
        final currentBal = (customerMaps.first['current_balance'] as num?)?.toDouble() ?? 0.0;
        final newBal = (currentBal - amount).clamp(0.0, double.infinity);
        await txn.update(
          'customers',
          {'current_balance': newBal},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      }

      // 3. Update Cash Box for today
      final cashBoxMaps = await txn.query('cash_box', where: 'date = ?', whereArgs: [today]);
      if (cashBoxMaps.isNotEmpty) {
        final box = cashBoxMaps.first;
        final cashIn = (box['cash_in'] as num?)?.toDouble() ?? 0.0;
        final closing = (box['closing_balance'] as num?)?.toDouble() ?? 0.0;
        await txn.update(
          'cash_box',
          {
            'cash_in': cashIn + amount,
            'closing_balance': closing + amount,
          },
          where: 'date = ?',
          whereArgs: [today],
        );
      } else {
        // Create new cashbox row
        final lastBoxes = await txn.query('cash_box', orderBy: 'date DESC', limit: 1);
        final opening = lastBoxes.isNotEmpty
            ? ((lastBoxes.first['closing_balance'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        await txn.insert('cash_box', {
          'date': today,
          'opening_balance': opening,
          'cash_in': amount,
          'cash_out': 0.0,
          'closing_balance': opening + amount,
          'notes': 'تحصيل دفعة آجل',
        });
      }
    });
  }

  Future<List<CreditTransactionModel>> getCustomerTransactions(
    int customerId, {
    String? fromDate,
    String? toDate,
  }) async {
    final db = await dbHelper.database;
    String whereClause = 'customer_id = ?';
    List<dynamic> whereArgs = [customerId];

    if (fromDate != null && toDate != null) {
      whereClause += ' AND transaction_date >= ? AND transaction_date <= ?';
      whereArgs.addAll([fromDate, toDate]);
    }

    final maps = await db.query(
      'credit_transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'transaction_date DESC, id DESC',
    );
    return maps.map((e) => CreditTransactionModel.fromMap(e)).toList();
  }

  Future<List<CreditTransactionModel>> getAllTransactions() async {
    final db = await dbHelper.database;
    final maps = await db.query('credit_transactions', orderBy: 'transaction_date DESC, id DESC');
    return maps.map((e) => CreditTransactionModel.fromMap(e)).toList();
  }
}
