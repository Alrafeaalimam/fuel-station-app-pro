import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/reports/reports_bloc.dart';
import '../../bloc/reports/reports_event.dart';
import '../../bloc/reports/reports_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');
    final numberFormat = NumberFormat('#,##0.0', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'التقارير المالية وحركة الوقود والربحية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: IconButton(
              onPressed: () {
                context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث التقرير',
            ),
          ),
        ],
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          if (state is ReportsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ReportsSummaryLoaded) {
            final sum = state.summary;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Overview
                  const Text(
                    'المؤشرات المالية الشاملة للمحطة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'إجمالي المبيعات الكلية',
                          value: '${currencyFormat.format(sum.totalSalesAmount)} ج.س',
                          icon: Icons.monetization_on_rounded,
                          color: AppTheme.primaryNavy,
                          subtitle: 'جميع طرق الدفع',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'مبيعات نقدي (كاش)',
                          value: '${currencyFormat.format(sum.totalSalesCash)} ج.س',
                          icon: Icons.money_rounded,
                          color: AppTheme.successGreen,
                          subtitle: 'توريد مباشر للخزنة',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'تحويل بنكي (بنكك)',
                          value: '${currencyFormat.format(sum.totalSalesBank)} ج.س',
                          icon: Icons.account_balance_rounded,
                          color: AppTheme.primaryBlue,
                          subtitle: 'حساب البنك',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'مبيعات آجل (عملاء)',
                          value: '${currencyFormat.format(sum.totalSalesCredit)} ج.س',
                          icon: Icons.credit_card_rounded,
                          color: AppTheme.warningOrange,
                          subtitle: 'مستحقات على الذمم',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Fuel Volumes & Operations
                  const Text(
                    'حجم المبيعات باللترات ومصروفات التشغيل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'إجمالي مبيعات البنزين',
                          value: '${numberFormat.format(sum.totalBenzinLiters)} لتر',
                          icon: Icons.local_gas_station,
                          color: AppTheme.benzinColor,
                          subtitle: 'عبر 4 فوهات بنزين',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'إجمالي مبيعات الجازولين',
                          value: '${numberFormat.format(sum.totalDieselLiters)} لتر',
                          icon: Icons.local_gas_station,
                          color: AppTheme.dieselColor,
                          subtitle: 'عبر 4 فوهات جازولين',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'إجمالي المصروفات التشغيلية',
                          value: '${currencyFormat.format(sum.totalExpenses)} ج.س',
                          icon: Icons.receipt_long,
                          color: AppTheme.dangerRed,
                          subtitle: 'كهرباء، صيانة، رواتب',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'صافي التدفق النقدي (السيولة)',
                          value: '${currencyFormat.format(sum.netCashFlow)} ج.س',
                          icon: Icons.savings_rounded,
                          color: AppTheme.accentCyan,
                          subtitle: 'نقد + تحصيلات - مصاريف',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Consolidated Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'بيان الحساب الختامي التراكمي',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24),
                          _buildReportRow(
                            'إجمالي الإيرادات المحققة من الوقود',
                            '${currencyFormat.format(sum.totalSalesAmount)} ج.س',
                            isBold: true,
                          ),
                          _buildReportRow(
                            'المتحصلات النقدية المحصلة فعلياً بالخزنة',
                            '${currencyFormat.format(sum.totalSalesCash)} ج.س',
                          ),
                          _buildReportRow(
                            'التحويلات البنكية المباشرة (تطبيق بنكك)',
                            '${currencyFormat.format(sum.totalSalesBank)} ج.س',
                          ),
                          _buildReportRow(
                            'تحصيلات سداد ديون سابقة من عملاء الآجل',
                            '+${currencyFormat.format(sum.totalCreditCollected)} ج.س',
                            color: AppTheme.successGreen,
                          ),
                          _buildReportRow(
                            'إجمالي المصروفات المنصرفة من الخزنة',
                            '-${currencyFormat.format(sum.totalExpenses)} ج.س',
                            color: AppTheme.dangerRed,
                          ),
                          const Divider(height: 24),
                          _buildReportRow(
                            'صافي رصيد السيولة النقدية المستلمة',
                            '${currencyFormat.format(sum.netCashFlow)} ج.س',
                            isBold: true,
                            color: AppTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is ReportsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة تحميل التقرير'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحميل البيانات المالية'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
