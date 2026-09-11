import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/reports/reports_bloc.dart';
import '../bloc/reports/reports_event.dart';
import '../bloc/shift/shift_bloc.dart';
import '../bloc/shift/shift_event.dart';
import '../bloc/tanks/tank_bloc.dart';
import '../bloc/tanks/tank_event.dart';
import '../bloc/cash_box/cash_box_bloc.dart';
import '../bloc/cash_box/cash_box_event.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'shifts/shift_close_screen.dart';
import 'prices/fuel_prices_screen.dart';
import 'deliveries/deliveries_screen.dart';
import 'customers/customers_screen.dart';
import 'cash_box/cash_box_screen.dart';
import 'expenses/expenses_screen.dart';
import 'reports/reports_screen.dart';
import 'shifts/shift_report_screen.dart';
import 'users/users_management_screen.dart';
import 'backup/backup_screen.dart';
import 'tanks/tank_settings_screen.dart';
import '../widgets/change_password_dialog.dart';
import '../config/station_config.dart';
import '../utils/permission_guard.dart';
import '../services/license_service.dart';
import 'license/license_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;
  final ScrollController _sidebarScrollController = ScrollController();

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    super.dispose();
  }

  void _onSelectScreen(int index) {
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    if (index == 7 && !(currentUser?.can(AppPermission.viewStrategicReports) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة التقارير المالية الاستراتيجية (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (index == 9 && !(currentUser?.can(AppPermission.manageUsers) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة إدارة المستخدمين (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (index == 10 && !(currentUser?.can(AppPermission.manageBackup) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة النسخ الاحتياطي (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (index == 11 && !(currentUser?.can(AppPermission.manageTanks) ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح لك بالاطلاع على شاشة إعدادات الخزانات (صلاحية خاصة بالمدير).'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });

    // Auto refresh data for screens when navigated to
    if (index == 7) {
      context.read<ReportsBloc>().add(const LoadFinancialSummaryReport());
    } else if (index == 1) {
      context.read<ShiftBloc>().add(LoadShiftClosingData());
    } else if (index == 0) {
      context.read<TankBloc>().add(LoadTanksAndPumps());
      context.read<CashBoxBloc>().add(LoadCashBox());
    }
  }

  void _showEditStationNameDialog(BuildContext context) {
    final controller = TextEditingController(text: StationConfig.stationName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('تعديل اسم المحطة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيظهر هذا الاسم في ترويسة التطبيق والتقارير المطبوعة وشاشة الدخول.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'اسم المحطة',
                hintText: 'أدخل اسم المحطة الجديد',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
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
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await StationConfig.setStationName(newName);
                if (context.mounted) {
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تعديل اسم المحطة إلى: "$newName"'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    final List<Widget> screens = [
      DashboardScreen(onNavigate: _onSelectScreen),
      const ShiftCloseScreen(),
      const FuelPricesScreen(),
      const DeliveriesScreen(),
      const CustomersScreen(),
      const CashBoxScreen(),
      const ExpensesScreen(),
      (currentUser?.can(AppPermission.viewStrategicReports) ?? false)
          ? const ReportsScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على التقارير المالية الاستراتيجية والأرباح.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
      const ShiftReportScreen(),
      (currentUser?.can(AppPermission.manageUsers) ?? false)
          ? const UsersManagementScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على شاشة إدارة المستخدمين.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
      (currentUser?.can(AppPermission.manageBackup) ?? false)
          ? const BackupScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على شاشة النسخ الاحتياطي.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
      (currentUser?.can(AppPermission.manageTanks) ?? false)
          ? const TankSettingsScreen()
          : const Center(
              child: Text(
                'غير مصرح لك بالاطلاع على شاشة إعدادات الخزانات.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
              ),
            ),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          _buildSidebar(context, currentUser),
          // Main Content View
          Expanded(
            child: Column(
              children: [
                // Top App Header
                _buildTopHeader(context, currentUser),
                // Trial Warning Banner
                _buildTrialBanner(context),
                // Screen Content
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, UserModel? user) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: StationConfig.stationNameNotifier,
                builder: (context, stationName, _) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: user?.isManager == true
                        ? () => _showEditStationNameDialog(context)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_gas_station_rounded, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 6),
                          Text(
                            stationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                              fontSize: 13,
                            ),
                          ),
                          if (user?.isManager == true) ...[
                            const SizedBox(width: 6),
                            const Tooltip(
                              message: 'تعديل اسم المحطة',
                              child: Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          Row(
            children: [
              // User info badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: user?.isManager == true
                          ? AppTheme.primaryBlue
                          : AppTheme.dieselColor,
                      child: Text(
                        user?.name.substring(0, 1) ?? 'م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user?.name ?? 'المستخدم',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: user?.isManager == true
                            ? Colors.indigo.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user?.roleArabic ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: user?.isManager == true ? Colors.indigo : Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Change password button
              IconButton(
                icon: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryNavy),
                tooltip: 'تغيير كلمة المرور',
                onPressed: () {
                  if (user != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => ChangePasswordDialog(currentUser: user),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              // Logout button
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
                tooltip: 'تسجيل الخروج',
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner(BuildContext context) {
    return ValueListenableBuilder<LicenseInfo>(
      valueListenable: LicenseService.licenseNotifier,
      builder: (context, info, _) {
        if (!info.isTrial) return const SizedBox.shrink();

        final days = info.daysRemaining;
        final isUrgent = days <= 2;

        final bgColor = isUrgent ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE);
        final borderColor = isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);
        final textColor = isUrgent ? const Color(0xFF92400E) : const Color(0xFF0369A1);
        final icon = isUrgent ? Icons.warning_amber_rounded : Icons.hourglass_top_rounded;

        String dayText;
        if (days == 1) {
          dayText = 'متبقي يوم واحد فقط!';
        } else if (days == 2) {
          dayText = 'متبقي يومان فقط!';
        } else {
          dayText = 'متبقي $days أيام';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Text(
                'الفترة التجريبية: $dayText',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openActivationScreen(context),
                icon: const Icon(Icons.key_rounded, size: 14),
                label: const Text('تفعيل الترخيص الآن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openActivationScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LicenseScreen(isDismissible: true),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, UserModel? user) {
    return Material(
      color: AppTheme.sidebarBg,
      child: SizedBox(
        width: 240,
        child: Column(
        children: [
          // Station Brand Header
          Container(
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                Icon(Icons.local_gas_station_rounded, color: Colors.cyanAccent, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نظام المحطة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'إدارة وتشغيل الوقود',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Scrollable Area containing all navigation items, password action, and footer
          Expanded(
            child: Scrollbar(
              controller: _sidebarScrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _sidebarScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                children: [
                  _buildNavItem(0, 'لوحة التحكم', Icons.dashboard_rounded),
                  _buildNavItem(1, 'قفل الوردية', Icons.lock_clock_rounded),
                  _buildNavItem(2, 'تسعير الوقود', Icons.price_change_rounded),
                  _buildNavItem(3, 'سجل التوريد', Icons.local_shipping_rounded),
                  _buildNavItem(4, 'العملاء والآجل', Icons.people_alt_rounded),
                  _buildNavItem(5, 'الخزنة اليومية', Icons.account_balance_wallet_rounded),
                  _buildNavItem(6, 'المصروفات', Icons.receipt_long_rounded),
                  if (user?.can(AppPermission.viewStrategicReports) ?? false)
                    _buildNavItem(7, 'التقارير المالية', Icons.bar_chart_rounded),
                  _buildNavItem(8, 'تقرير اليومية (طباعة)', Icons.print_rounded),
                  if (user?.can(AppPermission.manageUsers) ?? false)
                    _buildNavItem(9, 'إدارة المستخدمين', Icons.manage_accounts_rounded),
                  if (user?.can(AppPermission.manageBackup) ?? false)
                    _buildNavItem(10, 'النسخ الاحتياطي', Icons.backup_rounded),
                  if (user?.can(AppPermission.manageTanks) ?? false)
                    _buildNavItem(11, 'إعدادات الخزانات', Icons.storage_rounded),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  // Change password shortcut
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: const Icon(Icons.lock_reset_rounded, color: Colors.white70, size: 20),
                    title: const Text(
                      'تغيير كلمة المرور',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    onTap: () {
                      if (user != null) {
                        showDialog(
                          context: context,
                          builder: (ctx) => ChangePasswordDialog(currentUser: user),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  // Footer version
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    child: Text(
                      'Windows / Web Desktop v1.0',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryBlue,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey.shade400,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        onTap: () => _onSelectScreen(index),
      ),
    );
  }
}
