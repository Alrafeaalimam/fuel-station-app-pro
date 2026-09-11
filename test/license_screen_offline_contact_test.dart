import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_app_pro/screens/license/license_screen.dart';
import 'package:fuel_station_app_pro/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LicenseScreen displays offline contact phone and copies on button tap', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Setup cached notifier so screen doesn't get stuck loading
    LicenseService.licenseNotifier.value = LicenseInfo(
      status: LicenseStatus.expired,
      deviceCode: 'TEST-CODE',
      daysRemaining: 0,
      firstRunDate: DateTime.now().subtract(const Duration(days: 8)),
      errorMessage: 'انتهت الفترة التجريبية (7 أيام). يرجى شراء ترخيص دائم لمتابعة استخدام البرنامج.',
    );

    // Mock clipboard channel
    final List<MethodCall> clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        clipboardCalls.add(methodCall);
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: LicenseScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify WhatsApp button is present
    expect(find.text('تواصل مع المطوّر للحصول على الترخيص (واتساب)'), findsOneWidget);

    // 2. Verify offline phone label and phone number are present
    expect(find.text('أو تواصل عبر الرقم:'), findsOneWidget);
    expect(find.text('0115715672'), findsOneWidget);

    // 3. Verify copy phone button is present
    final copyPhoneBtn = find.widgetWithText(OutlinedButton, 'نسخ الرقم');
    expect(copyPhoneBtn, findsOneWidget);

    await tester.ensureVisible(copyPhoneBtn);
    await tester.pumpAndSettle();

    // 4. Tap copy phone button
    await tester.tap(copyPhoneBtn);
    await tester.pump();

    // Verify clipboard received the phone number
    final hasPhoneCopied = clipboardCalls.any((call) =>
        call.method == 'Clipboard.setData' &&
        call.arguments is Map &&
        (call.arguments as Map)['text'] == '0115715672');
    expect(hasPhoneCopied, isTrue, reason: 'Phone number 0115715672 must be copied to clipboard');

    // Verify snackbar is displayed
    expect(find.text('تم نسخ رقم التواصل (0115715672) إلى الحافظة بنجاح'), findsOneWidget);
  });
}
