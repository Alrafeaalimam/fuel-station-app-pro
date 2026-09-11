import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/customers/customer_bloc.dart';
import '../../bloc/customers/customer_event.dart';
import '../../bloc/customers/customer_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/permission_guard.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  // Add Customer Controllers
  final _nameController = TextEditingController();
  String _customerType = 'زبون دائم';
  final _phoneController = TextEditingController();
  final _creditLimitController = TextEditingController();

  // Payment Controller
  final _paymentAmountController = TextEditingController();
  final _paymentNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CustomerBloc>().add(LoadCustomers());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _creditLimitController.dispose();
    _paymentAmountController.dispose();
    _paymentNotesController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog(BuildContext context, {CustomerModel? existingCustomer}) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final canEditCreditLimit = currentUser?.can(AppPermission.editCustomerCreditLimit) ?? false;

    _nameController.text = existingCustomer?.name ?? '';
    _customerType = existingCustomer?.type ?? 'زبون دائم';
    _phoneController.text = existingCustomer?.phone ?? '';
    _creditLimitController.text =
        existingCustomer != null ? existingCustomer.creditLimit.toStringAsFixed(0) : '';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingCustomer == null ? 'إضافة عميل / مؤسسة جديدة' : 'تعديل بيانات العميل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم العميل أو الجهة'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _customerType,
                    decoration: const InputDecoration(labelText: 'نوع العميل'),
                    items: const [
                      DropdownMenuItem(value: 'زبون دائم', child: Text('زبون دائم')),
                      DropdownMenuItem(value: 'مؤسسة حكومية', child: Text('مؤسسة حكومية (مطالبة شهرية)')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          _customerType = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف / التواصل'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _creditLimitController,
                    keyboardType: TextInputType.number,
                    enabled: canEditCreditLimit,
                    decoration: InputDecoration(
                      labelText: canEditCreditLimit
                          ? 'السقف الائتماني المسموح به (ج.س)'
                          : 'السقف الائتماني (صلاحية خاصة بالمدير فقط)',
                      suffixText: 'ج.س',
                      prefixIcon: canEditCreditLimit ? null : const Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
                      filled: !canEditCreditLimit,
                      fillColor: canEditCreditLimit ? null : Colors.grey.shade100,
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
                    final name = _nameController.text.trim();
                    final phone = _phoneController.text.trim();
                    final limit = canEditCreditLimit
                        ? (double.tryParse(_creditLimitController.text) ?? 0.0)
                        : (existingCustomer?.creditLimit ?? 0.0);

                    if (name.isNotEmpty) {
                      if (existingCustomer == null) {
                        this.context.read<CustomerBloc>().add(
                              AddCustomerRequested(
                                CustomerModel(
                                  name: name,
                                  type: _customerType,
                                  phone: phone,
                                  creditLimit: limit,
                                  currentBalance: 0.0,
                                ),
                                user: currentUser,
                              ),
                            );
                      } else {
                        this.context.read<CustomerBloc>().add(
                              UpdateCustomerRequested(
                                existingCustomer.copyWith(
                                  name: name,
                                  type: _customerType,
                                  phone: phone,
                                  creditLimit: limit,
                                ),
                                user: currentUser,
                              ),
                            );
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordPaymentDialog(BuildContext context, CustomerModel customer) {
    _paymentAmountController.clear();
    _paymentNotesController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('سداد دفعة نقدية - ${customer.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرصيد المستحق الحالي: ${NumberFormat('#,##0').format(customer.currentBalance)} ج.س',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _paymentAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المدفوع (ج.س)',
                  suffixText: 'ج.س',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paymentNotesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات / رقم الإشعار (اختياري)',
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
                final amt = double.tryParse(_paymentAmountController.text);
                if (amt != null && amt > 0) {
                  this.context.read<CustomerBloc>().add(
                        RecordCustomerPaymentRequested(
                          customerId: customer.id!,
                          amount: amt,
                          notes: _paymentNotesController.text.trim().isNotEmpty
                              ? _paymentNotesController.text.trim()
                              : null,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('تسجيل الدفعة وتوريدها للخزنة'),
            ),
          ],
        );
      },
    );
  }

  void _showStatementDialog(BuildContext context, int customerId) {
    context.read<CustomerBloc>().add(LoadCustomerStatementRequested(customerId: customerId));

    showDialog(
      context: context,
      builder: (ctx) {
        final currencyFormat = NumberFormat('#,##0', 'en_US');

        return BlocBuilder<CustomerBloc, CustomerState>(
          builder: (context, state) {
            if (state is CustomerStatementLoaded) {
              final cust = state.customer;
              return AlertDialog(
                title: Text('كشف حساب: ${cust.name} (${cust.type})'),
                content: SizedBox(
                  width: 650,
                  height: 450,
                  child: Column(
                    children: [
                      // Header Stats
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('إجمالي المسحوبات (آجل): ${currencyFormat.format(state.totalCharges)} ج.س'),
                            Text('إجمالي السدادات: ${currencyFormat.format(state.totalPayments)} ج.س'),
                            Text(
                              'الرصيد المتبقي: ${currencyFormat.format(cust.currentBalance)} ج.س',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.dangerRed),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: state.transactions.isEmpty
                            ? const Center(child: Text('لا توجد حركات مسجلة لهذا العميل'))
                            : ListView.builder(
                                itemCount: state.transactions.length,
                                itemBuilder: (context, index) {
                                  final t = state.transactions[index];
                                  final isCharge = t.isCharge;

                                  return ListTile(
                                    leading: Icon(
                                      isCharge ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: isCharge ? AppTheme.dangerRed : AppTheme.successGreen,
                                    ),
                                    title: Text(
                                      isCharge ? 'سحب وقود آجل' : 'سداد دفعة نقدية',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      '${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(t.transactionDate))}${t.notes != null ? " - ${t.notes}" : ""}',
                                    ),
                                    trailing: Text(
                                      '${isCharge ? "+" : "-"}${currencyFormat.format(t.amount)} ج.س',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isCharge ? AppTheme.dangerRed : AppTheme.successGreen,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق'),
                  ),
                ],
              );
            }
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'العملاء وحسابات الآجل (زبائن دائمين ومؤسسات حكومية)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCustomerDialog(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
              label: const Text('إضافة عميل جديد'),
            ),
          ),
        ],
      ),
      body: BlocConsumer<CustomerBloc, CustomerState>(
        listener: (context, state) {
          if (state is CustomerActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          } else if (state is CustomerError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CustomerLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CustomerLoaded) {
            if (state.customers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('لا يوجد عملاء مسجلون حالياً'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showAddCustomerDialog(context),
                      child: const Text('إضافة أول عميل'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('اسم العميل / الجهة')),
                        DataColumn(label: Text('النوع')),
                        DataColumn(label: Text('الهاتف')),
                        DataColumn(label: Text('السقف الائتماني')),
                        DataColumn(label: Text('الرصيد المستحق')),
                        DataColumn(label: Text('الإجراءات')),
                      ],
                      rows: state.customers.map((c) {
                        final isLimitExceeded = c.isLimitExceeded;

                        return DataRow(
                          cells: [
                            DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (c.isGovernment ? Colors.indigo : Colors.teal)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.type,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: c.isGovernment ? Colors.indigo : Colors.teal,
                                ),
                              ),
                            )),
                            DataCell(Text(c.phone)),
                            DataCell(Text('${currencyFormat.format(c.creditLimit)} ج.س')),
                            DataCell(Row(
                              children: [
                                Text(
                                  '${currencyFormat.format(c.currentBalance)} ج.س',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isLimitExceeded ? AppTheme.dangerRed : Colors.black87,
                                  ),
                                ),
                                if (isLimitExceeded)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.warning, color: AppTheme.dangerRed, size: 16),
                                  ),
                              ],
                            )),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue),
                                  tooltip: 'كشف حساب تفصيلي',
                                  onPressed: () => _showStatementDialog(context, c.id!),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.payments_rounded, color: AppTheme.successGreen),
                                  tooltip: 'سداد دفعة نقدية',
                                  onPressed: () => _showRecordPaymentDialog(context, c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'تعديل البيانات',
                                  onPressed: () => _showAddCustomerDialog(context, existingCustomer: c),
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
