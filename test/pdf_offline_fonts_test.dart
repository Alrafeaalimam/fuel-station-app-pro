import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arabic fonts exist on disk and generate PDF completely offline without network', () async {
    final regularFile = File('assets/fonts/NotoNaskhArabic-Regular.ttf');
    final boldFile = File('assets/fonts/NotoNaskhArabic-Bold.ttf');

    // 1. Assert both font files exist physically on disk
    expect(regularFile.existsSync(), isTrue, reason: 'NotoNaskhArabic-Regular.ttf must exist on disk');
    expect(boldFile.existsSync(), isTrue, reason: 'NotoNaskhArabic-Bold.ttf must exist on disk');

    final regularBytes = await regularFile.readAsBytes();
    final boldBytes = await boldFile.readAsBytes();

    expect(regularBytes.length, greaterThan(50000));
    expect(boldBytes.length, greaterThan(50000));

    // 2. Instantiate pw.Font.ttf directly from local file bytes (100% offline, zero network)
    final regularFont = pw.Font.ttf(regularBytes.buffer.asByteData());
    final boldFont = pw.Font.ttf(boldBytes.buffer.asByteData());

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
          fontFallback: [
            pw.Font.helvetica(),
            pw.Font.helveticaBold(),
          ],
        ),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'محطة الوقود النموذجية - تقرير قفل الوردية (اليومية)',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'القسم الأول: الترويسة - سعر لتر البنزين: 1,250 ج.س | سعر لتر الجازولين: 1,150 ج.س',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'القسم الثاني: جدول المسطرة للخزانات - عجز/زيادة 0.0 جالون',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'القسم الثالث: إجمالي العدادات: 2,025,000 ج.س',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'القسم الرابع: إيراد نقدي: 1,025,000 ج.س | تحويل بنك: 800,000 ج.س',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'القسم الخامس: الصافي المحقق وتوقيع مدير المحطة',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    // 3. Save the PDF document to bytes
    final pdfBytes = await doc.save();
    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.length, greaterThan(1000));

    // 4. Verify PDF header
    final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
    expect(header, '%PDF-');

    print('SUCCESS: Local Arabic fonts loaded and PDF generated offline! (${pdfBytes.length} bytes)');
  });
}
