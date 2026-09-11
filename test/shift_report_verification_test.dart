import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('ShiftReportFullData computes all 5 Sudanese daily sheet sections accurately with real DB records', () async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final shiftRepo = ShiftRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);

    final tanks = await tankRepo.getTanks();
    final pumps = await tankRepo.getPumps();
    expect(tanks.length, 2);
    expect(pumps.length, 8);

    final benzinTank = tanks.firstWhere((t) => t.fuelType == 'بنزين');
    final dieselTank = tanks.firstWhere((t) => t.fuelType == 'جازولين');

    // 1. Prepare readings for 8 nozzles
    // Benzin nozzles (1 to 4): 100, 150, 200, 250 liters @ 1,250 = 700L, 875,000 SDG
    // Diesel nozzles (5 to 8): 300, 200, 150, 350 liters @ 1,150 = 1000L, 1,150,000 SDG
    final now = DateTime.now().toIso8601String();

    final shift = ShiftModel(
      closedByUserId: 1,
      closeDatetime: now,
      status: 'closed',
      notes: 'وردية نموذج اليومية السوداني المطبوع',
    );

    final List<ShiftReadingModel> readings = [];
    // Benzin pumps
    final benzinLiters = [100.0, 150.0, 200.0, 250.0];
    for (int i = 0; i < 4; i++) {
      final p = pumps[i];
      final sold = benzinLiters[i];
      readings.add(ShiftReadingModel(
        shiftId: 0,
        pumpId: p.id!,
        previousMeter: 1000.0 * (i + 1),
        currentMeter: (1000.0 * (i + 1)) + sold,
        litersSold: sold,
        previousDip: 30000.0,
        currentDip: 29300.0,
        deliveredLitersDuringShift: 0.0,
        surplusDeficit: 0.0,
        pricePerLiter: 1250.0,
        totalAmount: sold * 1250.0,
      ));
    }

    // Diesel pumps
    final dieselLiters = [300.0, 200.0, 150.0, 350.0];
    for (int i = 0; i < 4; i++) {
      final p = pumps[i + 4];
      final sold = dieselLiters[i];
      readings.add(ShiftReadingModel(
        shiftId: 0,
        pumpId: p.id!,
        previousMeter: 5000.0 * (i + 1),
        currentMeter: (5000.0 * (i + 1)) + sold,
        litersSold: sold,
        previousDip: 35000.0,
        currentDip: 34000.0,
        deliveredLitersDuringShift: 0.0,
        surplusDeficit: 0.0,
        pricePerLiter: 1150.0,
        totalAmount: sold * 1150.0,
      ));
    }

    final totalMetersAmount = 875000.0 + 1150000.0; // 2,025,000 SDG
    final summary = SalesSummaryModel(
      shiftId: 0,
      cashAmount: 1025000.0,
      bankTransferAmount: 800000.0,
      creditAmount: 200000.0,
      totalAmount: totalMetersAmount,
    );

    // Insert an expense for today to verify Section 5 (المنصرف والصافي)
    await db.insert('expenses', {
      'date': now,
      'category': 'صيانة',
      'amount': 25000.0,
      'description': 'صيانة مسدس فوهة رقم 2',
      'recorded_by_user_id': 1,
    });

    final shiftId = await shiftRepo.closeShift(
      shift: shift,
      readings: readings,
      summary: summary,
      tankNewDips: {
        benzinTank.id!: 29300.0,
        dieselTank.id!: 34000.0,
      },
    );

    expect(shiftId, greaterThan(0));

    // 2. Fetch and test getShiftReportFullData
    final reportData = await shiftRepo.getShiftReportFullData(shiftId);
    expect(reportData, isNotNull);

    // Section 1: Header (ترويسة)
    expect(reportData!.benzinPrice, 1250.0);
    expect(reportData.dieselPrice, 1150.0);
    expect(reportData.shift.id, shiftId);
    expect(reportData.closedByUser?.name, 'المدير العام');

    // Section 2: Tanks Dip (جدول قياس المسطرة للخزانات)
    expect(reportData.benzinTank, isNotNull);
    expect(reportData.benzinTank!.previousDip, 30000.0);
    expect(reportData.benzinTank!.delivered, 0.0);
    expect(reportData.benzinTank!.currentDip, 29300.0);
    expect(reportData.benzinTank!.metersSold, 700.0);
    expect(reportData.benzinTank!.diffLiters, 0.0); // Exact match
    expect(reportData.benzinTank!.diffGallons, 0.0);

    expect(reportData.dieselTank, isNotNull);
    expect(reportData.dieselTank!.previousDip, 35000.0);
    expect(reportData.dieselTank!.delivered, 0.0);
    expect(reportData.dieselTank!.currentDip, 34000.0);
    expect(reportData.dieselTank!.metersSold, 1000.0);
    expect(reportData.dieselTank!.diffLiters, 0.0);
    expect(reportData.dieselTank!.diffGallons, 0.0);

    // Section 3: Meters Table (جدول العدادات)
    // 4 Benzin pumps
    expect(reportData.benzinPumps.length, 4);
    expect(reportData.benzinPumps[0].reading.litersSold, 100.0);
    expect(reportData.benzinPumps[0].reading.totalAmount, 125000.0);
    expect(reportData.benzinPumps[1].reading.litersSold, 150.0);
    expect(reportData.benzinPumps[1].reading.totalAmount, 187500.0);
    expect(reportData.benzinPumps[2].reading.litersSold, 200.0);
    expect(reportData.benzinPumps[2].reading.totalAmount, 250000.0);
    expect(reportData.benzinPumps[3].reading.litersSold, 250.0);
    expect(reportData.benzinPumps[3].reading.totalAmount, 312500.0);
    expect(reportData.totalBenzinLiters, 700.0);
    expect(reportData.totalBenzinAmount, 875000.0);

    // 4 Diesel pumps
    expect(reportData.dieselPumps.length, 4);
    expect(reportData.dieselPumps[0].reading.litersSold, 300.0);
    expect(reportData.dieselPumps[0].reading.totalAmount, 345000.0);
    expect(reportData.dieselPumps[1].reading.litersSold, 200.0);
    expect(reportData.dieselPumps[1].reading.totalAmount, 230000.0);
    expect(reportData.dieselPumps[2].reading.litersSold, 150.0);
    expect(reportData.dieselPumps[2].reading.totalAmount, 172500.0);
    expect(reportData.dieselPumps[3].reading.litersSold, 350.0);
    expect(reportData.dieselPumps[3].reading.totalAmount, 402500.0);
    expect(reportData.totalDieselLiters, 1000.0);
    expect(reportData.totalDieselAmount, 1150000.0);

    // Grand total
    expect(reportData.totalMetersLiters, 1700.0);
    expect(reportData.totalMetersAmount, 2025000.0);

    // Section 4: Financial breakdown (التحويلات المالية)
    expect(reportData.bankMorning, 400000.0);
    expect(reportData.bankEvening, 400000.0);
    expect(reportData.cashAmount, 1025000.0);
    expect(reportData.creditAmount, 200000.0);
    expect(reportData.totalFinancialRevenue, 2025000.0);
    expect(reportData.remainingDeliveries, 0.0); // No remaining / fully matched

    // Section 5: Summary & Sign-off (الخلاصة وتوقيع مدير المحطة)
    expect(reportData.totalExpenses, greaterThanOrEqualTo(25000.0));
    expect(reportData.netAmount, reportData.totalMetersAmount - reportData.totalExpenses);
    expect(reportData.netAmount, 2025000.0 - reportData.totalExpenses);
  });
}
