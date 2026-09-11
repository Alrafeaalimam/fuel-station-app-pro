import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/permission_guard.dart';

class DeliveryRepository {
  final DatabaseHelper dbHelper;

  DeliveryRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<SupplierModel>> getSuppliers() async {
    final db = await dbHelper.database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((e) => SupplierModel.fromMap(e)).toList();
  }

  Future<int> addSupplier(SupplierModel supplier, {UserModel? user}) async {
    PermissionGuard.check(user, AppPermission.manageSuppliers);
    final db = await dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<DeliveryModel>> getDeliveries() async {
    final db = await dbHelper.database;
    final maps = await db.query('deliveries', orderBy: 'delivered_at DESC, id DESC');
    return maps.map((e) => DeliveryModel.fromMap(e)).toList();
  }

  Future<int> recordDelivery(DeliveryModel delivery) async {
    final db = await dbHelper.database;

    return await db.transaction((txn) async {
      final tankMaps = await txn.query('tanks', where: 'id = ?', whereArgs: [delivery.tankId]);
      if (tankMaps.isEmpty) {
        throw Exception('الخزان المحدد برقم #${delivery.tankId} غير موجود في قاعدة البيانات');
      }

      final currentDip = (tankMaps.first['current_dip_liters'] as num?)?.toDouble() ?? 0.0;
      final capacity = (tankMaps.first['capacity_liters'] as num?)?.toDouble() ?? 0.0;
      final newDip = currentDip + delivery.liters;

      if (capacity > 0 && newDip > capacity) {
        final nf = NumberFormat('#,##0', 'en_US');
        final maxAllowed = (capacity - currentDip).clamp(0.0, double.infinity);
        throw Exception(
          'لا يمكن تفريغ الشحنة! الكمية الإجمالية (${nf.format(newDip)} لتر) ستتجاوز سعة الخزان القصوى (${nf.format(capacity)} لتر).\n'
          'المخزون الحالي: ${nf.format(currentDip)} لتر، الشحنة: ${nf.format(delivery.liters)} لتر.\n'
          'الحد الأقصى المتاح للتفريغ في هذا الخزان: ${nf.format(maxAllowed)} لتر فقط.',
        );
      }

      // 1. Insert delivery record
      final id = await txn.insert('deliveries', delivery.toMap());

      // 2. Automatically update tank dip (+= liters)
      await txn.update(
        'tanks',
        {'current_dip_liters': newDip},
        where: 'id = ?',
        whereArgs: [delivery.tankId],
      );

      return id;
    });
  }
}
