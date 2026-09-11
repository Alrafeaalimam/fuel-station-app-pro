import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/tank_repository.dart';
import 'data/repositories/fuel_price_repository.dart';
import 'data/repositories/shift_repository.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/delivery_repository.dart';
import 'data/repositories/cash_box_repository.dart';
import 'data/repositories/expense_repository.dart';
import 'data/repositories/report_repository.dart';
import 'data/repositories/backup_repository.dart';

import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_state.dart';
import 'bloc/tanks/tank_bloc.dart';
import 'bloc/prices/fuel_price_bloc.dart';
import 'bloc/shift/shift_bloc.dart';
import 'bloc/customers/customer_bloc.dart';
import 'bloc/deliveries/delivery_bloc.dart';
import 'bloc/cash_box/cash_box_bloc.dart';
import 'bloc/expenses/expense_bloc.dart';
import 'bloc/reports/reports_bloc.dart';

import 'config/station_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StationConfig.loadStationName();
  runApp(const FuelStationApp());
}

class FuelStationApp extends StatelessWidget {
  const FuelStationApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize Repositories
    final authRepo = AuthRepository();
    final tankRepo = TankRepository();
    final priceRepo = FuelPriceRepository();
    final backupRepo = BackupRepository();
    final shiftRepo = ShiftRepository(backupRepo: backupRepo);
    final customerRepo = CustomerRepository();
    final deliveryRepo = DeliveryRepository();
    final cashBoxRepo = CashBoxRepository();
    final expenseRepo = ExpenseRepository();
    final reportRepo = ReportRepository();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepo),
        RepositoryProvider.value(value: tankRepo),
        RepositoryProvider.value(value: priceRepo),
        RepositoryProvider.value(value: shiftRepo),
        RepositoryProvider.value(value: customerRepo),
        RepositoryProvider.value(value: deliveryRepo),
        RepositoryProvider.value(value: cashBoxRepo),
        RepositoryProvider.value(value: expenseRepo),
        RepositoryProvider.value(value: reportRepo),
        RepositoryProvider.value(value: backupRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(authRepository: authRepo),
          ),
          BlocProvider(
            create: (context) => TankBloc(tankRepository: tankRepo),
          ),
          BlocProvider(
            create: (context) => FuelPriceBloc(fuelPriceRepository: priceRepo),
          ),
          BlocProvider(
            create: (context) => ShiftBloc(
              shiftRepository: shiftRepo,
              tankRepository: tankRepo,
              fuelPriceRepository: priceRepo,
              customerRepository: customerRepo,
            ),
          ),
          BlocProvider(
            create: (context) => CustomerBloc(customerRepository: customerRepo),
          ),
          BlocProvider(
            create: (context) => DeliveryBloc(
              deliveryRepository: deliveryRepo,
              tankRepository: tankRepo,
            ),
          ),
          BlocProvider(
            create: (context) => CashBoxBloc(cashBoxRepository: cashBoxRepo),
          ),
          BlocProvider(
            create: (context) => ExpenseBloc(expenseRepository: expenseRepo),
          ),
          BlocProvider(
            create: (context) => ReportsBloc(reportRepository: reportRepo),
          ),
        ],
        child: ValueListenableBuilder<String>(
          valueListenable: StationConfig.stationNameNotifier,
          builder: (context, stationName, _) {
            return MaterialApp(
              title: stationName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              builder: (context, child) {
                // Apply RTL Arabic directionality application-wide
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthAuthenticated) {
                    return const MainNavigationShell();
                  }
                  return const LoginScreen();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
