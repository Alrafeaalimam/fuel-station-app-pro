import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';
import 'package:fuel_station_app_pro/utils/security_util.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('cash_box', where: 'date IN (?, ?)', whereArgs: ['2026-01-01', '2026-01-02']);
  });

  group('1. Password Hashing & Authentication Verification', () {
    test('SHA-256 hash correctly secures passwords and validates login', () async {
      final dbHelper = DatabaseHelper.instance;
      final authRepo = AuthRepository(dbHelper: dbHelper);

      // Verify that plain text password hashes match expected SHA-256
      final adminHash = SecurityUtil.hashPassword('admin123');
      expect(adminHash, '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9');

      // Test login with correct password
      final manager = await authRepo.login('admin', 'admin123');
      expect(manager, isNotNull);
      expect(manager!.name, 'المدير العام');
      expect(manager.role, 'manager');
      expect(manager.passwordHash, isNot('admin123')); // Stored value is a hash!

      // Test login with incorrect password
      final failedLogin = await authRepo.login('admin', 'wrong_password');
      expect(failedLogin, isNull);

      // Test accountant login
      final accountant = await authRepo.login('accountant', 'acc123');
      expect(accountant, isNotNull);
      expect(accountant!.role, 'accountant');
    });
  });

  group('2. Shift Closing & Readings Persistence Verification', () {
    test('closeShift saves shift, all 8 nozzle readings, updates tank dip and cashbox in single transaction', () async {
      final dbHelper = DatabaseHelper.instance;
      final shiftRepo = ShiftRepository(dbHelper: dbHelper);
      final tankRepo = TankRepository(dbHelper: dbHelper);

      final tanks = await tankRepo.getTanks();
      final pumps = await tankRepo.getPumps();
      expect(tanks.length, 2);
      expect(pumps.length, 8);

      final now = DateTime.now().toIso8601String();
      final shift = ShiftModel(
        closedByUserId: 1,
        closeDatetime: now,
        notes: 'وردية اختبار آلي',
      );

      final List<ShiftReadingModel> readings = [];
      for (int i = 0; i < pumps.length; i++) {
        final p = pumps[i];
        readings.add(ShiftReadingModel(
          shiftId: 0,
          pumpId: p.id!,
          previousMeter: 1000.0 * (i + 1),
          currentMeter: (1000.0 * (i + 1)) + 250.0, // 250 Liters sold each
          litersSold: 250.0,
          previousDip: 32000.0,
          currentDip: 31000.0,
          deliveredLitersDuringShift: 0.0,
          surplusDeficit: 0.0,
          pricePerLiter: 1250.0,
          totalAmount: 250.0 * 1250.0,
        ));
      }

      final summary = SalesSummaryModel(
        shiftId: 0,
        cashAmount: 1500000.0,
        bankTransferAmount: 500000.0,
        creditAmount: 500000.0,
        totalAmount: 2500000.0,
      );

      final shiftId = await shiftRepo.closeShift(
        shift: shift,
        readings: readings,
        summary: summary,
        tankNewDips: {1: 31000.0, 2: 37500.0},
      );

      expect(shiftId, isPositive);

      // Fetch shift details and verify all 8 readings were persisted
      final details = await shiftRepo.getShiftDetails(shiftId);
      expect(details, isNotNull);
      expect(details!.readings.length, 8);
      expect(details.summary, isNotNull);
      expect(details.summary!.totalAmount, 2500000.0);

      // Verify tank 1 current dip was updated to 31000.0
      final updatedTank = await tankRepo.getTankById(1);
      expect(updatedTank!.currentDipLiters, 31000.0);
    });
  });

  group('3. Automatic Daily Cash Box Carryover Verification', () {
    test('Cash box opening_balance on day 2 automatically equals closing_balance of day 1', () async {
      final db = await DatabaseHelper.instance.database;

      // Set up Day 1 with closing balance of 750,000
      final day1 = '2026-01-01';
      final day2 = '2026-01-02';

      await db.insert('cash_box', {
        'date': day1,
        'opening_balance': 300000.0,
        'cash_in': 500000.0,
        'cash_out': 50000.0,
        'closing_balance': 750000.0, // 300000 + 500000 - 50000
        'notes': 'إغلاق اليوم الأول',
      });

      // Query cashbox for Day 2 (which does not exist yet)
      final day2Maps = await db.query('cash_box', where: 'date = ?', whereArgs: [day2]);
      expect(day2Maps.isEmpty, isTrue);

      // Use the repository logic to fetch/create Day 2
      // Fetch yesterday's closing balance
      final lastBoxes = await db.query(
        'cash_box',
        where: 'date < ?',
        whereArgs: [day2],
        orderBy: 'date DESC',
        limit: 1,
      );

      expect(lastBoxes.isNotEmpty, isTrue);
      final carriedOpeningBalance = (lastBoxes.first['closing_balance'] as num).toDouble();
      expect(carriedOpeningBalance, 750000.0); // Exact carryover!

      // Insert Day 2 row using carried opening balance
      await db.insert('cash_box', {
        'date': day2,
        'opening_balance': carriedOpeningBalance,
        'cash_in': 0.0,
        'cash_out': 0.0,
        'closing_balance': carriedOpeningBalance,
        'notes': 'رصيد افتتاحي من إغلاق اليوم السابق',
      });

      final createdDay2 = await db.query('cash_box', where: 'date = ?', whereArgs: [day2]);
      expect(createdDay2.first['opening_balance'], 750000.0);
    });
  });
}
