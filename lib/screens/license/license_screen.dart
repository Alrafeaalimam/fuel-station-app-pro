import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/license_service.dart';
import '../../theme/app_theme.dart';

/// شاشة تفعيل ترخيص تطبيق محطة الوقود وانتهاء الفترة التجريبية
class LicenseScreen extends StatefulWidget {
  final bool isDismissible;

  const LicenseScreen({
    super.key,
    this.isDismissible = false,
  });

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _keyController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _deviceCode;
  late bool _isLoading;
  bool _isActivating = false;
  String? _errorMessage;
  LicenseInfo? _licenseInfo;

  @override
  void initState() {
    super.initState();
    final cached = LicenseService.licenseNotifier.value;
    if (cached.deviceCode != 'LOADING' && cached.deviceCode.isNotEmpty) {
      _deviceCode = cached.deviceCode;
      _licenseInfo = cached;
      _errorMessage = cached.errorMessage;
      _isLoading = false;
    } else {
      _deviceCode = '...';
      _isLoading = true;
    }
    _loadDeviceAndLicense();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceAndLicense() async {
    if (_deviceCode == '...') {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final code = await LicenseService.getDeviceCode();
      final info = await LicenseService.checkLicenseStatus();
      if (mounted) {
        setState(() {
          _deviceCode = code;
          _licenseInfo = info;
          _isLoading = false;
          if (info.errorMessage != null) {
            _errorMessage = info.errorMessage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceCode = 'ERROR';
          _errorMessage = 'تعذر استخراج معرف الجهاز: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleActivation() async {
    if (!_formKey.currentState!.validate()) return;

    final inputKey = _keyController.text.trim();
    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final success = await LicenseService.activateLicense(inputKey: inputKey);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ تم تفعيل ترخيص محطة الوقود بنجاح! تم فتح كافة الميزات والتقارير.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: Duration(seconds: 4),
        ),
      );

      if (widget.isDismissible && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isActivating = false;
        _errorMessage = 'كود التفعيل غير صحيح أو لا يتطابق مع معرف هذا الجهاز تحديداً.';
      });
    }
  }

  Future<void> _copyDeviceCode() async {
    await Clipboard.setData(ClipboardData(text: _deviceCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ معرف الجهاز ($_deviceCode) إلى الحافظة بنجاح'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _copyPhoneNumber() async {
    const phoneNumber = '0115715672';
    await Clipboard.setData(const ClipboardData(text: phoneNumber));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رقم التواصل (0115715672) إلى الحافظة بنجاح'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final text = 'مرحباً، أريد الحصول على ترخيص لتطبيق محطة الوقود. معرف الجهاز: $_deviceCode';
    final url = 'https://wa.me/249115715672?text=${Uri.encodeComponent(text)}';

    // نسخ الرسالة للحافظة أيضاً لضمان وصولها
    await Clipboard.setData(ClipboardData(text: text));

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم فتح رابط واتساب ونسخ نص الرسالة للحافظة'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _licenseInfo?.status ?? LicenseStatus.expired;

    String headerTitle = 'انتهت الفترة التجريبية - يرجى التفعيل';
    IconData headerIcon = Icons.lock_clock_rounded;
    Color headerColor = AppTheme.dangerRed;

    if (status == LicenseStatus.tampered) {
      headerTitle = 'تنبيه أمني: انتهاء الفترة التجريبية';
      headerIcon = Icons.warning_amber_rounded;
      headerColor = AppTheme.warningOrange;
    } else if (status == LicenseStatus.mismatchedDevice) {
      headerTitle = 'ترخيص غير مطابق لهذا الجهاز';
      headerIcon = Icons.phonelink_erase_rounded;
      headerColor = AppTheme.dangerRed;
    } else if (status == LicenseStatus.trial) {
      headerTitle = 'تفعيل الترخيص التجاري الدائم';
      headerIcon = Icons.verified_user_rounded;
      headerColor = AppTheme.primaryBlue;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: widget.isDismissible
          ? AppBar(
              title: const Text('تفعيل الترخيص'),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // أيقونة الحالة العلوية
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: headerColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(headerIcon, size: 40, color: headerColor),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // العنوان الرئيسي
                        Text(
                          headerTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // الوصف التوضيحي
                        Text(
                          status == LicenseStatus.trial
                              ? 'يمكنك الترقية إلى ترخيص تجاري دائم عبر إدخال كود التفعيل المعتمد.'
                              : 'لتفعيل البرنامج ومتابعة إدارة محطة الوقود وقفل الورديات والتقارير، يرجى تزويد المطوّر بمعرف الجهاز للحصول على كود التفعيل.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // بطاقة كود الجهاز (Device ID)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.desktop_windows_rounded, size: 16, color: AppTheme.primaryBlue),
                                  SizedBox(width: 6),
                                  Text(
                                    'معرّف الجهاز الخاص بك (Device ID):',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_isLoading)
                                const SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Text(
                                  _deviceCode,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4,
                                    color: AppTheme.primaryBlue,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _isLoading ? null : _copyDeviceCode,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('نسخ معرّف الجهاز', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // زر التواصل مع المطوّر عبر واتساب
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _openWhatsApp,
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                          label: const Text(
                            'تواصل مع المطوّر للحصول على الترخيص (واتساب)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // خيار التواصل في حال عدم توفر إنترنت أو واتساب على جهاز الكمبيوتر
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Icon(Icons.phone_android_rounded, size: 18, color: AppTheme.primaryBlue),
                              const Text(
                                'أو تواصل عبر الرقم:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  '0115715672',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primaryBlue,
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _copyPhoneNumber,
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text('نسخ الرقم', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Divider(),
                        const SizedBox(height: 16),

                        // حقل إدخال كود التفعيل
                        const Text(
                          'أدخل كود التفعيل المستلم (Activation Key):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _keyController,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            fontFamily: 'monospace',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            hintText: 'XXXX-XXXX',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              letterSpacing: 2,
                              fontSize: 16,
                            ),
                            prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryBlue),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال كود التفعيل';
                            }
                            final clean = value.replaceAll('-', '').replaceAll(' ', '').trim();
                            if (clean.length < 8) {
                              return 'كود التفعيل يجب أن يتكون من 8 خانات (مثال: XXXX-XXXX)';
                            }
                            return null;
                          },
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.dangerRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // زر اعتماد التفعيل
                        ElevatedButton(
                          onPressed: _isActivating || _isLoading ? null : _handleActivation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isActivating
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'تفعيل التطبيق',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
