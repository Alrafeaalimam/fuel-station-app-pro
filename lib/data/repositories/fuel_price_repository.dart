import '../database_helper.dart';
import '../../models/models.dart';

class FuelPriceRepository {
  final DatabaseHelper dbHelper;

  FuelPriceRepository({DatabaseHelper? dbHelper})
      : dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<FuelPriceModel?> getActivePrice(String fuelType) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'fuel_prices',
      where: 'fuel_type = ? AND effective_to IS NULL',
      whereArgs: [fuelType],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return FuelPriceModel.fromMap(maps.first);
    }
    return null;
  }

  Future<Map<String, FuelPriceModel>> getActivePrices() async {
    final benzin = await getActivePrice('بنزين');
    final diesel = await getActivePrice('جازولين');
    final Map<String, FuelPriceModel> result = {};
    if (benzin != null) result['بنزين'] = benzin;
    if (diesel != null) result['جازولين'] = diesel;
    return result;
  }

  Future<List<FuelPriceModel>> getAllPrices() async {
    final db = await dbHelper.database;
    final maps = await db.query('fuel_prices', orderBy: 'id DESC');
    return maps.map((e) => FuelPriceModel.fromMap(e)).toList();
  }

  Future<int> setNewPrice({
    required String fuelType,
    required double newPrice,
    int? userId,
  }) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      // 1. Close current active price
      await txn.update(
        'fuel_prices',
        {'effective_to': now},
        where: 'fuel_type = ? AND effective_to IS NULL',
        whereArgs: [fuelType],
      );

      // 2. Insert new price
      return await txn.insert('fuel_prices', {
        'fuel_type': fuelType,
        'price_per_liter': newPrice,
        'effective_from': now,
        'effective_to': null,
        'set_by_user_id': userId,
      });
    });
  }
}
