import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/delivery_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/customer_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/expense_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Comprehensive Live Execution Proof: Deliveries, Customers, Expenses', () async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final deliveryRepo = DeliveryRepository(dbHelper: dbHelper);
    final customerRepo = CustomerRepository(dbHelper: dbHelper);
    final expenseRepo = ExpenseRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);

    print('\n================================================================');
    print('1. أ) شاشة التوريد (Deliveries) - تسجيل شحنة وتحديث الخزان');
    print('================================================================');
    final tanks = await tankRepo.getTanks();
    final benzinTank = tanks.firstWhere((t) => t.fuelType == 'بنزين');
    
    // Read tank dip before
    final tankBeforeMaps = await db.query('tanks', where: 'id = ?', whereArgs: [benzinTank.id]);
    final dipBefore = (tankBeforeMaps.first['current_dip_liters'] as num).toDouble();
    print('-> خزان البنزين [ID: ${benzinTank.id}] - منسوب المسطرة قبل الشحنة: $dipBefore لتر');

    // Ensure test supplier exists
    final suppliers = await deliveryRepo.getSuppliers();
    int supplierId;
    if (suppliers.isEmpty) {
      final authRepo = AuthRepository(dbHelper: dbHelper);
      final manager = await authRepo.login('admin', 'admin123');
      supplierId = await deliveryRepo.addSupplier(
        const SupplierModel(name: 'شركة النيل للبترول', phone: '0912345678'),
        user: manager,
      );
    } else {
      supplierId = suppliers.first.id!;
    }

    // Record delivery of 5,000 Liters
    final delivery = DeliveryModel(
      supplierId: supplierId,
      tankId: benzinTank.id!,
      liters: 5000.0,
      costPerLiter: 1100.0,
      totalCost: 5500000.0,
      deliveredAt: DateTime.now().toIso8601String(),
      recordedByUserId: 1,
    );
    final deliveryId = await deliveryRepo.recordDelivery(delivery);
    expect(deliveryId, greaterThan(0));

    // Read tank dip after
    final tankAfterMaps = await db.query('tanks', where: 'id = ?', whereArgs: [benzinTank.id]);
    final dipAfter = (tankAfterMaps.first['current_dip_liters'] as num).toDouble();
    print('-> تم إدراج الشحنة بنجاح في جدول deliveries برقم ID: #$deliveryId');
    print('-> خزان البنزين [ID: ${benzinTank.id}] - منسوب المسطرة بعد الشحنة: $dipAfter لتر');
    print('-> الزيادة الفعلية: +${dipAfter - dipBefore} لتر (مطابقة للـ 5000 لتر المسجلة)');
    expect(dipAfter, equals(dipBefore + 5000.0));

    print('\n================================================================');
    print('2. ب) شاشة العملاء والآجل (Customers) - تسجيل دفعة سداد وترحيلها للخزنة');
    print('================================================================');
    // Ensure test customer exists
    final customers = await customerRepo.getCustomers();
    CustomerModel testCustomer;
    if (customers.isEmpty) {
      final authRepo = AuthRepository(dbHelper: dbHelper);
      final manager = await authRepo.login('admin', 'admin123');
      final newId = await customerRepo.addCustomer(CustomerModel(
        name: 'عميل الفحص الشامل',
        type: 'مؤسسة حكومية',
        phone: '0912345678',
        creditLimit: 500000.0,
        currentBalance: 150000.0,
      ), user: manager);
      testCustomer = (await customerRepo.getCustomerById(newId))!;
    } else {
      testCustomer = customers.first;
      // Set a defined balance for testing
      await db.update('customers', {'current_balance': 150000.0}, where: 'id = ?', whereArgs: [testCustomer.id]);
      testCustomer = (await customerRepo.getCustomerById(testCustomer.id!))!;
    }

    // Ensure a cashbox row for today exists
    var cashBoxMaps = await db.query('cash_box', where: 'date = ?', whereArgs: [today]);
    if (cashBoxMaps.isEmpty) {
      await db.insert('cash_box', {
        'date': today,
        'opening_balance': 500000.0,
        'cash_in': 0.0,
        'cash_out': 0.0,
        'closing_balance': 500000.0,
      });
      cashBoxMaps = await db.query('cash_box', where: 'date = ?', whereArgs: [today]);
    }

    final custBalBefore = testCustomer.currentBalance;
    final cashClosingBefore = (cashBoxMaps.first['closing_balance'] as num).toDouble();
    final cashInBefore = (cashBoxMaps.first['cash_in'] as num).toDouble();

    print('-> العميل [${testCustomer.name}] - رصيد المديونية قبل السداد: $custBalBefore ج.س');
    print('-> الخزنة اليومية [$today] - رصيد الإغلاق قبل السداد: $cashClosingBefore ج.س | الوارد cash_in: $cashInBefore ج.س');

    // Record payment of 50,000 SDG
    const paymentAmount = 50000.0;
    await customerRepo.recordPayment(
      customerId: testCustomer.id!,
      amount: paymentAmount,
      notes: 'سداد دفعة نقدية لاختبار الترحيل الفعلي للخزنة',
    );

    // Read customer balance after
    final updatedCustomer = (await customerRepo.getCustomerById(testCustomer.id!))!;
    final custBalAfter = updatedCustomer.currentBalance;

    // Read cashbox after
    final cashBoxAfterMaps = await db.query('cash_box', where: 'date = ?', whereArgs: [today]);
    final cashClosingAfter = (cashBoxAfterMaps.first['closing_balance'] as num).toDouble();
    final cashInAfter = (cashBoxAfterMaps.first['cash_in'] as num).toDouble();

    print('-> العميل [${testCustomer.name}] - رصيد المديونية بعد السداد: $custBalAfter ج.س (انخفاض بمقدار: ${custBalBefore - custBalAfter} ج.س)');
    print('-> الخزنة اليومية [$today] - رصيد الإغلاق بعد السداد: $cashClosingAfter ج.س (زيادة بمقدار: +${cashClosingAfter - cashClosingBefore} ج.س)');
    print('-> وارد الخزنة cash_in أصبح: $cashInAfter ج.س (زيادة بمقدار: +${cashInAfter - cashInBefore} ج.س)');

    expect(custBalAfter, equals(custBalBefore - paymentAmount));
    expect(cashClosingAfter, equals(cashClosingBefore + paymentAmount));
    expect(cashInAfter, equals(cashInBefore + paymentAmount));

    // Verify Monthly Statement transactions query
    final txns = await customerRepo.getCustomerTransactions(testCustomer.id!);
    print('-> عدد الحركات المسجلة في كشف حساب العميل: ${txns.length} حركة (تتضمن حركة السداد الأخيرة بقيمة $paymentAmount ج.س)');
    expect(txns.any((t) => t.isPayment && t.amount == paymentAmount), isTrue);

    print('\n================================================================');
    print('3. ج) شاشة المصروفات (Expenses) - تسجيل مصروف وخصمه من الخزنة');
    print('================================================================');
    final cashBeforeExpMaps = await db.query('cash_box', where: 'date = ?', whereArgs: [today]);
    final cashClosingBeforeExp = (cashBeforeExpMaps.first['closing_balance'] as num).toDouble();
    final cashOutBeforeExp = (cashBeforeExpMaps.first['cash_out'] as num).toDouble();

    print('-> الخزنة اليومية [$today] - رصيد الإغلاق قبل المصروف: $cashClosingBeforeExp ج.س | المنصرف cash_out: $cashOutBeforeExp ج.س');

    // Add Expense of 20,000 SDG
    const expenseAmount = 20000.0;
    final expense = ExpenseModel(
      date: DateTime.now().toIso8601String(),
      category: 'صيانة',
      amount: expenseAmount,
      description: 'صيانة دورية تجريبية لمضخة الديزل',
      recordedByUserId: 1,
    );
    final expenseId = await expenseRepo.addExpense(expense);
    expect(expenseId, greaterThan(0));

    // Read cashbox after expense
    final cashAfterExpMaps = await db.query('cash_box', where: 'date = ?', whereArgs: [today]);
    final cashClosingAfterExp = (cashAfterExpMaps.first['closing_balance'] as num).toDouble();
    final cashOutAfterExp = (cashAfterExpMaps.first['cash_out'] as num).toDouble();

    print('-> تم إدراج المصروف بنجاح في جدول expenses برقم ID: #$expenseId');
    print('-> الخزنة اليومية [$today] - رصيد الإغلاق بعد المصروف: $cashClosingAfterExp ج.س (خصم بمقدار: -${cashClosingBeforeExp - cashClosingAfterExp} ج.س)');
    print('-> منصرف الخزنة cash_out أصبح: $cashOutAfterExp ج.س (زيادة بمقدار: +${cashOutAfterExp - cashOutBeforeExp} ج.س)');

    expect(cashClosingAfterExp, equals(cashClosingBeforeExp - expenseAmount));
    expect(cashOutAfterExp, equals(cashOutBeforeExp + expenseAmount));

    print('\n================================================================');
    print('✅ جميع الاختبارات التنفيذية على قاعدة البيانات أثبتت صحة العمليات 100%');
    print('================================================================\n');
  });
}
