import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/tanks/tank_bloc.dart';
import '../../bloc/tanks/tank_event.dart';
import '../../bloc/tanks/tank_state.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/permission_guard.dart';

class TankSettingsScreen extends StatefulWidget {
  const TankSettingsScreen({super.key});

  @override
  State<TankSettingsScreen> createState() => _TankSettingsScreenState();
}

class _TankSettingsScreenState extends State<TankSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TankBloc>().add(LoadTanksAndPumps());
  }

  void _showEditCapacityDialog(BuildContext context, TankModel tank, UserModel? user) {
    final controller = TextEditingController(
      text: tank.capacityLiters > 0 ? tank.capacityLiters.toStringAsFixed(0) : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.storage_rounded, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text('تعديل سعة ${tank.name}'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'نوع الوقود: ${tank.fuelType}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'المخزون الحالي المقاس: ${NumberFormat('#,##0').format(tank.currentDipLiters)} لتر',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'حدد السعة الإجمالية القصوى للخزان باللتر. ستُستخدم لمنع الشحنات الزائدة وحساب نسبة الامتلاء الدقيقة.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'السعة القصوى للخزان (لتر)',
                  hintText: 'مثال: 45000',
                  suffixText: 'لتر',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال سعة الخزان';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'يرجى إدخال رقم موجب صحيح أو عشري أكبر من صفر';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final newCap = double.parse(controller.text.trim());
                context.read<TankBloc>().add(
                      UpdateTankCapacityRequested(
                        tankId: tank.id!,
                        capacityLiters: newCap,
                        user: user,
                      ),
                    );
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم تحديث سعة "${tank.name}" إلى ${NumberFormat('#,##0').format(newCap)} لتر بنجاح'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: const Text('حفظ السعة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final isManager = currentUser?.can(AppPermission.manageTanks) ?? false;

    if (!isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('إعدادات الخزانات')),
        body: const Center(
          child: Text(
            'غير مصرح لك بالاطلاع على إعدادات الخزانات.\nهذه الصلاحية حصرية لمدير المحطة فقط.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final numberFormat = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إعدادات وسعات الخزانات الرئيسية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<TankBloc>().add(LoadTanksAndPumps()),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث بيانات الخزانات',
          ),
        ],
      ),
      body: BlocConsumer<TankBloc, TankState>(
        listener: (context, state) {
          if (state is TankError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.dangerRed),
            );
          } else if (state is TankActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.successGreen),
            );
          }
        },
        builder: (context, state) {
          if (state is TankLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TankLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 28),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تحديد السعة القصوى للخزانات (خاص بالمدير)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'قم بضبط السعة القصوى الفعلية لكل خزان باللتر. يتحقق النظام تلقائياً من منع أي شحنة توريد تتجاوز هذه السعة، ويحسب نسبة الامتلاء بدقة.',
                                style: TextStyle(fontSize: 13, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'قائمة الخزانات',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                  const SizedBox(height: 16),
                  ...state.tanks.map((tank) {
                    final isBenzin = tank.fuelType == 'بنزين';
                    final fuelColor = isBenzin ? AppTheme.benzinColor : AppTheme.dieselColor;
                    final hasCap = tank.hasCapacity;
                    final pct = tank.fillPercentage;
                    final isOverfilled = hasCap && tank.currentDipLiters > tank.capacityLiters;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: fuelColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.storage_rounded, color: fuelColor, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tank.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'نوع الوقود: ${tank.fuelType}',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  onPressed: () => _showEditCapacityDialog(context, tank, currentUser),
                                  icon: const Icon(Icons.tune_rounded, size: 18),
                                  label: Text(hasCap ? 'تعديل السعة' : 'تحديد السعة'),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            // Metrics Grid
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    'السعة الكلية القصوى',
                                    hasCap ? '${numberFormat.format(tank.capacityLiters)} لتر' : 'لم تُحدَّد بعد',
                                    hasCap ? AppTheme.primaryNavy : Colors.amber.shade900,
                                    Icons.straighten_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricTile(
                                    'المخزون الحالي (المسطرة)',
                                    '${numberFormat.format(tank.currentDipLiters)} لتر',
                                    Colors.black87,
                                    Icons.opacity_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricTile(
                                    'نسبة الامتلاء',
                                    hasCap
                                        ? '${pct.toStringAsFixed(1)}%'
                                        : 'لم تُحدَّد السعة بعد',
                                    isOverfilled
                                        ? AppTheme.dangerRed
                                        : (hasCap ? fuelColor : Colors.amber.shade900),
                                    Icons.pie_chart_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildMetricTile(
                                    'المتاح للتفريغ',
                                    hasCap
                                        ? '${numberFormat.format((tank.capacityLiters - tank.currentDipLiters).clamp(0, double.infinity))} لتر'
                                        : 'لم تُحدَّد بعد',
                                    hasCap ? AppTheme.successGreen : Colors.grey.shade600,
                                    Icons.add_shopping_cart_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Level bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                height: 12,
                                child: LinearProgressIndicator(
                                  value: hasCap ? (pct / 100).clamp(0.0, 1.0) : 0.0,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isOverfilled ? AppTheme.dangerRed : fuelColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
