import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/deliveries/delivery_bloc.dart';
import '../../bloc/deliveries/delivery_event.dart';
import '../../bloc/deliveries/delivery_state.dart';
import '../../bloc/tanks/tank_bloc.dart';
import '../../bloc/tanks/tank_event.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/permission_guard.dart';

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({super.key});

  @override
  State<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> {
  // New Delivery Dialog controllers
  SupplierModel? _selectedSupplier;
  TankModel? _selectedTank;
  final _litersController = TextEditingController();
  final _costPerLiterController = TextEditingController();

  // New Supplier Dialog controllers
  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<DeliveryBloc>().add(LoadDeliveriesAndSuppliers());
  }

  @override
  void dispose() {
    _litersController.dispose();
    _costPerLiterController.dispose();
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    super.dispose();
  }

  void _showRecordDeliveryDialog(BuildContext context, DeliveryLoaded state, int userId) {
    _selectedSupplier = state.suppliers.isNotEmpty ? state.suppliers.first : null;
    _selectedTank = state.tanks.isNotEmpty ? state.tanks.first : null;
    _litersController.clear();
    _costPerLiterController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final liters = double.tryParse(_litersController.text) ?? 0.0;
            final costPerLiter = double.tryParse(_costPerLiterController.text) ?? 0.0;
            final totalCost = liters * costPerLiter;

            return AlertDialog(
              title: const Text('تسجيل توريد وتفريغ شحنة جديدة'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'عند الحفظ، سيتم تحديث منسوب مسطرة الخزان تلقائياً بزيادة الكمية المفرغة.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      // Supplier selection
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<SupplierModel>(
                              initialValue: _selectedSupplier,
                              decoration: const InputDecoration(labelText: 'اسم المورد / الشركة'),
                              items: state.suppliers.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  _selectedSupplier = val;
                                });
                              },
                            ),
                          ),
                          if (context.read<AuthBloc>().state is AuthAuthenticated &&
                              (context.read<AuthBloc>().state as AuthAuthenticated).user.can(AppPermission.manageSuppliers)) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: AppTheme.primaryBlue),
                              tooltip: 'إضافة مورد جديد (خاص بالمدير)',
                              onPressed: () {
                                _showAddSupplierDialog(context);
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Tank selection
                      DropdownButtonFormField<TankModel>(
                        initialValue: _selectedTank,
                        decoration: const InputDecoration(labelText: 'الخزان المراد تفريغ الشحنة به'),
                        items: state.tanks.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text('${t.name} (${t.fuelType})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            _selectedTank = val;
                          });
                        },
                      ),
                      if (_selectedTank != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (_selectedTank!.capacityLiters > 0 &&
                                    (_selectedTank!.currentDipLiters + liters) > _selectedTank!.capacityLiters)
                                ? AppTheme.dangerRed.withValues(alpha: 0.1)
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_selectedTank!.capacityLiters > 0 &&
                                      (_selectedTank!.currentDipLiters + liters) > _selectedTank!.capacityLiters)
                                  ? AppTheme.dangerRed
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedTank!.capacityLiters > 0
                                        ? 'سعة الخزان: ${NumberFormat('#,##0').format(_selectedTank!.capacityLiters)} لتر'
                                        : 'سعة الخزان: لم تُحدَّد بعد',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedTank!.capacityLiters > 0
                                          ? Colors.black87
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                  Text(
                                    'المخزون الحالي: ${NumberFormat('#,##0').format(_selectedTank!.currentDipLiters)} لتر',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                ],
                              ),
                              if (_selectedTank!.capacityLiters > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'المساحة المتاحة للتفريغ: ${NumberFormat('#,##0').format((_selectedTank!.capacityLiters - _selectedTank!.currentDipLiters).clamp(0, double.infinity))} لتر',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: (_selectedTank!.currentDipLiters + liters) > _selectedTank!.capacityLiters
                                        ? AppTheme.dangerRed
                                        : AppTheme.successGreen,
                                  ),
                                ),
                                if (liters > 0 &&
                                    (_selectedTank!.currentDipLiters + liters) > _selectedTank!.capacityLiters) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '⚠️ تنبيه: الكمية المطلوبة ($liters لتر) تتجاوز سعة الخزان القصوى بمقدار ${NumberFormat('#,##0').format((_selectedTank!.currentDipLiters + liters) - _selectedTank!.capacityLiters)} لتر!',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.dangerRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Liters
                      TextFormField(
                        controller: _litersController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الكمية المفرغة (لتر)',
                          suffixText: 'لتر',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 14),
                      // Cost per liter
                      TextFormField(
                        controller: _costPerLiterController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر التكلفة للتر من المورد',
                          suffixText: 'ج.س',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي فاتورة الشحنة:'),
                            Text(
                              '${NumberFormat('#,##0').format(totalCost)} ج.س',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedSupplier == null || _selectedTank == null || liters <= 0 || costPerLiter <= 0) {
                      return;
                    }

                    if (_selectedTank!.capacityLiters > 0 &&
                        (_selectedTank!.currentDipLiters + liters) > _selectedTank!.capacityLiters) {
                      final maxAvailable =
                          (_selectedTank!.capacityLiters - _selectedTank!.currentDipLiters).clamp(0, double.infinity);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'لا يمكن تفريغ الشحنة! الكمية ستتجاوز سعة الخزان (${NumberFormat('#,##0').format(_selectedTank!.capacityLiters)} لتر).\n'
                            'المتاح للتفريغ حالياً: ${NumberFormat('#,##0').format(maxAvailable)} لتر فقط.',
                          ),
                          backgroundColor: AppTheme.dangerRed,
                          duration: const Duration(seconds: 6),
                        ),
                      );
                      return;
                    }

                    this.context.read<DeliveryBloc>().add(
                          RecordDeliveryRequested(
                            DeliveryModel(
                              supplierId: _selectedSupplier!.id!,
                              tankId: _selectedTank!.id!,
                              liters: liters,
                              costPerLiter: costPerLiter,
                              totalCost: totalCost,
                              deliveredAt: DateTime.now().toIso8601String(),
                              recordedByUserId: userId,
                            ),
                          ),
                        );
                    this.context.read<TankBloc>().add(LoadTanksAndPumps());
                    Navigator.pop(ctx);
                  },
                  child: const Text('تأكيد التفريغ والتسجيل'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    if (!(currentUser?.can(AppPermission.manageSuppliers) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بإضافة موردين جدد. هذه الصلاحية حصرية لمدير المحطة فقط.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    _supplierNameController.clear();
    _supplierPhoneController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إضافة مورد وقود جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _supplierNameController,
                decoration: const InputDecoration(labelText: 'اسم شركة التوريد أو المورد'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierPhoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
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
                if (_supplierNameController.text.trim().isNotEmpty) {
                  this.context.read<DeliveryBloc>().add(
                        AddSupplierRequested(
                          SupplierModel(
                            name: _supplierNameController.text.trim(),
                            phone: _supplierPhoneController.text.trim(),
                          ),
                          user: currentUser,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ المورد'),
            ),
          ],
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
          'سجل التوريد واستلام شحنات الوقود',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: BlocBuilder<DeliveryBloc, DeliveryState>(
              builder: (context, state) {
                if (state is DeliveryLoaded) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                    onPressed: () => _showRecordDeliveryDialog(context, state, userId),
                    icon: const Icon(Icons.local_shipping_rounded, color: Colors.white),
                    label: const Text('تسجيل شحنة واردة فوراً'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      body: BlocConsumer<DeliveryBloc, DeliveryState>(
        listener: (context, state) {
          if (state is DeliveryActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          } else if (state is DeliveryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.dangerRed,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is DeliveryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DeliveryLoaded) {
            if (state.deliveries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد شحنات توريد مسجلة حتى الآن',
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showRecordDeliveryDialog(context, state, userId),
                      icon: const Icon(Icons.add),
                      label: const Text('تسجيل أول شحنة الآن'),
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
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('المورد')),
                        DataColumn(label: Text('الخزان المُفرَّغ به')),
                        DataColumn(label: Text('الكمية (لتر)')),
                        DataColumn(label: Text('التكلفة للتر')),
                        DataColumn(label: Text('إجمالي التكلفة')),
                        DataColumn(label: Text('تاريخ ووقت الاستلام')),
                      ],
                      rows: state.deliveries.map((d) {
                        final supplier = state.suppliers.firstWhere(
                          (s) => s.id == d.supplierId,
                          orElse: () => SupplierModel(name: 'مورد #${d.supplierId}', phone: ''),
                        );
                        final tank = state.tanks.firstWhere(
                          (t) => t.id == d.tankId,
                          orElse: () => TankModel(
                            id: d.tankId,
                            name: 'خزان #${d.tankId}',
                            fuelType: '',
                            capacityLiters: 0,
                            currentDipLiters: 0,
                          ),
                        );

                        return DataRow(
                          cells: [
                            DataCell(Text('#${d.id}')),
                            DataCell(Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text('${tank.name} (${tank.fuelType})')),
                            DataCell(Text(
                              '${currencyFormat.format(d.liters)} لتر',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            )),
                            DataCell(Text('${currencyFormat.format(d.costPerLiter)} ج.س')),
                            DataCell(Text(
                              '${currencyFormat.format(d.totalCost)} ج.س',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(d.deliveredAt)),
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
