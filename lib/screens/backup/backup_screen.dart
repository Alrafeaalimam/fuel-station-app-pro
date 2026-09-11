import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../data/repositories/backup_repository.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/permission_guard.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = true;
  String? _dbPath;
  int _dbSize = 0;
  DateTime? _lastManualBackupDate;
  bool _showWeeklyReminder = false;
  List<File> _autoBackups = [];

  bool _isDismissedThisSession = false;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<BackupRepository>();
      final path = await repo.getDatabasePath();
      final size = await repo.getDatabaseSize();
      final lastDate = await repo.getLastManualBackupDate();
      final reminderNeeded = await repo.isManualBackupReminderNeeded();
      final autoFiles = await repo.getAutoBackups();

      if (mounted) {
        setState(() {
          _dbPath = path;
          _dbSize = size;
          _lastManualBackupDate = lastDate;
          _showWeeklyReminder = reminderNeeded && !_isDismissedThisSession;
          _autoBackups = autoFiles;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleManualBackup(UserModel user) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(now);
    final defaultFileName = 'fuel_station_backup_$dateStr.db';

    try {
      final repo = context.read<BackupRepository>();
      final bytes = await repo.getDatabaseBytes(user: user);

      final saveUri = await FilePicker.saveFile(
        dialogTitle: 'اختر موقع حفظ النسخة الاحتياطية',
        fileName: defaultFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (saveUri == null) return;

      final targetPath = saveUri.scheme == 'file' ? saveUri.toFilePath() : saveUri.path;
      await repo.setLastManualBackupDate(DateTime.now());

      if (mounted) {
        await _loadBackupInfo();
        _showSuccessDialog(
          title: 'تم إنشاء النسخة الاحتياطية بنجاح',
          message: 'تم حفظ نسخة كاملة من قاعدة البيانات في المسار التالي:\n\n$targetPath',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('فشل إنشاء النسخة الاحتياطية: $e');
      }
    }
  }

  Future<void> _handleRestoreBackup(UserModel user, {String? directFilePath}) async {
    String? filePathToRestore = directFilePath;

    if (filePathToRestore == null) {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'اختر ملف النسخة الاحتياطية (.db)',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (picked == null || picked.path == null) return;
      filePathToRestore = picked.path;
    }

    if (filePathToRestore == null || !mounted) return;
    final confirmedPath = filePathToRestore;

    // Show Critical Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.dangerRed, size: 28),
            SizedBox(width: 8),
            Text('تحذير استعادة البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم استبدال كل البيانات الحالية بالكامل بالنسخة المختارة. هذا الإجراء لا يمكن التراجع عنه.\n\nهل أنت متأكد تماماً من المتابعة؟',
              style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'الملف المختار: ${p.basename(confirmedPath)}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: const Text('تأكيد الاستبدال والاستعادة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final repo = context.read<BackupRepository>();
      await repo.restoreBackup(confirmedPath, user: user);

      if (mounted) {
        await _loadBackupInfo();
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 26),
                SizedBox(width: 8),
                Text('اكتملت الاستعادة بنجاح'),
              ],
            ),
            content: const Text(
              'تمت استعادة قاعدة البيانات وتحديث النظام بالكامل.\nيُوصى بإعادة تشغيل التطبيق أو تسجيل الخروج وإعادة الدخول لضمان تحديث كافة الجداول النشطة في الذاكرة.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('فشل استعادة النسخة الاحتياطية: $e');
      }
    }
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 24),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 24),
            SizedBox(width: 8),
            Text('خطأ', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    if (currentUser == null || !currentUser.can(AppPermission.manageBackup)) {
      return const Center(
        child: Text(
          'غير مصرح لك بالاطلاع على شاشة النسخ الاحتياطي.\nهذه الصلاحية خاصة بمدير المحطة فقط.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'النسخ الاحتياطي واستعادة البيانات',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'حماية بيانات المحطة عبر النسخ اليدوي الخارجي والنسخ التلقائي اليومي',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  onPressed: _loadBackupInfo,
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        // Weekly Reminder Banner
                        if (_showWeeklyReminder) ...[
                          _buildWeeklyReminderBanner(currentUser),
                          const SizedBox(height: 16),
                        ],

                        // Main Actions & DB Status
                        _buildStatusAndActionsCard(currentUser),
                        const SizedBox(height: 20),

                        // Automatic Backups Section
                        _buildAutoBackupsSection(currentUser),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyReminderBanner(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تذكير أسبوعي هام: يُوصى بعمل نسخة احتياطية يدوية جديدة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastManualBackupDate == null
                      ? 'لم يتم عمل أي نسخة احتياطية يدوية حتى الآن. يُرجى حفظ نسخة على فلاشة USB أو سحابة.'
                      : 'آخر نسخة يدوية مسجلة كانت بتاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(_lastManualBackupDate!)} (منذ أكثر من 7 أيام).',
                  style: TextStyle(fontSize: 13, color: Colors.brown.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _handleManualBackup(user),
            icon: const Icon(Icons.backup_rounded, size: 16),
            label: const Text('نسخ الآن'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() {
              _showWeeklyReminder = false;
              _isDismissedThisSession = true;
            }),
            child: const Text('تجاهل مؤقتاً', style: TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndActionsCard(UserModel user) {
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage_rounded, color: AppTheme.primaryBlue, size: 22),
                SizedBox(width: 8),
                Text(
                  'حالة قاعدة البيانات الحالية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مسار قاعدة البيانات النشطة:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      SelectableText(
                        _dbPath ?? 'جاري التحميل...',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('حجم البيانات', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(_dbSize),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  _lastManualBackupDate != null ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: _lastManualBackupDate != null ? AppTheme.successGreen : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  'آخر نسخة احتياطية يدوية: ',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  _lastManualBackupDate != null
                      ? dateFormat.format(_lastManualBackupDate!)
                      : 'لا توجد نسخة يدوية سابقة مسجلة',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleManualBackup(user),
                    icon: const Icon(Icons.save_alt_rounded, size: 20),
                    label: const Text(
                      'إنشاء نسخة احتياطية الآن (حفظ باسم)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: const BorderSide(color: AppTheme.dangerRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleRestoreBackup(user),
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 20),
                    label: const Text(
                      'استعادة نسخة احتياطية من ملف (.db)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoBackupsSection(UserModel user) {
    return Card(
      elevation: 0,
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
                const Row(
                  children: [
                    Icon(Icons.auto_mode_rounded, color: Colors.indigo, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'النسخ الاحتياطي التلقائي (عند قفل الورديات)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'العدد: ${_autoBackups.length} / 14 كحد أقصى',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Critical Hardware Disclaimer Note (Requirement 4)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'تنبيه أمني وإرشادي:\nهذه النسخ التلقائية تُنشأ في مجلد محلي على نفس القرص الصلب الخاص بهذا الجهاز عند إغلاق كل وردية (مع الاحتفاظ بآخر 14 نسخة فقط دورياً). لا تغني هذه النسخ إطلاقاً عن عمل "نسخة احتياطية يدوية" بانتظام وحفظها على وسيط تخزين منفصل (فلاشة USB أو سحابة إلكترونية)، تحسباً لعطل الجهاز أو تلف القرص الصلب.',
                      style: TextStyle(fontSize: 12, height: 1.5, color: Colors.red.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_autoBackups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'لم يتم إنشاء نسخ تلقائية بعد.\nستظهر أول نسخة تلقائية تلقائياً فور قفل أول وردية بنجاح.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _autoBackups.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final file = _autoBackups[index];
                  final filename = p.basename(file.path);
                  final stat = file.statSync();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigoAccent,
                      radius: 18,
                      child: Icon(Icons.backup_table_rounded, color: Colors.white, size: 18),
                    ),
                    title: Text(filename, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(stat.modified)} | الحجم: ${_formatFileSize(stat.size)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade50,
                        foregroundColor: Colors.indigo.shade800,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('استعادة هذه النسخة'),
                      onPressed: () => _handleRestoreBackup(user, directFilePath: file.path),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
