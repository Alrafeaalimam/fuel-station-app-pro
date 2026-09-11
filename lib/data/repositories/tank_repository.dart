import '../database_helper.dart';
import '../../models/models.dart';
import '../../utils/permission_guard.dart';

class TankRepository {
  final DatabaseHelper dbHelper;

  TankRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<TankModel>> getTanks() async {
    final db = await dbHelper.database;
    final maps = await db.query('tanks', orderBy: 'id ASC');
    return maps.map((e) => TankModel.fromMap(e)).toList();
  }

  Future<TankModel?> getTankById(int id) async {
    final db = await dbHelper.database;
    final maps = await db.query('tanks', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return TankModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<PumpModel>> getPumps() async {
    final db = await dbHelper.database;
    final maps = await db.query('pumps', orderBy: 'nozzle_number ASC');
    return maps.map((e) => PumpModel.fromMap(e)).toList();
  }

  Future<List<PumpModel>> getPumpsForTank(int tankId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'pumps',
      where: 'tank_id = ?',
      whereArgs: [tankId],
      orderBy: 'nozzle_number ASC',
    );
    return maps.map((e) => PumpModel.fromMap(e)).toList();
  }

  Future<void> updateTankDip(int tankId, double newDipLiters) async {
    final db = await dbHelper.database;
    await db.update(
      'tanks',
      {'current_dip_liters': newDipLiters},
      where: 'id = ?',
      whereArgs: [tankId],
    );
  }

  Future<void> updateTankCapacity(int tankId, double capacityLiters, {UserModel? user}) async {
    PermissionGuard.check(user, AppPermission.manageTanks);
    if (capacityLiters < 0) {
      throw ArgumentError('سعة الخزان يجب ألا تكون سالبة');
    }
    final db = await dbHelper.database;
    await db.update(
      'tanks',
      {'capacity_liters': capacityLiters},
      where: 'id = ?',
      whereArgs: [tankId],
    );
  }
}
