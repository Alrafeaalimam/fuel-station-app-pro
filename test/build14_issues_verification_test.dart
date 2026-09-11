import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/fuel_price_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/customer_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/report_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/delivery_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/backup_repository.dart';
import 'package:fuel_station_app_pro/bloc/shift/shift_bloc.dart';
import 'package:fuel_station_app_pro/bloc/shift/shift_event.dart';
import 'package:fuel_station_app_pro/bloc/shift/shift_state.dart';
import 'package:fuel_station_app_pro/bloc/reports/reports_bloc.dart';
import 'package:fuel_station_app_pro/bloc/reports/reports_event.dart';
import 'package:fuel_station_app_pro/bloc/reports/reports_state.dart';
import 'package:fuel_station_app_pro/bloc/auth/auth_bloc.dart';
import 'package:fuel_station_app_pro/bloc/auth/auth_state.dart';
import 'package:fuel_station_app_pro/bloc/tanks/tank_bloc.dart';
import 'package:fuel_station_app_pro/bloc/prices/fuel_price_bloc.dart';
import 'package:fuel_station_app_pro/bloc/cash_box/cash_box_bloc.dart';
import 'package:fuel_station_app_pro/bloc/customers/customer_bloc.dart';
import 'package:fuel_station_app_pro/bloc/deliveries/delivery_bloc.dart';
import 'package:fuel_station_app_pro/bloc/expenses/expense_bloc.dart';
import 'package:fuel_station_app_pro/data/repositories/cash_box_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/expense_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/utils/permission_guard.dart';
import 'package:fuel_station_app_pro/models/models.dart';
import 'package:fuel_station_app_pro/screens/main_navigation_shell.dart';
import 'package:fuel_station_app_pro/widgets/tank_level_card.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseHelper dbHelper;
  late ShiftRepository shiftRepo;
  late TankRepository tankRepo;
  late FuelPriceRepository priceRepo;
  late CustomerRepository customerRepo;
  late ReportRepository reportRepo;
  late DeliveryRepository deliveryRepo;
  late BackupRepository backupRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    dbHelper = DatabaseHelper.withDatabase(db);
    await dbHelper.createDBForTesting(db);

    backupRepo = BackupRepository(dbHelper: dbHelper);
    shiftRepo = ShiftRepository(dbHelper: dbHelper, backupRepo: backupRepo);
    tankRepo = TankRepository(dbHelper: dbHelper);
    priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    customerRepo = CustomerRepository(dbHelper: dbHelper);
    reportRepo = ReportRepository(dbHelper: dbHelper);
    deliveryRepo = DeliveryRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await db.close();
  });

  group('Problem 1: Shift Close -> History -> Financial Reports in Same Session Without Freeze', () {
    test('Consecutive shift closures never freeze BLoC, DB, or Reports in single session', () async {
      final shiftBloc = ShiftBloc(
        shiftRepository: shiftRepo,
        tankRepository: tankRepo,
        fuelPriceRepository: priceRepo,
        customerRepository: customerRepo,
      );

      final reportsBloc = ReportsBloc(reportRepository: reportRepo);

      // Verify clean initial state
      expect(shiftBloc.state.closeSuccess, isNull);
      expect(shiftBloc.state.historyStatus, ShiftHistoryStatus.initial);

      // -------------------------------------------------------------
      // SHIFT 1: Close shift, check history, check reports
      // -------------------------------------------------------------
      print('=== [TEST] Starting Shift 1 Lifecycle in Session ===');
      shiftBloc.add(LoadShiftClosingData());
      await Future.delayed(const Duration(milliseconds: 100));

      final shift1 = ShiftModel(
        closedByUserId: 1,
        closeDatetime: '2026-09-09T10:00:00',
        status: 'closed',
        notes: 'وردية صباحية 1',
      );
      final readings1 = [
        const ShiftReadingModel(
          shiftId: 0,
          pumpId: 1,
          previousMeter: 1000.0,
          currentMeter: 1200.0,
          litersSold: 200.0,
          previousDip: 10000.0,
          currentDip: 9800.0,
          deliveredLitersDuringShift: 0.0,
          surplusDeficit: 0.0,
          pricePerLiter: 1500.0,
          totalAmount: 300000.0,
        ),
      ];
      final summary1 = const SalesSummaryModel(
        shiftId: 0,
        cashAmount: 200000.0,
        bankTransferAmount: 100000.0,
        creditAmount: 0.0,
        totalAmount: 300000.0,
      );

      shiftBloc.add(SubmitCloseShiftRequested(
        shift: shift1,
        readings: readings1,
        summary: summary1,
        tankNewDips: {1: 9800.0},
      ));
      await Future.doWhile(() async {
        if (shiftBloc.state.closeSuccess != null || shiftBloc.state.submitErrorMessage != null) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        return true;
      }).timeout(const Duration(seconds: 5));

      expect(shiftBloc.state.closeSuccess, isNotNull);
      final shiftId1 = shiftBloc.state.closeSuccess!.shiftId;
      print('-> Shift 1 Closed Successfully with ID #$shiftId1');

      // Crucial: UI resets submission status to prevent infinite loop
      shiftBloc.add(ResetShiftCloseStatus());
      await Future.doWhile(() async {
        if (shiftBloc.state.closeSuccess == null) return false;
        await Future.delayed(const Duration(milliseconds: 20));
        return true;
      }).timeout(const Duration(seconds: 2));
      expect(shiftBloc.state.closeSuccess, isNull, reason: 'closeSuccess must be cleared');

      // Now load history in the same session
      shiftBloc.add(LoadShiftHistory());
      await Future.doWhile(() async {
        if (shiftBloc.state.historyStatus == ShiftHistoryStatus.loaded ||
            shiftBloc.state.historyStatus == ShiftHistoryStatus.error) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        return true;
      }).timeout(const Duration(seconds: 5));
      expect(shiftBloc.state.historyStatus, ShiftHistoryStatus.loaded);
      expect(shiftBloc.state.shifts.length, 1);
      print('-> Shift History Loaded cleanly with ${shiftBloc.state.shifts.length} record(s)');

      // Now load Financial Reports in the exact same session
      reportsBloc.add(const LoadFinancialSummaryReport());
      await Future.doWhile(() async {
        if (reportsBloc.state is ReportsSummaryLoaded || reportsBloc.state is ReportsError) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        return true;
      }).timeout(const Duration(seconds: 5));
      expect(reportsBloc.state, isA<ReportsSummaryLoaded>());
      final reportState1 = reportsBloc.state as ReportsSummaryLoaded;
      expect(reportState1.summary.totalSalesAmount, 300000.0);
      expect(reportState1.summary.totalSalesCash, 200000.0);
      expect(reportState1.summary.totalSalesBank, 100000.0);
      print('-> Financial Report Loaded cleanly in same session: total = ${reportState1.summary.totalSalesAmount} SDG');

      // -------------------------------------------------------------
      // SHIFT 2: Immediately close another shift in the same session
      // -------------------------------------------------------------
      print('=== [TEST] Starting Shift 2 in Same Session Without App Restart ===');
      shiftBloc.add(LoadShiftClosingData());
      await Future.delayed(const Duration(milliseconds: 100));

      final shift2 = ShiftModel(
        closedByUserId: 1,
        closeDatetime: '2026-09-09T18:00:00',
        status: 'closed',
        notes: 'وردية مسائية 2',
      );
      final readings2 = [
        const ShiftReadingModel(
          shiftId: 0,
          pumpId: 1,
          previousMeter: 1200.0,
          currentMeter: 1500.0,
          litersSold: 300.0,
          previousDip: 9800.0,
          currentDip: 9500.0,
          deliveredLitersDuringShift: 0.0,
          surplusDeficit: 0.0,
          pricePerLiter: 1500.0,
          totalAmount: 450000.0,
        ),
      ];
      final summary2 = const SalesSummaryModel(
        shiftId: 0,
        cashAmount: 300000.0,
        bankTransferAmount: 150000.0,
        creditAmount: 0.0,
        totalAmount: 450000.0,
      );

      shiftBloc.add(SubmitCloseShiftRequested(
        shift: shift2,
        readings: readings2,
        summary: summary2,
        tankNewDips: {1: 9500.0},
      ));
      await Future.doWhile(() async {
        if (shiftBloc.state.closeSuccess != null || shiftBloc.state.submitErrorMessage != null) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        return true;
      }).timeout(const Duration(seconds: 5));

      expect(shiftBloc.state.closeSuccess, isNotNull);
      final shiftId2 = shiftBloc.state.closeSuccess!.shiftId;
      print('-> Shift 2 Closed Successfully with ID #$shiftId2');

      shiftBloc.add(ResetShiftCloseStatus());
      await Future.doWhile(() async {
        if (shiftBloc.state.closeSuccess == null) return false;
        await Future.delayed(const Duration(milliseconds: 20));
        return true;
      }).timeout(const Duration(seconds: 2));
      expect(shiftBloc.state.closeSuccess, isNull);

      shiftBloc.add(LoadShiftHistory());
      await Future.delayed(const Duration(milliseconds: 40));
      await Future.doWhile(() async {
        if (shiftBloc.state.historyStatus == ShiftHistoryStatus.loaded ||
            shiftBloc.state.historyStatus == ShiftHistoryStatus.error) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        return true;
      }).timeout(const Duration(seconds: 5));
      expect(shiftBloc.state.historyStatus, ShiftHistoryStatus.loaded);
      expect(shiftBloc.state.shifts.length, 2);
      print('-> Shift History Updated: now has 2 shifts');

      reportsBloc.add(const LoadFinancialSummaryReport());
      await Future.delayed(const Duration(milliseconds: 40));
      await Future.doWhile(() async {
        if (reportsBloc.state is ReportsSummaryLoaded &&
            (reportsBloc.state as ReportsSummaryLoaded).summary.totalSalesAmount == 750000.0) {
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 30));
        return true;
      }).timeout(const Duration(seconds: 5));
      expect(reportsBloc.state, isA<ReportsSummaryLoaded>());
      final reportState2 = reportsBloc.state as ReportsSummaryLoaded;
      expect(reportState2.summary.totalSalesAmount, 750000.0);
      expect(reportState2.summary.totalSalesCash, 500000.0);
      print('-> Financial Report Updated in same session: total sales = ${reportState2.summary.totalSalesAmount} SDG');

      await shiftBloc.close();
      await reportsBloc.close();
      print('=== [PASS] Problem 1 Verified 100%: No freeze, no loop, reports populated. ===');
    });
  });

  group('Problem 2: Sidebar Scrolling on Small Screen / Window Heights', () {
    testWidgets('Sidebar scrolls smoothly and allows reaching bottom items on short window height (400px)', (tester) async {
      // Create authenticated manager
      final manager = const UserModel(
        id: 1,
        name: 'المدير العام',
        username: 'admin',
        passwordHash: 'hash',
        role: 'manager',
      );

      final authBloc = AuthBloc(authRepository: AuthRepository(dbHelper: dbHelper));
      authBloc.emit(AuthAuthenticated(manager));

      final tankB = TankBloc(tankRepository: tankRepo);
      final priceB = FuelPriceBloc(fuelPriceRepository: priceRepo);
      final shiftB = ShiftBloc(
        shiftRepository: shiftRepo,
        tankRepository: tankRepo,
        fuelPriceRepository: priceRepo,
        customerRepository: customerRepo,
      );
      final custB = CustomerBloc(customerRepository: customerRepo);
      final delivB = DeliveryBloc(deliveryRepository: deliveryRepo, tankRepository: tankRepo);
      final cashB = CashBoxBloc(cashBoxRepository: CashBoxRepository(dbHelper: dbHelper));
      final expB = ExpenseBloc(expenseRepository: ExpenseRepository(dbHelper: dbHelper));
      final repB = ReportsBloc(reportRepository: reportRepo);

      final authRepo = AuthRepository(dbHelper: dbHelper);
      final cashBoxRepo = CashBoxRepository(dbHelper: dbHelper);
      final expRepo = ExpenseRepository(dbHelper: dbHelper);

      // Set a short window height: 1200 x 450
      tester.view.physicalSize = const Size(1200, 450);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: authRepo),
            RepositoryProvider.value(value: tankRepo),
            RepositoryProvider.value(value: priceRepo),
            RepositoryProvider.value(value: shiftRepo),
            RepositoryProvider.value(value: customerRepo),
            RepositoryProvider.value(value: deliveryRepo),
            RepositoryProvider.value(value: cashBoxRepo),
            RepositoryProvider.value(value: expRepo),
            RepositoryProvider.value(value: reportRepo),
            RepositoryProvider.value(value: backupRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: authBloc),
              BlocProvider.value(value: tankB),
              BlocProvider.value(value: priceB),
              BlocProvider.value(value: shiftB),
              BlocProvider.value(value: custB),
              BlocProvider.value(value: delivB),
              BlocProvider.value(value: cashB),
              BlocProvider.value(value: expB),
              BlocProvider.value(value: repB),
            ],
            child: const MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: MainNavigationShell(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify top item is visible
      expect(find.text('لوحة التحكم'), findsOneWidget);

      // Verify that the sidebar contains a Scrollable ListView
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsWidgets);

      // Scroll down the sidebar ListView to bring bottom items into view
      await tester.drag(listViewFinder.first, const Offset(0, -650));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom items must now be completely visible and reachable without overflow!
      expect(find.text('إعدادات الخزانات'), findsOneWidget);
      expect(find.text('تغيير كلمة المرور'), findsOneWidget);
      expect(find.text('Windows / Web Desktop v1.0'), findsOneWidget);

      // Tap on "إعدادات الخزانات" to prove interactivity
      await tester.tap(find.text('إعدادات الخزانات'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify navigation to TankSettingsScreen
      expect(find.text('إعدادات وسعات الخزانات الرئيسية'), findsOneWidget);
      print('=== [PASS] Problem 2 Verified 100%: All sidebar items accessible via scroll on 400px height. ===');

      // Unmount widgets cleanly and expire any internal sqflite lock-check timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });
  });

  group('Problem 3: Tank Capacity Setting, Delivery Overfill Rejection, and Fill Percentage', () {
    test('Executive Proof: Benzin 45,000L capacity, reject 50,000L, accept 40,000L with 88.9% ratio', () async {
      print('=== [TEST] Problem 3: Tank Capacity & Delivery Logic Verification ===');

      final manager = const UserModel(
        id: 1,
        name: 'المدير العام',
        username: 'admin',
        passwordHash: 'hash',
        role: 'manager',
      );

      final accountant = const UserModel(
        id: 2,
        name: 'المحاسب',
        username: 'acc',
        passwordHash: 'hash',
        role: 'accountant',
      );

      // 1. Initial State: Capacity is 0.0, current dip is 0.0
      final tanksInitial = await tankRepo.getTanks();
      final benzinTank = tanksInitial.firstWhere((t) => t.fuelType == 'بنزين');
      print('1. Initial Tank: ${benzinTank.name}, Capacity: ${benzinTank.capacityLiters} L, Dip: ${benzinTank.currentDipLiters} L');
      expect(benzinTank.capacityLiters, 0.0);
      expect(benzinTank.hasCapacity, false);
      expect(benzinTank.fillPercentage, 0.0);

      // 2. Permission check: Accountant is denied setting capacity
      expect(
        () => tankRepo.updateTankCapacity(benzinTank.id!, 45000.0, user: accountant),
        throwsA(isA<UnauthorizedException>()),
      );
      print('2. Non-manager user (Accountant) was correctly REJECTED from setting tank capacity.');

      // 3. Manager sets capacity to 45,000 Liters
      await tankRepo.updateTankCapacity(benzinTank.id!, 45000.0, user: manager);
      final tankAfterCap = await tankRepo.getTankById(benzinTank.id!);
      expect(tankAfterCap!.capacityLiters, 45000.0);
      expect(tankAfterCap.hasCapacity, true);
      print('3. Manager set ${benzinTank.name} capacity to: ${tankAfterCap.capacityLiters} Liters.');

      // Add supplier for delivery test
      final supplierId = await deliveryRepo.addSupplier(
        const SupplierModel(name: 'شركة النيل للبترول', phone: '0912345678'),
        user: manager,
      );

      // 4. Attempt to deliver 50,000 Liters into the 45,000 Liter tank
      print('4. Attempting delivery of 50,000 Liters into 45,000 Liters capacity tank...');
      final overfillDelivery = DeliveryModel(
        supplierId: supplierId,
        tankId: benzinTank.id!,
        liters: 50000.0,
        costPerLiter: 1200.0,
        totalCost: 60000000.0,
        deliveredAt: '2026-09-09T11:00:00',
        recordedByUserId: 1,
      );

      expect(
        deliveryRepo.recordDelivery(overfillDelivery),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('لا يمكن تفريغ الشحنة') &&
            e.toString().contains('45,000'))),
      );
      print('-> Delivery of 50,000 L REJECTED with clear overfill exception!');

      // Verify no delivery was recorded and tank dip remains unchanged
      final deliveriesAfterReject = await deliveryRepo.getDeliveries();
      expect(deliveriesAfterReject.isEmpty, true);
      final tankCheck1 = await tankRepo.getTankById(benzinTank.id!);
      expect(tankCheck1!.currentDipLiters, 0.0);
      print('-> Verified DB: 0 deliveries stored, current dip remains 0.0 L.');

      // 5. Deliver 40,000 Liters into the 45,000 Liter tank
      print('5. Attempting valid delivery of 40,000 Liters...');
      final validDelivery = DeliveryModel(
        supplierId: supplierId,
        tankId: benzinTank.id!,
        liters: 40000.0,
        costPerLiter: 1200.0,
        totalCost: 48000000.0,
        deliveredAt: '2026-09-09T11:30:00',
        recordedByUserId: 1,
      );

      final deliveryId = await deliveryRepo.recordDelivery(validDelivery);
      expect(deliveryId, greaterThan(0));
      print('-> Delivery ACCEPTED successfully with ID #$deliveryId!');

      // 6. Verify Tank state after 40,000L delivery:
      // Current Dip: 40,000L
      // Capacity: 45,000L
      // Fill percentage: (40,000 / 45,000) * 100 = 88.8888...% -> 88.9%
      final tankFinal = await tankRepo.getTankById(benzinTank.id!);
      expect(tankFinal!.currentDipLiters, 40000.0);
      expect(tankFinal.capacityLiters, 45000.0);
      expect(tankFinal.fillPercentage, closeTo(88.888, 0.01));
      final formattedPercentage = tankFinal.fillPercentage.toStringAsFixed(1);
      expect(formattedPercentage, '88.9');
      print('6. Final Tank State: Dip = ${tankFinal.currentDipLiters} L, Capacity = ${tankFinal.capacityLiters} L');
      print('-> Fill Percentage = $formattedPercentage% (Accurately computed 40,000 ÷ 45,000 × 100)');

      // 7. Attempt second delivery of 6,000L (current 40,000 + 6,000 = 46,000 > 45,000)
      print('7. Attempting second delivery of 6,000 L (would total 46,000 L > 45,000 L)...');
      final secondOverfill = DeliveryModel(
        supplierId: supplierId,
        tankId: benzinTank.id!,
        liters: 6000.0,
        costPerLiter: 1200.0,
        totalCost: 7200000.0,
        deliveredAt: '2026-09-09T12:00:00',
        recordedByUserId: 1,
      );
      expect(
        deliveryRepo.recordDelivery(secondOverfill),
        throwsA(predicate((e) =>
            e is Exception &&
            e.toString().contains('5,000'))),
      );
      print('-> Correctly REJECTED: Notice explicitly reported 5,000 L maximum remaining space!');

      print('=== [PASS] Problem 3 Verified 100%: Tank capacity, overfill protection, and 88.9% fill ratio! ===');
    });

    testWidgets('TankLevelCard displays "لم تُحدَّد السعة بعد" when capacity=0 and "88.9%" when capacity=45k, dip=40k', (tester) async {
      // Card with capacity = 0
      final tankZeroCap = const TankModel(
        id: 1,
        name: 'خزان بنزين رقم (1)',
        fuelType: 'بنزين',
        capacityLiters: 0.0,
        currentDipLiters: 1500000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TankLevelCard(tank: tankZeroCap),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must display "لم تُحدَّد السعة بعد" rather than misleading "0.0%"
      expect(find.text('لم تُحدَّد السعة بعد'), findsWidgets);
      expect(find.text('0.0%'), findsNothing);

      // Card with capacity = 45,000 and dip = 40,000
      final tank88Pct = const TankModel(
        id: 1,
        name: 'خزان بنزين رقم (1)',
        fuelType: 'بنزين',
        capacityLiters: 45000.0,
        currentDipLiters: 40000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TankLevelCard(tank: tank88Pct),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must display "88.9%"
      expect(find.text('88.9%'), findsOneWidget);
    });
  });
}
