import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/tanks/tank_bloc.dart';
import '../../bloc/tanks/tank_state.dart';
import '../../bloc/tanks/tank_event.dart';
import '../../bloc/prices/fuel_price_bloc.dart';
import '../../bloc/prices/fuel_price_state.dart';
import '../../bloc/prices/fuel_price_event.dart';
import '../../bloc/cash_box/cash_box_bloc.dart';
import '../../bloc/cash_box/cash_box_state.dart';
import '../../bloc/cash_box/cash_box_event.dart';
import '../../bloc/customers/customer_bloc.dart';
import '../../bloc/customers/customer_state.dart';
import '../../bloc/customers/customer_event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/tank_level_card.dart';
import '../../config/station_config.dart';
import '../../utils/permission_guard.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    context.read<TankBloc>().add(LoadTanksAndPumps());
    context.read<FuelPriceBloc>().add(LoadFuelPrices());
    context.read<CashBoxBloc>().add(LoadCashBox());
    context.read<CustomerBloc>().add(LoadCustomers());
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0', 'en_US');
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome & Quick Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      'مرحباً بك، ${currentUser?.name ?? "المستخدم"}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<String>(
                      valueListenable: StationConfig.stationNameNotifier,
                      builder: (context, stationName, _) => Text(
                        'لوحة المتابعة الميدانية والمالية - $stationName',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'تحديث البيانات',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                      ),
                      onPressed: () => widget.onNavigate(1), // Go to Shift close
                      icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
                      label: const Text('قفل وردية جديدة'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Prices Banner
            BlocBuilder<FuelPriceBloc, FuelPriceState>(
              builder: (context, priceState) {
                if (priceState is FuelPriceLoaded) {
                  final benzinPrice = priceState.activePrices['بنزين']?.pricePerLiter ?? 0;
                  final dieselPrice = priceState.activePrices['جازولين']?.pricePerLiter ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.price_change_outlined, color: Colors.amber, size: 30),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التسعيرة الرسمية السارية حالياً',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'تُعتمد تلقائياً في حسابات قفل الوردية الحالية',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        _buildPriceTag('بنزين', benzinPrice, AppTheme.benzinColor),
                        const SizedBox(width: 12),
                        _buildPriceTag('جازولين', dieselPrice, AppTheme.dieselColor),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),

            // Financial & Cash Box Stats
            BlocBuilder<CashBoxBloc, CashBoxState>(
              builder: (context, cashState) {
                final todayBox = cashState is CashBoxLoaded ? cashState.todayBox : null;
                final opening = todayBox?.openingBalance ?? 0.0;
                final cashIn = todayBox?.cashIn ?? 0.0;
                final cashOut = todayBox?.cashOut ?? 0.0;
                final closing = todayBox?.closingBalance ?? 0.0;

                return BlocBuilder<CustomerBloc, CustomerState>(
                  builder: (context, custState) {
                    double totalDebts = 0.0;
                    if (custState is CustomerLoaded) {
                      for (final c in custState.customers) {
                        totalDebts += c.currentBalance;
                      }
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 900;
                        final cardWidth = isNarrow
                            ? (constraints.maxWidth - 12) / 2
                            : (constraints.maxWidth - 36) / 4;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: StatCard(
                                title: 'رصيد الخزنة الحالي',
                                value: '${numberFormat.format(closing)} ج.س',
                                icon: Icons.account_balance_wallet_rounded,
                                color: AppTheme.primaryBlue,
                                subtitle: 'افتتاحي: ${numberFormat.format(opening)}',
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: StatCard(
                                title: 'إجمالي الوارد اليوم',
                                value: '${numberFormat.format(cashIn)} ج.س',
                                icon: Icons.arrow_downward_rounded,
                                color: AppTheme.successGreen,
                                subtitle: 'نقدي + تحصيلات آجل',
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: StatCard(
                                title: 'إجمالي المنصرف اليوم',
                                value: '${numberFormat.format(cashOut)} ج.س',
                                icon: Icons.arrow_upward_rounded,
                                color: AppTheme.dangerRed,
                                subtitle: 'مصروفات تشغيلية',
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: StatCard(
                                title: 'إجمالي مديونيات الآجل',
                                value: '${numberFormat.format(totalDebts)} ج.س',
                                icon: Icons.people_outline_rounded,
                                color: AppTheme.warningOrange,
                                subtitle: 'مستحقات على العملاء',
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 28),

            // Tanks Level Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'حالة خزانات الوقود ومناسيب المسطرة (2 خزان)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                if (currentUser?.can(AppPermission.manageTanks) ?? false)
                  TextButton.icon(
                    onPressed: () => widget.onNavigate(11),
                    icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                    label: const Text('إعدادات وسعات الخزانات'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            BlocBuilder<TankBloc, TankState>(
              builder: (context, tankState) {
                if (tankState is TankLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tankState is TankLoaded) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 800;
                      return isNarrow
                          ? Column(
                              children: tankState.tanks
                                  .map((tank) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: TankLevelCard(tank: tank),
                                      ))
                                  .toList(),
                            )
                          : Row(
                              children: tankState.tanks
                                  .map((tank) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: TankLevelCard(tank: tank),
                                        ),
                                      ))
                                  .toList(),
                            );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 28),

            // 8 Pumps / Nozzles Grid
            const Text(
              'فوهات التوزيع العاملة (8 فوهات)',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            BlocBuilder<TankBloc, TankState>(
              builder: (context, tankState) {
                if (tankState is TankLoaded) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth < 600
                          ? 2
                          : constraints.maxWidth < 1000
                              ? 4
                              : 4;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: tankState.pumps.length,
                        itemBuilder: (context, index) {
                          final pump = tankState.pumps[index];
                          final tank = tankState.tanks.firstWhere(
                            (t) => t.id == pump.tankId,
                            orElse: () => tankState.tanks.first,
                          );
                          final isBenzin = tank.fuelType == 'بنزين';
                          final fuelColor =
                              isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: fuelColor.withValues(alpha: 0.12),
                                    child: Text(
                                      '#${pump.nozzleNumber}',
                                      style: TextStyle(
                                        color: fuelColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          pump.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          tank.fuelType,
                                          style: TextStyle(
                                            color: fuelColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceTag(String fuelName, double price, Color color) {
    final numberFormat = NumberFormat('#,##0', 'en_US');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            '$fuelName: ',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          Text(
            '${numberFormat.format(price)} ج.س / لتر',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
