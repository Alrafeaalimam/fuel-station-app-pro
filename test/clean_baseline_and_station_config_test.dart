import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/config/station_config.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/fuel_price_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/cash_box_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/customer_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/delivery_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<DatabaseHelper> createFreshDbHelper() async {
    final inMemoryDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => DatabaseHelper.instance.createDBForTesting(db),
      ),
    );
    return DatabaseHelper.withDatabase(inMemoryDb);
  }

  test('Clean Initial Baseline Data Verification on pristine database', () async {
    final dbHelper = await createFreshDbHelper();
    final db = await dbHelper.database;

    // 1. Verify Users (only admin and accountant)
    final authRepo = AuthRepository(dbHelper: dbHelper);
    final admin = await authRepo.login('admin', 'admin123');
    expect(admin, isNotNull);
    expect(admin!.isManager, isTrue);

    final accountant = await authRepo.login('accountant', 'acc123');
    expect(accountant, isNotNull);
    expect(accountant!.isAccountant, isTrue);

    final userCount = (await db.query('users')).length;
    expect(userCount, equals(2));

    // 2. Verify Zero Suppliers and Zero Customers
    final customerRepo = CustomerRepository(dbHelper: dbHelper);
    final customers = await customerRepo.getCustomers();
    expect(customers.isEmpty, isTrue, reason: 'Must have zero mock customers');

    final deliveryRepo = DeliveryRepository(dbHelper: dbHelper);
    final suppliers = await deliveryRepo.getSuppliers();
    expect(suppliers.isEmpty, isTrue, reason: 'Must have zero mock suppliers');

    // 3. Verify 2 Tanks with 0.0 dip and 0.0 capacity
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final tanks = await tankRepo.getTanks();
    expect(tanks.length, equals(2));
    for (final t in tanks) {
      expect(t.currentDipLiters, equals(0.0));
      expect(t.capacityLiters, equals(0.0));
      expect(t.fillPercentage, equals(0.0));
    }

    // 4. Verify 8 Pumps (4 for Benzin, 4 for Diesel)
    final pumps = await tankRepo.getPumps();
    expect(pumps.length, equals(8));

    // 5. Verify Fuel Prices are 0.0
    final priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    final benzinPrice = await priceRepo.getActivePrice('بنزين');
    expect(benzinPrice, isNotNull);
    expect(benzinPrice!.pricePerLiter, equals(0.0));

    final dieselPrice = await priceRepo.getActivePrice('جازولين');
    expect(dieselPrice, isNotNull);
    expect(dieselPrice!.pricePerLiter, equals(0.0));

    // 6. Verify Cash Box has 0.0 balance for today
    final cashRepo = CashBoxRepository(dbHelper: dbHelper);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayCash = await cashRepo.getCashBoxForDate(today);
    expect(todayCash, isNotNull);
    expect(todayCash!.openingBalance, equals(0.0));
    expect(todayCash.closingBalance, equals(0.0));
  });

  test('StationConfig loads, persists in DB and updates reactively', () async {
    final dbHelper = await createFreshDbHelper();

    // 1. Initial load from fresh DB
    await StationConfig.loadStationName(dbHelper: dbHelper);
    expect(StationConfig.stationName, equals('محطة الوقود النموذجية'));

    // 2. Change station name
    const newStationName = 'محطة النور للخدمات البترولية';
    await StationConfig.setStationName(newStationName, dbHelper: dbHelper);
    expect(StationConfig.stationName, equals(newStationName));
    expect(StationConfig.stationNameNotifier.value, equals(newStationName));

    // 3. Verify in SQLite settings table directly
    final db = await dbHelper.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: ['station_name']);
    expect(rows.isNotEmpty, isTrue);
    expect(rows.first['value'], equals(newStationName));

    // 4. Simulate reload from DB
    StationConfig.stationNameNotifier.value = 'محطة الوقود النموذجية';
    await StationConfig.loadStationName(dbHelper: dbHelper);
    expect(StationConfig.stationName, equals(newStationName));

    // Reset to default for other tests
    StationConfig.stationNameNotifier.value = 'محطة الوقود النموذجية';
  });

  test('DeliveryRepository updates tank dip even when initial capacity is 0.0', () async {
    final dbHelper = await createFreshDbHelper();
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final deliveryRepo = DeliveryRepository(dbHelper: dbHelper);

    final tanks = await tankRepo.getTanks();
    final benzinTank = tanks.firstWhere((t) => t.fuelType == 'بنزين');
    final initialDip = benzinTank.currentDipLiters;

    // Record delivery
    final delivery = DeliveryModel(
      supplierId: 1,
      tankId: benzinTank.id!,
      liters: 10000.0,
      costPerLiter: 1150.0,
      totalCost: 11500000.0,
      deliveredAt: DateTime.now().toIso8601String(),
      recordedByUserId: 1,
    );

    await deliveryRepo.recordDelivery(delivery);

    // Verify tank dip increased by 10,000 without being clamped to 0.0
    final updatedTanks = await tankRepo.getTanks();
    final updatedBenzin = updatedTanks.firstWhere((t) => t.id == benzinTank.id);
    expect(updatedBenzin.currentDipLiters, equals(initialDip + 10000.0));
  });
}
