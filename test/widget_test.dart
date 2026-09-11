import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_app_pro/main.dart';
import 'package:fuel_station_app_pro/config/station_config.dart';

void main() {
  testWidgets('Fuel station app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FuelStationApp());
    expect(find.text(StationConfig.stationName), findsWidgets);
    expect(find.text('تسجيل الدخول للنظام (مدير المحطة / محاسب)'), findsWidgets);
  });
}
