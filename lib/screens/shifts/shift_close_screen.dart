import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/shift/shift_bloc.dart';
import '../../bloc/shift/shift_event.dart';
import '../../bloc/shift/shift_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'shift_report_screen.dart';

class ShiftCloseScreen extends StatefulWidget {
  const ShiftCloseScreen({super.key});

  @override
  State<ShiftCloseScreen> createState() => _ShiftCloseScreenState();
}

class _ShiftCloseScreenState extends State<ShiftCloseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Map to hold text controllers for each nozzle
  final Map<int, TextEditingController> _prevMeterControllers = {};
  final Map<int, TextEditingController> _currMeterControllers = {};

  // Controllers for the 2 tanks' current dip
  final Map<int, TextEditingController> _currDipControllers = {};

  // Payment Breakdown controllers
  final _cashController = TextEditingController(text: '0');
  final _bankTransferController = TextEditingController(text: '0');
  final _creditController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  // Credit customer transactions during this shift
  final List<CreditTransactionModel> _creditTxns = [];
  CustomerModel? _selectedCustomerForCredit;
  final _customerCreditAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    context.read<ShiftBloc>().add(LoadShiftClosingData());
    context.read<ShiftBloc>().add(LoadShiftHistory());
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      final historyStatus = context.read<ShiftBloc>().state.historyStatus;
      if (historyStatus == ShiftHistoryStatus.initial ||
          historyStatus == ShiftHistoryStatus.error) {
        context.read<ShiftBloc>().add(LoadShiftHistory());
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    for (var c in _prevMeterControllers.values) {
      c.dispose();
    }
    for (var c in _currMeterControllers.values) {
      c.dispose();
    }
    for (var c in _currDipControllers.values) {
      c.dispose();
    }
    _cashController.dispose();
    _bankTransferController.dispose();
    _creditController.dispose();
    _notesController.dispose();
    _customerCreditAmountController.dispose();
    super.dispose();
  }

  void _initControllersWithState(ShiftState state) {
    for (final p in state.pumpDataList) {
      final pid = p.pump.id!;
      if (!_prevMeterControllers.containsKey(pid)) {
        _prevMeterControllers[pid] =
            TextEditingController(text: p.previousMeter.toStringAsFixed(1));
      }
      if (!_currMeterControllers.containsKey(pid)) {
        _currMeterControllers[pid] =
            TextEditingController(text: p.previousMeter.toStringAsFixed(1));
      }
    }

    for (final t in state.tankDataList) {
      final tid = t.tank.id!;
      if (!_currDipControllers.containsKey(tid)) {
        _currDipControllers[tid] =
            TextEditingController(text: t.previousDip.toStringAsFixed(1));
      }
    }
  }

  double _getPumpLitersSold(int pumpId) {
    final prev = double.tryParse(_prevMeterControllers[pumpId]?.text ?? '') ?? 0.0;
    final curr = double.tryParse(_currMeterControllers[pumpId]?.text ?? '') ?? 0.0;
    return (curr - prev).clamp(0.0, double.infinity);
  }

  void _autoDistributeCash(double totalAmount) {
    final bank = double.tryParse(_bankTransferController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final remainingCash = (totalAmount - bank - credit).clamp(0.0, double.infinity);
    _cashController.text = remainingCash.toStringAsFixed(0);
    setState(() {});
  }

  void _submitShift(ShiftState state) {
    if (!_formKey.currentState!.validate()) return;

    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.id ?? 1 : 1;
    final now = DateTime.now().toIso8601String();

    final List<ShiftReadingModel> readings = [];
    final Map<int, double> tankNewDips = {};

    // Collect tank dips
    for (final t in state.tankDataList) {
      final tid = t.tank.id!;
      final currDip = double.tryParse(_currDipControllers[tid]?.text ?? '') ?? t.previousDip;
      tankNewDips[tid] = currDip;
    }

    // Collect pump readings
    for (final p in state.pumpDataList) {
      final pid = p.pump.id!;
      final prevMeter = double.tryParse(_prevMeterControllers[pid]?.text ?? '') ?? p.previousMeter;
      final currMeter = double.tryParse(_currMeterControllers[pid]?.text ?? '') ?? prevMeter;
      final litersSold = (currMeter - prevMeter).clamp(0.0, double.infinity);
      final totalAmount = litersSold * p.activePrice;

      final tankData = state.tankDataList.firstWhere((t) => t.tank.id == p.tank.id);
      final currentDip = tankNewDips[p.tank.id] ?? tankData.previousDip;

      // Tank surplus / deficit allocated
      final tankConsumed = (tankData.previousDip + tankData.deliveredDuringShift - currentDip);
      final surplusDeficit = litersSold - (tankConsumed / 4.0); // Nozzle's share approx

      readings.add(ShiftReadingModel(
        shiftId: 0,
        pumpId: pid,
        previousMeter: prevMeter,
        currentMeter: currMeter,
        litersSold: litersSold,
        previousDip: tankData.previousDip,
        currentDip: currentDip,
        deliveredLitersDuringShift: tankData.deliveredDuringShift,
        surplusDeficit: surplusDeficit,
        pricePerLiter: p.activePrice,
        totalAmount: totalAmount,
      ));
    }

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final bank = double.tryParse(_bankTransferController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final totalPayment = cash + bank + credit;

    final shift = ShiftModel(
      closedByUserId: userId,
      closeDatetime: now,
      status: 'closed',
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    final summary = SalesSummaryModel(
      shiftId: 0,
      cashAmount: cash,
      bankTransferAmount: bank,
      creditAmount: credit,
      totalAmount: totalPayment,
    );

    context.read<ShiftBloc>().add(SubmitCloseShiftRequested(
          shift: shift,
          readings: readings,
          summary: summary,
          tankNewDips: tankNewDips,
          creditTransactions: _creditTxns,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat('#,##0.0', 'en_US');
    final currencyFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'قفل الوردية وإغلاق الحسابات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(icon: Icon(Icons.edit_calendar_rounded), text: 'إدخال قفل الوردية الحالية'),
            Tab(icon: Icon(Icons.history_rounded), text: 'سجل الورديات السابقة'),
          ],
        ),
      ),
      body: BlocConsumer<ShiftBloc, ShiftState>(
        listenWhen: (previous, current) =>
            previous.closeSuccess != current.closeSuccess ||
            previous.submitErrorMessage != current.submitErrorMessage,
        listener: (context, state) {
          if (state.closeSuccess != null) {
            final success = state.closeSuccess!;
            // Immediately clear the submission status in BLoC so subsequent emits never re-trigger
            context.read<ShiftBloc>().add(ResetShiftCloseStatus());

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success.message),
                backgroundColor: AppTheme.successGreen,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'عرض تقرير اليومية',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShiftReportScreen(shiftId: success.shiftId),
                      ),
                    );
                  },
                ),
              ),
            );

            // Cleanly reset controllers & memory state for a fresh shift
            _creditTxns.clear();
            _notesController.clear();
            _cashController.text = '0';
            _bankTransferController.text = '0';
            _creditController.text = '0';
            _customerCreditAmountController.clear();
            _selectedCustomerForCredit = null;

            // Clear dynamic controllers safely without premature dispose
            _prevMeterControllers.clear();
            _currMeterControllers.clear();
            _currDipControllers.clear();

            context.read<ShiftBloc>().add(LoadShiftClosingData());
            context.read<ShiftBloc>().add(LoadShiftHistory());
            if (_tabController.index != 1) {
              _tabController.animateTo(1);
            }
          } else if (state.submitErrorMessage != null) {
            final errMsg = state.submitErrorMessage!;
            context.read<ShiftBloc>().add(ResetShiftCloseStatus());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errMsg),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          }
        },
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildClosingForm(context, state, numberFormat, currencyFormat),
              _buildShiftHistory(context, state, numberFormat, currencyFormat),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClosingForm(
    BuildContext context,
    ShiftState state,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
  ) {
    if (state.closingStatus == ShiftClosingStatus.loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('جاري تجهيز بيانات قفل الوردية...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (state.closingStatus == ShiftClosingStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 48),
              const SizedBox(height: 16),
              Text(
                state.closingErrorMessage ?? 'خطأ أثناء تجهيز بيانات قفل الوردية',
                style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<ShiftBloc>().add(LoadShiftClosingData()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.closingStatus != ShiftClosingStatus.loaded) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => context.read<ShiftBloc>().add(LoadShiftClosingData()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة تحميل بيانات الوردية'),
        ),
      );
    }

    _initControllersWithState(state);

    // Calculate totals across all 8 pumps
    double totalShiftLiters = 0.0;
    double totalShiftRevenue = 0.0;
    for (final p in state.pumpDataList) {
      final liters = _getPumpLitersSold(p.pump.id!);
      totalShiftLiters += liters;
      totalShiftRevenue += (liters * p.activePrice);
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner of closing info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.lastShift != null
                          ? 'آخر قفل وردية سابق كان بتاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(state.lastShift!.closeDatetime))}. تم جلب العدادات تلقائياً.'
                          : 'هذه أول وردية تُسجل على النظام. يمكنك إدخال العدادات والمسطرة الابتدائية يدوياً.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.primaryNavy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: 8 Nozzles / Pumps Readings Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '1. قراءات العدادات للفوهات (8 فوهات)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                Text(
                  'إجمالي الوقود المباع: ${numberFormat.format(totalShiftLiters)} لتر',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('الفوهة')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('العداد السابق')),
                      DataColumn(label: Text('العداد الحالي (القفل)')),
                      DataColumn(label: Text('اللترات المباعة')),
                      DataColumn(label: Text('السعر/لتر')),
                      DataColumn(label: Text('الإجمالي (ج.س)')),
                    ],
                    rows: state.pumpDataList.map((p) {
                      final pid = p.pump.id!;
                      final litersSold = _getPumpLitersSold(pid);
                      final rowTotal = litersSold * p.activePrice;
                      final isBenzin = p.tank.fuelType == 'بنزين';
                      final fuelColor =
                          isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;

                      return DataRow(
                        cells: [
                          DataCell(Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: fuelColor.withValues(alpha: 0.15),
                                child: Text(
                                  '${p.pump.nozzleNumber}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: fuelColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(p.pump.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          )),
                          DataCell(Text(
                            p.tank.fuelType,
                            style: TextStyle(color: fuelColor, fontWeight: FontWeight.bold),
                          )),
                          DataCell(SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _prevMeterControllers[pid],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => v == null || double.tryParse(v) == null
                                  ? 'خطأ'
                                  : null,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: _currMeterControllers[pid],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || double.tryParse(v) == null) return 'قيمة خاطئة';
                                final curr = double.tryParse(v)!;
                                final prev = double.tryParse(_prevMeterControllers[pid]?.text ?? '') ?? 0;
                                if (curr < prev) return 'أقل من السابق';
                                return null;
                              },
                            ),
                          )),
                          DataCell(Text(
                            numberFormat.format(litersSold),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataCell(Text('${currencyFormat.format(p.activePrice)} ج.س')),
                          DataCell(Text(
                            currencyFormat.format(rowTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Tanks Dip Ruler (المسطرة ومقارنة العجز / الفائض)
            const Text(
              '2. قراءات مسطرة الخزانات ومطابقة العجز / الفائض',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                return isNarrow
                    ? Column(
                        children: state.tankDataList
                            .map((t) => _buildTankDipCard(t, state, numberFormat))
                            .toList(),
                      )
                    : Row(
                        children: state.tankDataList
                            .map((t) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: _buildTankDipCard(t, state, numberFormat),
                                  ),
                                ))
                            .toList(),
                      );
              },
            ),
            const SizedBox(height: 24),

            // Section 3: Payment Breakdown & Credit Transactions
            const Text(
              '3. توزيع المتحصلات المالية وطرق الدفع',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إجمالي قيمة مبيعات الوردية: ${currencyFormat.format(totalShiftRevenue)} ج.س',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _autoDistributeCash(totalShiftRevenue),
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('ضبط المتبقي في النقدي تلقائياً'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 700;
                        return isNarrow
                            ? Column(
                                children: [
                                  _buildPaymentField('نقدي (كاش)', _cashController, Icons.money),
                                  const SizedBox(height: 12),
                                  _buildPaymentField('تحويل بنكي (بنكك)', _bankTransferController, Icons.account_balance),
                                  const SizedBox(height: 12),
                                  _buildPaymentField('مبيعات آجل (عملاء)', _creditController, Icons.credit_card),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildPaymentField(
                                        'نقدي (كاش)', _cashController, Icons.money),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildPaymentField(
                                        'تحويل بنكي (بنكك)',
                                        _bankTransferController,
                                        Icons.account_balance),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildPaymentField(
                                        'مبيعات آجل (عملاء)',
                                        _creditController,
                                        Icons.credit_card),
                                  ),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Add Customer Credit Sales Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تخصيص مبيعات الآجل للعملاء:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showAddCreditCustomerDialog(state.customers),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('إضافة سحب آجل لعميل'),
                        ),
                      ],
                    ),
                    if (_creditTxns.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _creditTxns.length,
                        itemBuilder: (context, index) {
                          final txn = _creditTxns[index];
                          final customer = state.customers.firstWhere(
                            (c) => c.id == txn.customerId,
                            orElse: () => CustomerModel(
                              id: txn.customerId,
                              name: 'عميل',
                              type: '',
                              phone: '',
                              creditLimit: 0,
                              currentBalance: 0,
                            ),
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 18, color: AppTheme.primaryBlue),
                                const SizedBox(width: 8),
                                Text(
                                  customer.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  'المبلغ: ${currencyFormat.format(txn.amount)} ج.س',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed),
                                  onPressed: () {
                                    setState(() {
                                      _creditTxns.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات الوردية (اختياري)',
                        hintText: 'أدخل أي ملاحظات حول قفل الوردية أو الأعطال أو الفروقات...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  elevation: 2,
                ),
                onPressed: () => _submitShift(state),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                label: const Text(
                  'اعتماد وقفل الوردية وترحيل الخزنة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: 'ج.س',
      ),
      onChanged: (_) => setState(() {}),
      validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل قيمة صحيحة' : null,
    );
  }

  Widget _buildTankDipCard(
    TankShiftInitData tankData,
    ShiftState state,
    NumberFormat numberFormat,
  ) {
    final tid = tankData.tank.id!;
    final isBenzin = tankData.tank.fuelType == 'بنزين';
    final fuelColor = isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;

    // Calculate sum of pump meters for this tank
    double pumpsSold = 0.0;
    for (final p in state.pumpDataList.where((p) => p.tank.id == tid)) {
      pumpsSold += _getPumpLitersSold(p.pump.id!);
    }

    final currDip = double.tryParse(_currDipControllers[tid]?.text ?? '') ?? tankData.previousDip;
    final tankDrawn = (tankData.previousDip + tankData.deliveredDuringShift - currDip);
    final diff = pumpsSold - tankDrawn; // positive = surplus, negative = deficit

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: fuelColor),
                const SizedBox(width: 8),
                Text(
                  '${tankData.tank.name} (${tankData.tank.fuelType})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المسطرة السابقة: ${numberFormat.format(tankData.previousDip)} لتر'),
                Text('الوارد أثناء الوردية: ${numberFormat.format(tankData.deliveredDuringShift)} لتر'),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _currDipControllers[tid],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قراءة المسطرة عند القفل (لتر)',
                suffixText: 'لتر',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل قراءة المسطرة' : null,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (diff >= 0 ? AppTheme.successGreen : AppTheme.dangerRed).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    diff >= 0 ? 'فائض المسطرة:' : 'عجز المسطرة:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: diff >= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                    ),
                  ),
                  Text(
                    '${diff >= 0 ? "+" : ""}${numberFormat.format(diff)} لتر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: diff >= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCreditCustomerDialog(List<CustomerModel> customers) {
    _selectedCustomerForCredit = customers.isNotEmpty ? customers.first : null;
    _customerCreditAmountController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cust = _selectedCustomerForCredit;
            final isLimitWarning = cust != null &&
                (cust.currentBalance + (double.tryParse(_customerCreditAmountController.text) ?? 0)) >
                    cust.creditLimit;

            return AlertDialog(
              title: const Text('تسجيل مبيعات آجل لعميل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<CustomerModel>(
                    initialValue: cust,
                    decoration: const InputDecoration(labelText: 'اختر العميل'),
                    items: customers.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (${c.type})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        _selectedCustomerForCredit = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (cust != null) ...[
                    Text(
                      'الرصيد المستحق الحالي: ${NumberFormat('#,##0').format(cust.currentBalance)} ج.س / السقف: ${NumberFormat('#,##0').format(cust.creditLimit)} ج.س',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _customerCreditAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المسحوب آجل (ج.س)',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (isLimitWarning) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 20),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'تنبيه: سيتجاوز العميل السقف الائتماني المحدد له.',
                              style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(_customerCreditAmountController.text);
                    if (amt != null && amt > 0 && _selectedCustomerForCredit != null) {
                      setState(() {
                        _creditTxns.add(CreditTransactionModel(
                          customerId: _selectedCustomerForCredit!.id!,
                          amount: amt,
                          type: 'charge',
                          transactionDate: DateTime.now().toIso8601String(),
                          notes: 'سحب آجل وردية',
                        ));
                        // Update total credit controller
                        double currentTotalCredit = double.tryParse(_creditController.text) ?? 0;
                        _creditController.text = (currentTotalCredit + amt).toStringAsFixed(0);
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShiftHistory(
    BuildContext context,
    ShiftState state,
    NumberFormat numberFormat,
    NumberFormat currencyFormat,
  ) {
    // 1. Independent Error Check First (never masked by loading)
    if (state.historyStatus == ShiftHistoryStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 56),
              const SizedBox(height: 16),
              Text(
                state.historyErrorMessage ?? 'حدث خطأ غير متوقع أثناء استرجاع سجل الورديات',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.dangerRed,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<ShiftBloc>().add(LoadShiftHistory()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Loading State (or Initial before first trigger)
    if (state.historyStatus == ShiftHistoryStatus.loading ||
        state.historyStatus == ShiftHistoryStatus.initial) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'جاري تحميل سجل الورديات السابقة...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 3. Empty State (No records found, clean message with refresh button)
    if (state.historyStatus == ShiftHistoryStatus.empty ||
        (state.historyStatus == ShiftHistoryStatus.loaded && state.shifts.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'لا توجد ورديات سابقة مسجلة بعد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.read<ShiftBloc>().add(LoadShiftHistory()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث السجل'),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Loaded Data State
    if (state.historyStatus == ShiftHistoryStatus.loaded) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<ShiftBloc>().add(LoadShiftHistory());
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.shifts.length,
          itemBuilder: (context, index) {
            final s = state.shifts[index];
            final date = DateTime.tryParse(s.closeDatetime) ?? DateTime.now();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '#${s.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                ),
                title: Text(
                  'وردية رقم #${s.id} - ${DateFormat('yyyy-MM-dd HH:mm').format(date)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  s.notes != null ? 'ملاحظات: ${s.notes}' : 'تم الإغلاق بنجاح',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        foregroundColor: AppTheme.primaryNavy,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShiftReportScreen(shiftId: s.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('تقرير اليومية / PDF'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        context.read<ShiftBloc>().add(LoadShiftDetailsRequested(s.id!));
                        _showShiftDetailsModal(context, s.id!);
                      },
                      child: const Text('عرض التفاصيل'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Center(
      child: OutlinedButton.icon(
        onPressed: () => context.read<ShiftBloc>().add(LoadShiftHistory()),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('تحميل السجل'),
      ),
    );
  }

  void _showShiftDetailsModal(BuildContext context, int shiftId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return BlocBuilder<ShiftBloc, ShiftState>(
          builder: (context, state) {
            if (state.detailsStatus == ShiftDetailsStatus.loaded && state.selectedDetails != null) {
              final details = state.selectedDetails!;
              final summary = details.summary;
              final currencyFormat = NumberFormat('#,##0', 'en_US');

              return AlertDialog(
                title: Text('تفاصيل وردية رقم #${details.shift.id}'),
                content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تاريخ القفل: ${details.shift.closeDatetime}'),
                        Text('تم القفل بواسطة: ${details.closedByUser?.name ?? "المستخدم"}'),
                        const Divider(),
                        if (summary != null) ...[
                          const Text('ملخص المبيعات:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('• إجمالي المبيعات: ${currencyFormat.format(summary.totalAmount)} ج.س'),
                          Text('• نقدي: ${currencyFormat.format(summary.cashAmount)} ج.س'),
                          Text('• بنكك: ${currencyFormat.format(summary.bankTransferAmount)} ج.س'),
                          Text('• آجل: ${currencyFormat.format(summary.creditAmount)} ج.س'),
                          const Divider(),
                        ],
                        const Text('قراءات الفوهات:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...details.readings.map((r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                  'فوهة #${r.pumpId}: سابق (${r.previousMeter}) -> قفل (${r.currentMeter}) = ${r.litersSold} لتر | الإجمالي: ${currencyFormat.format(r.totalAmount)} ج.س'),
                            )),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق'),
                  ),
                ],
              );
            } else if (state.detailsStatus == ShiftDetailsStatus.error) {
              return AlertDialog(
                title: const Text('خطأ'),
                content: Text(state.detailsErrorMessage ?? 'تعذر تحميل التفاصيل'),
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
}
