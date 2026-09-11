import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../data/database_helper.dart';

/// حالات ترخيص التطبيق
enum LicenseStatus {
  trial,             // قيد الفترة التجريبية (7 أيام)
  active,            // مفعّل تجارياً برمز دائم مطابق
  expired,           // انتهت الفترة التجريبية (مرور 7 أيام)
  tampered,          // تم اكتشاف تلاعب بتاريخ وساعة النظام
  mismatchedDevice,  // تم نقل قاعدة البيانات لجهاز آخر بكود غير مطابق
}

/// بيانات حالة الترخيص
class LicenseInfo {
  final LicenseStatus status;
  final String deviceCode;
  final int daysRemaining;
  final DateTime? firstRunDate;
  final DateTime? lastSeenDate;
  final DateTime? activatedAt;
  final String? activationKey;
  final String? errorMessage;

  const LicenseInfo({
    required this.status,
    required this.deviceCode,
    required this.daysRemaining,
    this.firstRunDate,
    this.lastSeenDate,
    this.activatedAt,
    this.activationKey,
    this.errorMessage,
  });

  bool get isOperational =>
      status == LicenseStatus.active || status == LicenseStatus.trial;

  bool get isTrial => status == LicenseStatus.trial;
  bool get isActivated => status == LicenseStatus.active;
}

/// خدمة إدارة الترخيص وبصمة الجهاز والفترة التجريبية لنظام محطة الوقود Pro
class LicenseService {
  // المفتاح السري الموحد لتشفير وتوليد أكواد الترخيص (مطابق لأداة admin_dashboard.py)
  static const String licenseSecretKey = 'STR-SEC-2026-X9K7-W4B8-9841F3E8';

  // المحارف المستخدمة (Base32 مستبعد منها 0, 1, I, O لمنع اللبس)
  static const String _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  // Notifier عام للاستماع لتغيرات حالة الترخيص في الواجهات
  static final ValueNotifier<LicenseInfo> licenseNotifier = ValueNotifier<LicenseInfo>(
    const LicenseInfo(
      status: LicenseStatus.trial,
      deviceCode: 'LOADING',
      daysRemaining: 7,
    ),
  );

  // متغيرات دعم الاختبارات والمحاكاة (Testing Overrides)
  static String? _mockRawDeviceId;
  static DateTime? _mockNow;

  @visibleForTesting
  static void setMockRawDeviceId(String? mockId) {
    _mockRawDeviceId = mockId;
  }

  @visibleForTesting
  static void setMockNow(DateTime? mockDateTime) {
    _mockNow = mockDateTime;
  }

  static DateTime get _now => _mockNow ?? DateTime.now();

  /// استخراج البصمة العتادية الثابتة للجهاز (Hardware Fingerprint)
  /// على Windows: يقرأ MachineGuid من السجل و UUID للوحة الأم والنظام عبر WMI / PowerShell
  static Future<String> getRawDeviceId() async {
    if (_mockRawDeviceId != null) {
      return _mockRawDeviceId!;
    }

    if (kIsWeb) {
      return 'WEB_CLIENT_INSTANCE_FUEL_STATION';
    }

    try {
      if (Platform.isWindows) {
        String guid = '';
        String wmiUuid = '';

        // 1. قراءة MachineGuid الفريد من Windows Registry
        try {
          final regResult = await Process.run('reg', [
            'query',
            r'HKLM\SOFTWARE\Microsoft\Cryptography',
            '/v',
            'MachineGuid',
          ]);
          if (regResult.exitCode == 0) {
            final output = regResult.stdout.toString();
            final match = RegExp(r'MachineGuid\s+REG_SZ\s+([^\r\n]+)').firstMatch(output);
            if (match != null) {
              guid = match.group(1)!.trim();
            }
          }
        } catch (_) {}

        // 2. قراءة UUID العتادي للنظام عبر PowerShell / WMI
        try {
          final psResult = await Process.run('powershell', [
            '-NoProfile',
            '-Command',
            r'(Get-CimInstance Win32_ComputerSystemProduct).UUID',
          ]);
          if (psResult.exitCode == 0) {
            wmiUuid = psResult.stdout.toString().trim();
          }
        } catch (_) {}

        if (guid.isNotEmpty || wmiUuid.isNotEmpty) {
          return 'WIN_HW:$guid:$wmiUuid';
        }

        // بديل عبر بيئة النظام واسم الكمبيوتر
        final compName = Platform.environment['COMPUTERNAME'] ?? 'WIN_PC';
        final userDomain = Platform.environment['USERDOMAIN'] ?? '';
        return 'WIN_ENV:$compName:$userDomain';
      } else if (Platform.isLinux) {
        // على Linux / Android / Termux: قراءة machine-id
        try {
          const machineIdPath = '/etc/machine-id';
          final f = File(machineIdPath);
          if (await f.exists()) {
            final id = (await f.readAsString()).trim();
            if (id.isNotEmpty) return 'LINUX_ID:$id';
          }
        } catch (_) {}

        final hostname = Platform.localHostname;
        return 'LINUX_HOST:$hostname';
      } else if (Platform.isMacOS) {
        try {
          final res = await Process.run('ioreg', ['-rd1', '-c', 'IOPlatformExpertDevice']);
          if (res.exitCode == 0) {
            final match = RegExp(r'"IOPlatformUUID"\s*=\s*"([^"]+)"').firstMatch(res.stdout.toString());
            if (match != null) return 'MAC_UUID:${match.group(1)}';
          }
        } catch (_) {}
        return 'MACOS_HOST:${Platform.localHostname}';
      }
    } catch (_) {}

    return 'FUEL_DEFAULT_FALLBACK_DEVICE_${Platform.operatingSystem}';
  }

  /// تحويل أي نص إلى كود من 8 خانات بصيغة XXXX-XXXX عبر SHA-256
  static String hashToCode(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    final hashBytes = digest.bytes;

    final buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      final charIndex = hashBytes[i] % _charset.length;
      buffer.write(_charset[charIndex]);
    }

    final raw = buffer.toString();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}';
  }

  /// كود الجهاز المقروء المكون من 8 خانات (مثلاً: A3F9-K2M1)
  static Future<String> getDeviceCode() async {
    final rawId = await getRawDeviceId();
    final payload = 'DEV:${rawId.trim()}:$licenseSecretKey';
    return hashToCode(payload);
  }

  /// توليد كود التفعيل المتوقع لجهاز معين (مطابق لأداة admin_dashboard.py)
  static String generateActivationKey(String deviceCode) {
    final cleanCode = deviceCode
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();
    final payload = 'LIC:$cleanCode:$licenseSecretKey';
    return hashToCode(payload);
  }

  /// التحقق من صحة كود التفعيل المدخل ومطابقته لكود الجهاز
  static bool validateActivationKey({
    required String deviceCode,
    required String inputKey,
  }) {
    final cleanInput = inputKey
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim()
        .toUpperCase();

    final expectedKey = generateActivationKey(deviceCode)
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .toUpperCase();

    return cleanInput.isNotEmpty && cleanInput == expectedKey;
  }

  /// التحقق من حالة الترخيص والفترة التجريبية من قاعدة البيانات
  static Future<LicenseInfo> checkLicenseStatus({
    DatabaseHelper? dbHelper,
    Database? customDb,
  }) async {
    final deviceCode = await getDeviceCode();
    final db = customDb ?? await (dbHelper ?? DatabaseHelper.instance).database;

    // 1. قراءة إعدادات الترخيص من جدول settings
    final settingsMaps = await db.query(
      'settings',
      where: 'key LIKE ?',
      whereArgs: ['license_%'],
    );
    final settings = <String, String>{};
    for (final row in settingsMaps) {
      settings[row['key'].toString()] = row['value'].toString();
    }

    final activationKey = settings['license_activation_key'];
    final activatedAtStr = settings['license_activated_at'];
    final firstRunStr = settings['license_first_run_date'];
    final lastSeenStr = settings['license_last_seen_date'];
    final clockTamperedStr = settings['license_clock_tampered'];

    // 2. التحقق مما إذا كان التطبيق مفعّلاً سابقاً
    if (activationKey != null && activationKey.isNotEmpty) {
      final isValid = validateActivationKey(
        deviceCode: deviceCode,
        inputKey: activationKey,
      );

      if (isValid) {
        final info = LicenseInfo(
          status: LicenseStatus.active,
          deviceCode: deviceCode,
          daysRemaining: 9999,
          activationKey: activationKey,
          activatedAt: activatedAtStr != null ? DateTime.tryParse(activatedAtStr) : null,
          firstRunDate: firstRunStr != null ? DateTime.tryParse(firstRunStr) : null,
        );
        licenseNotifier.value = info;
        return info;
      } else {
        // تم تفعيل المفتاح على جهاز آخر ونقل ملف قاعدة البيانات لهذا الجهاز!
        final info = LicenseInfo(
          status: LicenseStatus.mismatchedDevice,
          deviceCode: deviceCode,
          daysRemaining: 0,
          errorMessage: 'كود الترخيص المسجل لا يطابق هذا الجهاز. تم نقل قاعدة البيانات أو تغيير الجهاز.',
        );
        licenseNotifier.value = info;
        return info;
      }
    }

    // 3. التطبيق غير مفعّل - فحص الفترة التجريبية (7 أيام) وحماية الساعة
    final now = _now;

    // تحقق من علامة التلاعب السابقة
    if (clockTamperedStr == '1') {
      final info = LicenseInfo(
        status: LicenseStatus.tampered,
        deviceCode: deviceCode,
        daysRemaining: 0,
        errorMessage: 'تم إنهاء الفترة التجريبية لاكتشاف محاولة تغيير تاريخ/ساعة النظام.',
      );
      licenseNotifier.value = info;
      return info;
    }

    DateTime firstRunDate;
    if (firstRunStr == null) {
      // أول تشغيل للتطبيق على هذا الجهاز
      firstRunDate = now;
      await db.insert(
        'settings',
        {'key': 'license_first_run_date', 'value': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'settings',
        {'key': 'license_last_seen_date', 'value': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      firstRunDate = DateTime.tryParse(firstRunStr) ?? now;
    }

    // التحقق من التلاعب بتاريخ وساعة النظام
    if (lastSeenStr != null) {
      final lastSeen = DateTime.tryParse(lastSeenStr);
      if (lastSeen != null) {
        // إذا كان تاريخ النظام الحالي أقدم من آخر تاريخ مسجل بأكثر من 5 دقائق: تلاعب بالساعة!
        if (now.isBefore(lastSeen.subtract(const Duration(minutes: 5)))) {
          await db.insert(
            'settings',
            {'key': 'license_clock_tampered', 'value': '1'},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final info = LicenseInfo(
            status: LicenseStatus.tampered,
            deviceCode: deviceCode,
            daysRemaining: 0,
            firstRunDate: firstRunDate,
            lastSeenDate: lastSeen,
            errorMessage: 'تم اكتشاف محاولة إرجاع تاريخ النظام للخلف! انتهت الفترة التجريبية فوراً.',
          );
          licenseNotifier.value = info;
          return info;
        }
      }
    }

    // تحديث last_seen_date بالوقت الحالي
    await db.insert(
      'settings',
      {'key': 'license_last_seen_date', 'value': now.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // حساب الأيام المتبقية من الأيام السبعة
    final totalTrialDuration = const Duration(days: 7);
    final elapsed = now.difference(firstRunDate);

    if (elapsed >= totalTrialDuration || elapsed.isNegative) {
      final info = LicenseInfo(
        status: LicenseStatus.expired,
        deviceCode: deviceCode,
        daysRemaining: 0,
        firstRunDate: firstRunDate,
        lastSeenDate: now,
        errorMessage: 'انتهت الفترة التجريبية (7 أيام). يرجى تفعيل الترخيص لمتابعة استخدام البرنامج.',
      );
      licenseNotifier.value = info;
      return info;
    }

    // الأيام المتبقية: 7 - عدد الأيام المنقضية
    final secondsRemaining = totalTrialDuration.inSeconds - elapsed.inSeconds;
    int daysRemaining = (secondsRemaining / 86400).ceil();
    if (daysRemaining <= 0) daysRemaining = 1;
    if (daysRemaining > 7) daysRemaining = 7;

    final info = LicenseInfo(
      status: LicenseStatus.trial,
      deviceCode: deviceCode,
      daysRemaining: daysRemaining,
      firstRunDate: firstRunDate,
      lastSeenDate: now,
    );
    licenseNotifier.value = info;
    return info;
  }

  /// تفعيل الترخيص عند إدخال كود التفعيل الصحيح
  static Future<bool> activateLicense({
    required String inputKey,
    DatabaseHelper? dbHelper,
    Database? customDb,
  }) async {
    final deviceCode = await getDeviceCode();
    final isValid = validateActivationKey(
      deviceCode: deviceCode,
      inputKey: inputKey,
    );

    if (!isValid) {
      return false;
    }

    final db = customDb ?? await (dbHelper ?? DatabaseHelper.instance).database;
    final cleanKey = inputKey.replaceAll(' ', '').trim().toUpperCase();
    final nowStr = _now.toIso8601String();

    await db.insert(
      'settings',
      {'key': 'license_activation_key', 'value': cleanKey},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'settings',
      {'key': 'license_activated_at', 'value': nowStr},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'settings',
      {'key': 'license_status', 'value': 'active'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // تحديث الحالة فوراً
    await checkLicenseStatus(dbHelper: dbHelper, customDb: customDb);
    return true;
  }
}
