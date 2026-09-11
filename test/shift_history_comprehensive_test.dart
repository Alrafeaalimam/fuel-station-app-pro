import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuel_station_app_pro/data/database_helper.dart';
import 'package:fuel_station_app_pro/data/repositories/auth_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/tank_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/fuel_price_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/shift_repository.dart';
import 'package:fuel_station_app_pro/data/repositories/customer_repository.dart';
import 'package:fuel_station_app_pro/bloc/auth/auth_bloc.dart';
import 'package:fuel_station_app_pro/bloc/shift/shift_bloc.dart';
import 'package:fuel_station_app_pro/bloc/shift/shift_event.dart';
import 'package:fuel_station_app_pro/bloc/shift/shift_state.dart';
import 'package:fuel_station_app_pro/screens/shifts/shift_close_screen.dart';
import 'package:fuel_station_app_pro/models/models.dart';

// Mock repository to simulate database exception
class ThrowingShiftRepository extends ShiftRepository {
  ThrowingShiftRepository({super.dbHelper});

  @override
  Future<List<ShiftModel>> getAllShifts() async {
    throw Exception('فشل الاتصال بقاعدة البيانات على نظام التشغيل');
  }
}

// Mock repository to simulate empty database
class EmptyShiftRepository extends ShiftRepository {
  EmptyShiftRepository({super.dbHelper});

  @override
  Future<List<ShiftModel>> getAllShifts() async {
    return [];
  }
}

// Mock repository to simulate loaded database
class PopulatedShiftRepository extends ShiftRepository {
  PopulatedShiftRepository({super.dbHelper});

  @override
  Future<List<ShiftModel>> getAllShifts() async {
    return [
      ShiftModel(
        id: 777,
        closedByUserId: 1,
        closeDatetime: '2026-09-08T18:00:00.000',
        status: 'closed',
        notes: 'وردية تجريبية مؤكدة',
      ),
    ];
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('ShiftBloc retains both Closing and History states without clobbering', () async {
    final dbHelper = DatabaseHelper.instance;
    final shiftRepo = ShiftRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    final customerRepo = CustomerRepository(dbHelper: dbHelper);

    final shiftBloc = ShiftBloc(
      shiftRepository: shiftRepo,
      tankRepository: tankRepo,
      fuelPriceRepository: priceRepo,
      customerRepository: customerRepo,
    );

    // Initial state
    expect(shiftBloc.state.closingStatus, ShiftClosingStatus.initial);
    expect(shiftBloc.state.historyStatus, ShiftHistoryStatus.initial);

    // Dispatch both events concurrently as in initState
    shiftBloc.add(LoadShiftClosingData());
    shiftBloc.add(LoadShiftHistory());

    await shiftBloc.stream
        .firstWhere((s) =>
            s.closingStatus == ShiftClosingStatus.loaded &&
            (s.historyStatus == ShiftHistoryStatus.loaded ||
                s.historyStatus == ShiftHistoryStatus.empty))
        .timeout(const Duration(seconds: 4));

    // Both should now be loaded!
    expect(shiftBloc.state.closingStatus, ShiftClosingStatus.loaded);
    expect(shiftBloc.state.pumpDataList.length, 8);
    expect(
      shiftBloc.state.historyStatus == ShiftHistoryStatus.loaded ||
          shiftBloc.state.historyStatus == ShiftHistoryStatus.empty,
      true,
    );

    print('SUCCESS: Both Closing Data (${shiftBloc.state.closingStatus}) and History (${shiftBloc.state.historyStatus}) co-exist simultaneously!');
  });

  testWidgets('Case A: Empty State displays "لا توجد ورديات سابقة مسجلة بعد" when DB has no shifts', (tester) async {
    final dbHelper = DatabaseHelper.instance;
    final emptyShiftRepo = EmptyShiftRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    final customerRepo = CustomerRepository(dbHelper: dbHelper);
    final authRepo = AuthRepository(dbHelper: dbHelper);

    final shiftBloc = ShiftBloc(
      shiftRepository: emptyShiftRepo,
      tankRepository: tankRepo,
      fuelPriceRepository: priceRepo,
      customerRepository: customerRepo,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ShiftRepository>.value(value: emptyShiftRepo),
            RepositoryProvider.value(value: tankRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: shiftBloc),
              BlocProvider(create: (_) => AuthBloc(authRepository: authRepo)),
            ],
            child: const MaterialApp(
              home: ShiftCloseScreen(),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
    });

    await tester.pump();
    await tester.tap(find.byIcon(Icons.history_rounded));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('لا توجد ورديات سابقة مسجلة بعد'), findsOneWidget);
    expect(find.text('تحديث السجل'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Drain any remaining timers from timeout
    await tester.pump(const Duration(seconds: 15));
    print('SUCCESS Case A: Empty state verified within seconds!');
  });

  testWidgets('Case B: Loaded State displays shift list when records exist', (tester) async {
    final dbHelper = DatabaseHelper.instance;
    final populatedShiftRepo = PopulatedShiftRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    final customerRepo = CustomerRepository(dbHelper: dbHelper);
    final authRepo = AuthRepository(dbHelper: dbHelper);

    final shiftBloc = ShiftBloc(
      shiftRepository: populatedShiftRepo,
      tankRepository: tankRepo,
      fuelPriceRepository: priceRepo,
      customerRepository: customerRepo,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ShiftRepository>.value(value: populatedShiftRepo),
            RepositoryProvider.value(value: tankRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: shiftBloc),
              BlocProvider(create: (_) => AuthBloc(authRepository: authRepo)),
            ],
            child: const MaterialApp(
              home: ShiftCloseScreen(),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
    });

    await tester.pump();
    await tester.tap(find.byIcon(Icons.history_rounded));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('وردية رقم #777'), findsOneWidget);
    expect(find.text('عرض التفاصيل'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Drain any remaining timers from timeout
    await tester.pump(const Duration(seconds: 15));
    print('SUCCESS Case B: Loaded shift data verified within seconds!');
  });

  testWidgets('Case C: Error State displays explicit error message and retry button on failure', (tester) async {
    final dbHelper = DatabaseHelper.instance;
    final throwingRepo = ThrowingShiftRepository(dbHelper: dbHelper);
    final tankRepo = TankRepository(dbHelper: dbHelper);
    final priceRepo = FuelPriceRepository(dbHelper: dbHelper);
    final customerRepo = CustomerRepository(dbHelper: dbHelper);
    final authRepo = AuthRepository(dbHelper: dbHelper);

    final shiftBloc = ShiftBloc(
      shiftRepository: throwingRepo,
      tankRepository: tankRepo,
      fuelPriceRepository: priceRepo,
      customerRepository: customerRepo,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ShiftRepository>.value(value: throwingRepo),
            RepositoryProvider.value(value: tankRepo),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: shiftBloc),
              BlocProvider(create: (_) => AuthBloc(authRepository: authRepo)),
            ],
            child: const MaterialApp(
              home: ShiftCloseScreen(),
            ),
          ),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));
    });

    await tester.pump();
    await tester.tap(find.byIcon(Icons.history_rounded));

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('فشل الاتصال بقاعدة البيانات'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Drain any remaining timers from timeout
    await tester.pump(const Duration(seconds: 15));
    print('SUCCESS Case C: Explicit error state caught and displayed within seconds!');
  });
}
