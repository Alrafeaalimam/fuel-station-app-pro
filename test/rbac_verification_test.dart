import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/customer_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/delivery_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/cash_box_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';
import 'package:fuel_station_app_pro/utils/permission_guard.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('RBAC System Strict Verification: Role Restrictions & Repository Defense', () async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final authRepo = AuthRepository(dbHelper: dbHelper);
    final customerRepo = CustomerRepository(dbHelper: dbHelper);
    final deliveryRepo = DeliveryRepository(dbHelper: dbHelper);
    final cashBoxRepo = CashBoxRepository(dbHelper: dbHelper);

    // =========================================================================
    // 1. تسجيل الدخول والتحقق من المصفوفة المركزية للصلاحيات (Permissions Matrix)
    // =========================================================================
    print('\n================================================================');
    print('1. تسجيل الدخول بحساب المحاسب والتحقق من الصلاحيات');
    print('================================================================');
    final accountant = await authRepo.login('accountant', 'acc123');
    expect(accountant, isNotNull);
    expect(accountant!.isAccountant, isTrue);
    expect(accountant.isManager, isFalse);
    print('-> تم تسجيل دخول المستخدم: ${accountant.name} (الدور: ${accountant.roleArabic})');

    // التحقق من الصلاحيات المحظورة على المحاسب
    expect(accountant.can(AppPermission.editCustomerCreditLimit), isFalse);
    expect(accountant.can(AppPermission.manageSuppliers), isFalse);
    expect(accountant.can(AppPermission.adjustCashBoxManually), isFalse);
    expect(accountant.can(AppPermission.viewStrategicReports), isFalse);
    expect(accountant.can(AppPermission.editFuelPrices), isFalse);
    print('-> فحص الصلاحيات الحصرية:');
    print('   - تعديل السقف الائتماني للعملاء: ${accountant.can(AppPermission.editCustomerCreditLimit) ? "مسموح" : "❌ محظور"}');
    print('   - إدارة وإضافة الموردين: ${accountant.can(AppPermission.manageSuppliers) ? "مسموح" : "❌ محظور"}');
    print('   - تعديل رصيد الخزنة يدوياً: ${accountant.can(AppPermission.adjustCashBoxManually) ? "مسموح" : "❌ محظور"}');
    print('   - التقارير المالية الاستراتيجية: ${accountant.can(AppPermission.viewStrategicReports) ? "مسموح" : "❌ محظور"}');
    print('   - تعديل أسعار الوقود: ${accountant.can(AppPermission.editFuelPrices) ? "مسموح" : "❌ محظور"}');

    // التحقق من الصلاحيات التشغيلية المتاحة للمحاسب
    expect(accountant.can(AppPermission.recordCustomerPayment), isTrue);
    expect(accountant.can(AppPermission.recordDelivery), isTrue);
    expect(accountant.can(AppPermission.recordExpense), isTrue);
    expect(accountant.can(AppPermission.closeShift), isTrue);
    print('-> فحص الصلاحيات التشغيلية اليومية:');
    print('   - تسجيل دفعات سداد العملاء: ${accountant.can(AppPermission.recordCustomerPayment) ? "✅ مسموح" : "محظور"}');
    print('   - تسجيل شحنات الوقود: ${accountant.can(AppPermission.recordDelivery) ? "✅ مسموح" : "محظور"}');
    print('   - تسجيل المصروفات: ${accountant.can(AppPermission.recordExpense) ? "✅ مسموح" : "محظور"}');
    print('   - قفل الوردية: ${accountant.can(AppPermission.closeShift) ? "✅ مسموح" : "محظور"}');

    // تسجيل دخول المدير
    final manager = await authRepo.login('admin', 'admin123');
    expect(manager, isNotNull);
    expect(manager!.isManager, isTrue);
    expect(manager.can(AppPermission.editCustomerCreditLimit), isTrue);
    expect(manager.can(AppPermission.manageSuppliers), isTrue);
    expect(manager.can(AppPermission.adjustCashBoxManually), isTrue);
    expect(manager.can(AppPermission.viewStrategicReports), isTrue);

    // =========================================================================
    // 2. اختبار محاولة المحاسب تعديل السقف الائتماني لعميل (اختراق/تجاوز الواجهة)
    // =========================================================================
    print('\n================================================================');
    print('2. تجربة اختراق: محاولة المحاسب تعديل credit_limit لعميل');
    print('================================================================');
    // إعداد عميل تجريبي بسقف 100,000 ج.س
    final testCustId = await db.insert('customers', {
      'name': 'عميل اختبار الحماية RBAC',
      'type': 'زبون دائم',
      'phone': '0999999999',
      'credit_limit': 100000.0,
      'current_balance': 20000.0,
    });
    final originalCustomer = (await customerRepo.getCustomerById(testCustId))!;
    print('-> بيانات العميل الأصلية: السقف الائتماني = ${originalCustomer.creditLimit} ج.س');

    // المحاسب يحاول رفع السقف الائتماني إلى 500,000 ج.س
    final hackedCustomer = originalCustomer.copyWith(creditLimit: 500000.0);
    print('-> يقوم المحاسب بمحاولة استدعاء updateCustomer وتمرير سقف جديد (500,000 ج.س)...');

    bool exceptionThrown = false;
    try {
      await customerRepo.updateCustomer(hackedCustomer, user: accountant);
    } on UnauthorizedException catch (e) {
      exceptionThrown = true;
      print('-> 🛑 رفض أمني صارم من الـ Repository: $e');
    }
    expect(exceptionThrown, isTrue, reason: 'Repository MUST throw UnauthorizedException when accountant tries to change credit_limit');

    // التحقق من قاعدة البيانات أن السقف لم يتغير إطلاقاً
    final checkMaps = await db.query('customers', where: 'id = ?', whereArgs: [testCustId]);
    final persistedLimit = (checkMaps.first['credit_limit'] as num).toDouble();
    print('-> فحص قاعدة البيانات المباشر: السقف المخزن هو $persistedLimit ج.س (لم يتغير إطلاقاً)');
    expect(persistedLimit, 100000.0);

    // الآن: المدير العام يقوم بنفس التعديل
    print('-> يقوم مدير المحطة بتنفيذ نفس التعديل بسقف 500,000 ج.س...');
    await customerRepo.updateCustomer(hackedCustomer, user: manager);
    final afterManagerMaps = await db.query('customers', where: 'id = ?', whereArgs: [testCustId]);
    final managerLimit = (afterManagerMaps.first['credit_limit'] as num).toDouble();
    print('-> نجاح عملية المدير: السقف الجديد المخزن أصبح $managerLimit ج.س');
    expect(managerLimit, 500000.0);

    // =========================================================================
    // 3. اختبار محاولة المحاسب إضافة مورد جديد
    // =========================================================================
    print('\n================================================================');
    print('3. تجربة اختراق: محاولة المحاسب إضافة مورد جديد');
    print('================================================================');
    final supplierName = 'شركة وقود غير مصرحة ${DateTime.now().microsecondsSinceEpoch}';
    final illegalSupplier = SupplierModel(
      name: supplierName,
      phone: '0123456789',
    );
    print('-> يقوم المحاسب بمحاولة استدعاء addSupplier...');
    bool supplierBlocked = false;
    try {
      await deliveryRepo.addSupplier(illegalSupplier, user: accountant);
    } on UnauthorizedException catch (e) {
      supplierBlocked = true;
      print('-> 🛑 رفض أمني صارم من الـ Repository: $e');
    }
    expect(supplierBlocked, isTrue);

    // التأكد من عدم وجود المورد في قاعدة البيانات
    final supMaps = await db.query('suppliers', where: 'name = ?', whereArgs: [supplierName]);
    expect(supMaps.isEmpty, isTrue);
    print('-> فحص قاعدة البيانات المباشر: لم يتم إدراج المورد في جدول suppliers.');

    // المدير يضيف المورد بنجاح
    print('-> يقوم مدير المحطة بإضافة نفس المورد...');
    final supId = await deliveryRepo.addSupplier(illegalSupplier, user: manager);
    expect(supId, greaterThan(0));
    print('-> نجاح عملية المدير: تم حفظ المورد برقم ID: #$supId');

    // =========================================================================
    // 4. اختبار محاولة المحاسب تعديل رصيد الخزنة يدوياً
    // =========================================================================
    print('\n================================================================');
    print('4. تجربة اختراق: محاولة المحاسب تعديل الخزنة يدوياً');
    print('================================================================');
    bool cashBoxBlocked = false;
    try {
      await cashBoxRepo.updateTodayCashBox(
        cashInDelta: 50000.0,
        cashOutDelta: 0.0,
        notes: 'محاولة تعديل يدوي من المحاسب',
        user: accountant,
      );
    } on UnauthorizedException catch (e) {
      cashBoxBlocked = true;
      print('-> 🛑 رفض أمني صارم من الـ Repository: $e');
    }
    expect(cashBoxBlocked, isTrue);
    print('-> تم منع المحاسب من التعديل اليدوي على رصيد الخزنة.');

    print('\n================================================================');
    print('✅ تم تأكيد عمل نظام RBAC بنجاح على مستوى الواجهة والـ Repository');
    print('================================================================\n');
  });
}
