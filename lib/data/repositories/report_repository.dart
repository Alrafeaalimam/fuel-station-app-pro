import '../database_helper.dart';

class FinancialSummary {
  final double totalSalesCash;
  final double totalSalesBank;
  final double totalSalesCredit;
  final double totalSalesAmount;
  final double totalBenzinLiters;
  final double totalDieselLiters;
  final double totalExpenses;
  final double totalCreditCollected;
  final double totalDeliveryCost;

  const FinancialSummary({
    required this.totalSalesCash,
    required this.totalSalesBank,
    required this.totalSalesCredit,
    required this.totalSalesAmount,
    required this.totalBenzinLiters,
    required this.totalDieselLiters,
    required this.totalExpenses,
    required this.totalCreditCollected,
    required this.totalDeliveryCost,
  });

  double get netCashFlow => totalSalesCash + totalCreditCollected - totalExpenses;
}

class ReportRepository {
  final DatabaseHelper dbHelper;

  ReportRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<FinancialSummary> getFinancialSummary({String? fromDate, String? toDate}) async {
    final db = await dbHelper.database;

    // 1. Sales summary total
    String salesQuery = '''
      SELECT 
        SUM(ss.cash_amount) as total_cash,
        SUM(ss.bank_transfer_amount) as total_bank,
        SUM(ss.credit_amount) as total_credit,
        SUM(ss.total_amount) as total_amount
      FROM sales_summary ss
      JOIN shifts s ON ss.shift_id = s.id
    ''';
    List<dynamic> salesArgs = [];
    if (fromDate != null && toDate != null) {
      salesQuery += ' WHERE s.close_datetime >= ? AND s.close_datetime <= ?';
      salesArgs.addAll([fromDate, toDate]);
    }
    final salesResult = await db.rawQuery(salesQuery, salesArgs);

    double totalCash = 0;
    double totalBank = 0;
    double totalCredit = 0;
    double totalAmount = 0;

    if (salesResult.isNotEmpty) {
      totalCash = (salesResult.first['total_cash'] as num?)?.toDouble() ?? 0.0;
      totalBank = (salesResult.first['total_bank'] as num?)?.toDouble() ?? 0.0;
      totalCredit = (salesResult.first['total_credit'] as num?)?.toDouble() ?? 0.0;
      totalAmount = (salesResult.first['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Fuel liters sold by type
    String litersQuery = '''
      SELECT 
        t.fuel_type,
        SUM(sr.liters_sold) as total_liters
      FROM shift_readings sr
      JOIN pumps p ON sr.pump_id = p.id
      JOIN tanks t ON p.tank_id = t.id
      JOIN shifts s ON sr.shift_id = s.id
    ''';
    List<dynamic> litersArgs = [];
    if (fromDate != null && toDate != null) {
      litersQuery += ' WHERE s.close_datetime >= ? AND s.close_datetime <= ?';
      litersArgs.addAll([fromDate, toDate]);
    }
    litersQuery += ' GROUP BY t.fuel_type';
    final litersResult = await db.rawQuery(litersQuery, litersArgs);

    double benzinLiters = 0.0;
    double dieselLiters = 0.0;
    for (final row in litersResult) {
      final type = row['fuel_type'] as String? ?? '';
      final liters = (row['total_liters'] as num?)?.toDouble() ?? 0.0;
      if (type == 'بنزين') {
        benzinLiters = liters;
      } else if (type == 'جازولين') {
        dieselLiters = liters;
      }
    }

    // 3. Expenses total
    String expenseQuery = 'SELECT SUM(amount) as total_expenses FROM expenses';
    List<dynamic> expenseArgs = [];
    if (fromDate != null && toDate != null) {
      expenseQuery += ' WHERE date >= ? AND date <= ?';
      expenseArgs.addAll([fromDate, toDate]);
    }
    final expenseResult = await db.rawQuery(expenseQuery, expenseArgs);
    double totalExpenses = 0.0;
    if (expenseResult.isNotEmpty) {
      totalExpenses = (expenseResult.first['total_expenses'] as num?)?.toDouble() ?? 0.0;
    }

    // 4. Credit collected total
    String creditCollectedQuery = "SELECT SUM(amount) as total_collected FROM credit_transactions WHERE type = 'payment'";
    List<dynamic> creditArgs = [];
    if (fromDate != null && toDate != null) {
      creditCollectedQuery += ' AND transaction_date >= ? AND transaction_date <= ?';
      creditArgs.addAll([fromDate, toDate]);
    }
    final creditResult = await db.rawQuery(creditCollectedQuery, creditArgs);
    double totalCollected = 0.0;
    if (creditResult.isNotEmpty) {
      totalCollected = (creditResult.first['total_collected'] as num?)?.toDouble() ?? 0.0;
    }

    // 5. Total delivery cost
    String deliveryQuery = 'SELECT SUM(total_cost) as total_cost FROM deliveries';
    List<dynamic> deliveryArgs = [];
    if (fromDate != null && toDate != null) {
      deliveryQuery += ' WHERE delivered_at >= ? AND delivered_at <= ?';
      deliveryArgs.addAll([fromDate, toDate]);
    }
    final deliveryResult = await db.rawQuery(deliveryQuery, deliveryArgs);
    double totalDeliveryCost = 0.0;
    if (deliveryResult.isNotEmpty) {
      totalDeliveryCost = (deliveryResult.first['total_cost'] as num?)?.toDouble() ?? 0.0;
    }

    return FinancialSummary(
      totalSalesCash: totalCash,
      totalSalesBank: totalBank,
      totalSalesCredit: totalCredit,
      totalSalesAmount: totalAmount,
      totalBenzinLiters: benzinLiters,
      totalDieselLiters: dieselLiters,
      totalExpenses: totalExpenses,
      totalCreditCollected: totalCollected,
      totalDeliveryCost: totalDeliveryCost,
    );
  }
}
