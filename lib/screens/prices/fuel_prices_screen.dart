import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/prices/fuel_price_bloc.dart';
import '../../bloc/prices/fuel_price_event.dart';
import '../../bloc/prices/fuel_price_state.dart';
import '../../theme/app_theme.dart';

class FuelPricesScreen extends StatefulWidget {
  const FuelPricesScreen({super.key});

  @override
  State<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends State<FuelPricesScreen> {
  String _selectedFuelType = 'بنزين';
  final _newPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<FuelPriceBloc>().add(LoadFuelPrices());
  }

  @override
  void dispose() {
    _newPriceController.dispose();
    super.dispose();
  }

  void _showUpdatePriceDialog(BuildContext context, int? userId) {
    _newPriceController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تسجيل تسعيرة وقود جديدة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سيتم أرشفة السعر الحالي واعتماد السعر الجديد فوراً لجميع العمليات والورديات القادمة.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFuelType,
                    decoration: const InputDecoration(labelText: 'نوع الوقود'),
                    items: const [
                      DropdownMenuItem(value: 'بنزين', child: Text('بنزين')),
                      DropdownMenuItem(value: 'جازولين', child: Text('جازولين')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _selectedFuelType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _newPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'السعر الجديد للتر',
                      suffixText: 'ج.س / لتر',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(_newPriceController.text);
                    if (price != null && price > 0) {
                      this.context.read<FuelPriceBloc>().add(
                            UpdateFuelPriceRequested(
                              fuelType: _selectedFuelType,
                              newPrice: price,
                              userId: userId,
                            ),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('اعتماد التسعيرة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');
    final authState = context.watch<AuthBloc>().state;
    final isManager = authState is AuthAuthenticated && authState.user.isManager;
    final userId = authState is AuthAuthenticated ? authState.user.id : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة وتسعير الوقود (التسعيرة الرسمية والسجل التاريخي)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (isManager)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                ),
                onPressed: () => _showUpdatePriceDialog(context, userId),
                icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
                label: const Text('تعديل / تحديث تسعيرة'),
              ),
            ),
        ],
      ),
      body: BlocConsumer<FuelPriceBloc, FuelPriceState>(
        listener: (context, state) {
          if (state is FuelPriceUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          } else if (state is FuelPriceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is FuelPriceLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FuelPriceLoaded) {
            final benzinPrice = state.activePrices['بنزين']?.pricePerLiter ?? 0;
            final dieselPrice = state.activePrices['جازولين']?.pricePerLiter ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Prices Cards
                  const Text(
                    'الأسعار الرسمية السارية حالياً',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActivePriceCard(
                          'بنزين (Super)',
                          benzinPrice,
                          AppTheme.benzinColor,
                          state.activePrices['بنزين']?.effectiveFrom,
                          currencyFormat,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActivePriceCard(
                          'جازولين (Diesel)',
                          dieselPrice,
                          AppTheme.dieselColor,
                          state.activePrices['جازولين']?.effectiveFrom,
                          currencyFormat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // History Table
                  const Text(
                    'السجل التاريخي لتغيرات أسعار الوقود',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('نوع الوقود')),
                            DataColumn(label: Text('السعر للتر (ج.س)')),
                            DataColumn(label: Text('ساري من تاريخ')),
                            DataColumn(label: Text('ساري حتى تاريخ')),
                            DataColumn(label: Text('الحالة')),
                          ],
                          rows: state.priceHistory.map((p) {
                            final isBenzin = p.fuelType == 'بنزين';
                            final fuelColor =
                                isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;
                            final isActive = p.isActive;

                            return DataRow(
                              cells: [
                                DataCell(Text('#${p.id}')),
                                DataCell(Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: fuelColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      p.fuelType,
                                      style: TextStyle(
                                        color: fuelColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )),
                                DataCell(Text(
                                  '${currencyFormat.format(p.pricePerLiter)} ج.س',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )),
                                DataCell(Text(DateFormat('yyyy-MM-dd HH:mm')
                                    .format(DateTime.parse(p.effectiveFrom)))),
                                DataCell(Text(p.effectiveTo != null
                                    ? DateFormat('yyyy-MM-dd HH:mm')
                                        .format(DateTime.parse(p.effectiveTo!))
                                    : 'مستمر حتى الآن')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isActive
                                              ? AppTheme.successGreen
                                              : Colors.grey)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isActive ? 'ساري حالياً' : 'مؤرشف',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? AppTheme.successGreen
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildActivePriceCard(
    String title,
    double price,
    Color color,
    String? effectiveFrom,
    NumberFormat currencyFormat,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ساري المفعول',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${currencyFormat.format(price)} ج.س / لتر',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              effectiveFrom != null
                  ? 'تم الاعتماد: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(effectiveFrom))}'
                  : '',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
