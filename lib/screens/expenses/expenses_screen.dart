import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/expenses/expense_bloc.dart';
import '../../bloc/expenses/expense_event.dart';
import '../../bloc/expenses/expense_state.dart';
import '../../bloc/cash_box/cash_box_bloc.dart';
import '../../bloc/cash_box/cash_box_event.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _selectedCategory = 'صيانة';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _categories = ['كهرباء', 'صيانة', 'رواتب', 'أخرى'];

  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(const LoadExpenses());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddExpenseDialog(BuildContext context, int userId) {
    _amountController.clear();
    _descriptionController.clear();
    _selectedCategory = 'صيانة';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تسجيل مصروف جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'سيتم خصم قيمة المصروف تلقائياً من رصيد الخزنة النقدية لليوم الحالي.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'بند / تصنيف المصروف'),
                    items: _categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          _selectedCategory = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مبلغ المصروف (ج.س)',
                      suffixText: 'ج.س',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'تفاصيل وبيان المصروف',
                      hintText: 'مثلاً: صيانة فوهة رقم 3 وشراء قطع غيار',
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
                    final amt = double.tryParse(_amountController.text);
                    final desc = _descriptionController.text.trim();

                    if (amt != null && amt > 0 && desc.isNotEmpty) {
                      this.context.read<ExpenseBloc>().add(
                            AddExpenseRequested(
                              ExpenseModel(
                                date: DateTime.now().toIso8601String(),
                                category: _selectedCategory,
                                amount: amt,
                                description: desc,
                                recordedByUserId: userId,
                              ),
                            ),
                          );
                      this.context.read<CashBoxBloc>().add(LoadCashBox());
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('تسجيل وخصم من الخزنة'),
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
    final userId = authState is AuthAuthenticated ? authState.user.id ?? 1 : 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المصروفات التشغيلية للمحطة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
              onPressed: () => _showAddExpenseDialog(context, userId),
              icon: const Icon(Icons.add_card_rounded, color: Colors.white),
              label: const Text('تسجيل مصروف جديد'),
            ),
          ),
        ],
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state is ExpenseActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          } else if (state is ExpenseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ExpenseLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total and Category Breakdown Cards
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'إجمالي المصروفات الكلية',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${currencyFormat.format(state.totalExpenses)} ج.س',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ..._categories.map((cat) {
                        final catTotal = state.categorySummary[cat] ?? 0.0;
                        return Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${currencyFormat.format(catTotal)} ج.س',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Expenses Table
                  const Text(
                    'قائمة سندات الصرف والمصروفات المسجلة',
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
                        child: state.expenses.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: Text('لا توجد مصروفات مسجلة')),
                              )
                            : DataTable(
                                columns: const [
                                  DataColumn(label: Text('#')),
                                  DataColumn(label: Text('التصنيف')),
                                  DataColumn(label: Text('المبلغ')),
                                  DataColumn(label: Text('البيان والتفاصيل')),
                                  DataColumn(label: Text('التاريخ والوقت')),
                                ],
                                rows: state.expenses.map((e) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('#${e.id}')),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          e.category,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )),
                                      DataCell(Text(
                                        '${currencyFormat.format(e.amount)} ج.س',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.dangerRed,
                                        ),
                                      )),
                                      DataCell(Text(e.description)),
                                      DataCell(Text(
                                        DateFormat('yyyy-MM-dd HH:mm')
                                            .format(DateTime.parse(e.date)),
                                      )),
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
}
