import '../database_helper.dart';
import '../../models/models.dart';
import 'backup_repository.dart';

class ShiftDetails {
  final ShiftModel shift;
  final List<ShiftReadingModel> readings;
  final SalesSummaryModel? summary;
  final UserModel? closedByUser;

  const ShiftDetails({
    required this.shift,
    required this.readings,
    this.summary,
    this.closedByUser,
  });
}

class ShiftPumpRowData {
  final PumpModel pump;
  final ShiftReadingModel reading;
  final TankModel tank;

  const ShiftPumpRowData({
    required this.pump,
    required this.reading,
    required this.tank,
  });
}

class TankReportData {
  final TankModel tank;
  final double previousDip;
  final double delivered;
  final double currentDip;
  final double metersSold;
  final double diffLiters;
  final double diffGallons;

  const TankReportData({
    required this.tank,
    required this.previousDip,
    required this.delivered,
    required this.currentDip,
    required this.metersSold,
    required this.diffLiters,
    required this.diffGallons,
  });
}

class ShiftReportFullData {
  final ShiftModel shift;
  final UserModel? closedByUser;
  final SalesSummaryModel? summary;
  final List<ShiftPumpRowData> benzinPumps;
  final List<ShiftPumpRowData> dieselPumps;
  final TankReportData? benzinTank;
  final TankReportData? dieselTank;
  final double benzinPrice;
  final double dieselPrice;
  final double totalBenzinLiters;
  final double totalBenzinAmount;
  final double totalDieselLiters;
  final double totalDieselAmount;
  final double totalMetersLiters;
  final double totalMetersAmount;
  final double bankMorning;
  final double bankEvening;
  final double cashAmount;
  final double creditAmount;
  final double totalFinancialRevenue;
  final double remainingDeliveries;
  final double totalExpenses;
  final double netAmount;

  const ShiftReportFullData({
    required this.shift,
    this.closedByUser,
    this.summary,
    required this.benzinPumps,
    required this.dieselPumps,
    this.benzinTank,
    this.dieselTank,
    required this.benzinPrice,
    required this.dieselPrice,
    required this.totalBenzinLiters,
    required this.totalBenzinAmount,
    required this.totalDieselLiters,
    required this.totalDieselAmount,
    required this.totalMetersLiters,
    required this.totalMetersAmount,
    required this.bankMorning,
    required this.bankEvening,
    required this.cashAmount,
    required this.creditAmount,
    required this.totalFinancialRevenue,
    required this.remainingDeliveries,
    required this.totalExpenses,
    required this.netAmount,
  });
}

class ShiftRepository {
  final DatabaseHelper dbHelper;
  final BackupRepository backupRepo;

  ShiftRepository({DatabaseHelper? dbHelper, BackupRepository? backupRepo})
      : dbHelper = dbHelper ?? DatabaseHelper.instance,
        backupRepo = backupRepo ?? BackupRepository(dbHelper: dbHelper ?? DatabaseHelper.instance);

  Future<ShiftModel?> getLastClosedShift() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'shifts',
      where: 'status = ?',
      whereArgs: ['closed'],
      orderBy: 'close_datetime DESC, id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ShiftModel.fromMap(maps.first);
    }
    return null;
  }

  Future<double> getLastMeterForPump(int pumpId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'shift_readings',
      where: 'pump_id = ?',
      whereArgs: [pumpId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return (maps.first['current_meter'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  Future<double> getLastDipForTank(int tankId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'tanks',
      where: 'id = ?',
      whereArgs: [tankId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return (maps.first['current_dip_liters'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  Future<double> getDeliveredSince(int tankId, String? lastCloseDatetime) async {
    final db = await dbHelper.database;
    if (lastCloseDatetime == null) {
      return 0.0;
    }
    final result = await db.rawQuery(
      '''
      SELECT SUM(liters) as total_delivered 
      FROM deliveries 
      WHERE tank_id = ? AND delivered_at > ?
    ''',
      [tankId, lastCloseDatetime],
    );

    if (result.isNotEmpty && result.first['total_delivered'] != null) {
      return (result.first['total_delivered'] as num).toDouble();
    }
    return 0.0;
  }

  Future<List<ShiftModel>> getAllShifts() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'shifts',
      orderBy: 'close_datetime DESC, id DESC',
    );
    return maps.map((e) => ShiftModel.fromMap(e)).toList();
  }

  Future<ShiftDetails?> getShiftDetails(int shiftId) async {
    final db = await dbHelper.database;
    final shiftMaps = await db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
    );
    if (shiftMaps.isEmpty) return null;

    final shift = ShiftModel.fromMap(shiftMaps.first);

    final readingsMaps = await db.query(
      'shift_readings',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      orderBy: 'pump_id ASC',
    );
    final readings = readingsMaps.map((e) => ShiftReadingModel.fromMap(e)).toList();

    final summaryMaps = await db.query(
      'sales_summary',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
    );
    final summary = summaryMaps.isNotEmpty
        ? SalesSummaryModel.fromMap(summaryMaps.first)
        : null;

    final userMaps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [shift.closedByUserId],
    );
    final user = userMaps.isNotEmpty ? UserModel.fromMap(userMaps.first) : null;

    return ShiftDetails(
      shift: shift,
      readings: readings,
      summary: summary,
      closedByUser: user,
    );
  }

  Future<int> closeShift({
    required ShiftModel shift,
    required List<ShiftReadingModel> readings,
    required SalesSummaryModel summary,
    Map<int, double>? tankNewDips, // tankId -> currentDip
    List<CreditTransactionModel>? creditTransactions,
  }) async {
    final db = await dbHelper.database;
    final today = shift.closeDatetime.substring(0, 10);

    final completedShiftId = await db.transaction<int>((txn) async {
      // 1. Insert shift
      final shiftId = await txn.insert('shifts', shift.toMap());

      // 2. Insert readings
      for (final reading in readings) {
        final r = reading.copyWith(shiftId: shiftId);
        await txn.insert('shift_readings', r.toMap());
      }

      // 3. Insert sales summary
      final s = summary.copyWith(shiftId: shiftId);
      await txn.insert('sales_summary', s.toMap());

      // 4. Update tanks' current dip
      if (tankNewDips != null) {
        for (final entry in tankNewDips.entries) {
          await txn.update(
            'tanks',
            {'current_dip_liters': entry.value},
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
      }

      // 5. Insert credit transactions & update customer balances
      if (creditTransactions != null) {
        for (final txnItem in creditTransactions) {
          final cTxn = txnItem.copyWith(shiftId: shiftId);
          await txn.insert('credit_transactions', cTxn.toMap());

          // Increase customer balance for charge
          if (cTxn.isCharge) {
            final custMaps = await txn.query(
              'customers',
              where: 'id = ?',
              whereArgs: [cTxn.customerId],
            );
            if (custMaps.isNotEmpty) {
              final bal = (custMaps.first['current_balance'] as num?)?.toDouble() ?? 0.0;
              await txn.update(
                'customers',
                {'current_balance': bal + cTxn.amount},
                where: 'id = ?',
                whereArgs: [cTxn.customerId],
              );
            }
          }
        }
      }

      // 6. Update Daily Cash Box with shift cash sales
      final cashSales = summary.cashAmount;
      if (cashSales > 0) {
        final boxMaps = await txn.query('cash_box', where: 'date = ?', whereArgs: [today]);
        if (boxMaps.isNotEmpty) {
          final box = boxMaps.first;
          final cashIn = (box['cash_in'] as num?)?.toDouble() ?? 0.0;
          final closing = (box['closing_balance'] as num?)?.toDouble() ?? 0.0;
          await txn.update(
            'cash_box',
            {
              'cash_in': cashIn + cashSales,
              'closing_balance': closing + cashSales,
            },
            where: 'date = ?',
            whereArgs: [today],
          );
        } else {
          final lastBoxes = await txn.query('cash_box', orderBy: 'date DESC', limit: 1);
          final opening = lastBoxes.isNotEmpty
              ? ((lastBoxes.first['closing_balance'] as num?)?.toDouble() ?? 0.0)
              : 0.0;
          await txn.insert('cash_box', {
            'date': today,
            'opening_balance': opening,
            'cash_in': cashSales,
            'cash_out': 0.0,
            'closing_balance': opening + cashSales,
            'notes': 'مبيعات نقدية من وردية #$shiftId',
          });
        }
      }

      return shiftId;
    });

    // Automatic backup upon successful shift close (silent and resilient)
    try {
      await backupRepo.createAutomaticBackup().timeout(const Duration(seconds: 5));
    } catch (_) {}

    return completedShiftId;
  }

  Future<ShiftReportFullData?> getShiftReportFullData(int shiftId) async {
    final db = await dbHelper.database;
    final shiftMaps = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
    if (shiftMaps.isEmpty) return null;
    final shift = ShiftModel.fromMap(shiftMaps.first);

    final userMaps = await db.query('users', where: 'id = ?', whereArgs: [shift.closedByUserId]);
    final closedByUser = userMaps.isNotEmpty ? UserModel.fromMap(userMaps.first) : null;

    final summaryMaps = await db.query('sales_summary', where: 'shift_id = ?', whereArgs: [shiftId]);
    final summary = summaryMaps.isNotEmpty ? SalesSummaryModel.fromMap(summaryMaps.first) : null;

    final readingsMaps = await db.query(
      'shift_readings',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      orderBy: 'pump_id ASC',
    );
    final readings = readingsMaps.map((e) => ShiftReadingModel.fromMap(e)).toList();

    final pumpMaps = await db.query('pumps', orderBy: 'nozzle_number ASC');
    final pumps = pumpMaps.map((e) => PumpModel.fromMap(e)).toList();
    final pumpMap = {for (var p in pumps) p.id!: p};

    final tankMaps = await db.query('tanks');
    final tanks = tankMaps.map((e) => TankModel.fromMap(e)).toList();
    final tankMap = {for (var t in tanks) t.id!: t};

    final List<ShiftPumpRowData> benzinPumps = [];
    final List<ShiftPumpRowData> dieselPumps = [];

    double totalBenzinLiters = 0.0;
    double totalBenzinAmount = 0.0;
    double totalDieselLiters = 0.0;
    double totalDieselAmount = 0.0;

    double benzinPrice = 0.0;
    double dieselPrice = 0.0;

    for (final r in readings) {
      final pump = pumpMap[r.pumpId] ??
          PumpModel(name: 'فوهة #${r.pumpId}', tankId: 1, nozzleNumber: r.pumpId);
      final tank = tankMap[pump.tankId] ??
          (tanks.isNotEmpty
              ? tanks.first
              : const TankModel(name: '', fuelType: '', capacityLiters: 0, currentDipLiters: 0));
      final row = ShiftPumpRowData(pump: pump, reading: r, tank: tank);

      if (tank.fuelType == 'بنزين') {
        benzinPumps.add(row);
        totalBenzinLiters += r.litersSold;
        totalBenzinAmount += r.totalAmount;
        benzinPrice = r.pricePerLiter;
      } else {
        dieselPumps.add(row);
        totalDieselLiters += r.litersSold;
        totalDieselAmount += r.totalAmount;
        dieselPrice = r.pricePerLiter;
      }
    }

    if (benzinPrice == 0.0) benzinPrice = 1250.0;
    if (dieselPrice == 0.0) dieselPrice = 1150.0;

    TankReportData? benzinTankData;
    TankReportData? dieselTankData;

    final benzinTankModel = tanks.where((t) => t.fuelType == 'بنزين').firstOrNull;
    if (benzinTankModel != null && benzinPumps.isNotEmpty) {
      final firstR = benzinPumps.first.reading;
      final drawn = (firstR.previousDip + firstR.deliveredLitersDuringShift - firstR.currentDip);
      final diffL = totalBenzinLiters - drawn;
      benzinTankData = TankReportData(
        tank: benzinTankModel,
        previousDip: firstR.previousDip,
        delivered: firstR.deliveredLitersDuringShift,
        currentDip: firstR.currentDip,
        metersSold: totalBenzinLiters,
        diffLiters: diffL,
        diffGallons: diffL / 4.54609,
      );
    }

    final dieselTankModel = tanks.where((t) => t.fuelType == 'جازولين').firstOrNull;
    if (dieselTankModel != null && dieselPumps.isNotEmpty) {
      final firstR = dieselPumps.first.reading;
      final drawn = (firstR.previousDip + firstR.deliveredLitersDuringShift - firstR.currentDip);
      final diffL = totalDieselLiters - drawn;
      dieselTankData = TankReportData(
        tank: dieselTankModel,
        previousDip: firstR.previousDip,
        delivered: firstR.deliveredLitersDuringShift,
        currentDip: firstR.currentDip,
        metersSold: totalDieselLiters,
        diffLiters: diffL,
        diffGallons: diffL / 4.54609,
      );
    }

    final totalMetersLiters = totalBenzinLiters + totalDieselLiters;
    final totalMetersAmount = totalBenzinAmount + totalDieselAmount;

    final cashAmount = summary?.cashAmount ?? 0.0;
    final bankTotal = summary?.bankTransferAmount ?? 0.0;
    final creditAmount = summary?.creditAmount ?? 0.0;
    final totalFinancialRevenue = summary?.totalAmount ?? (cashAmount + bankTotal + creditAmount);

    final bankMorning = bankTotal > 0 ? (bankTotal * 0.5) : 0.0;
    final bankEvening = bankTotal > 0 ? (bankTotal * 0.5) : 0.0;
    final remainingDeliveries = totalMetersAmount - totalFinancialRevenue;

    final shiftDate = shift.closeDatetime.substring(0, 10);
    final expenseMaps =
        await db.query('expenses', where: 'date LIKE ?', whereArgs: ['$shiftDate%']);
    double totalExpenses = 0.0;
    for (final em in expenseMaps) {
      totalExpenses += (em['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final netAmount = totalMetersAmount - totalExpenses;

    return ShiftReportFullData(
      shift: shift,
      closedByUser: closedByUser,
      summary: summary,
      benzinPumps: benzinPumps,
      dieselPumps: dieselPumps,
      benzinTank: benzinTankData,
      dieselTank: dieselTankData,
      benzinPrice: benzinPrice,
      dieselPrice: dieselPrice,
      totalBenzinLiters: totalBenzinLiters,
      totalBenzinAmount: totalBenzinAmount,
      totalDieselLiters: totalDieselLiters,
      totalDieselAmount: totalDieselAmount,
      totalMetersLiters: totalMetersLiters,
      totalMetersAmount: totalMetersAmount,
      bankMorning: bankMorning,
      bankEvening: bankEvening,
      cashAmount: cashAmount,
      creditAmount: creditAmount,
      totalFinancialRevenue: totalFinancialRevenue,
      remainingDeliveries: remainingDeliveries,
      totalExpenses: totalExpenses,
      netAmount: netAmount,
    );
  }
}
