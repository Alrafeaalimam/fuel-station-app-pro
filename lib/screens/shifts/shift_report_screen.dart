import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/repositories/shift_repository.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../config/station_config.dart';

class ShiftReportScreen extends StatefulWidget {
  final int? shiftId;

  const ShiftReportScreen({super.key, this.shiftId});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  ShiftReportFullData? _reportData;
  List<ShiftModel> _allShifts = [];
  int? _currentShiftId;

  @override
  void initState() {
    super.initState();
    _currentShiftId = widget.shiftId;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shiftRepo = context.read<ShiftRepository>();
      final shifts = await shiftRepo.getAllShifts();
      _allShifts = shifts;

      int? targetId = _currentShiftId;
      if (targetId == null && shifts.isNotEmpty) {
        targetId = shifts.first.id;
      }

      if (targetId == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'لا توجد ورديات مقفولة مسجلة في قاعدة البيانات حتى الآن.';
        });
        return;
      }

      _currentShiftId = targetId;
      final data = await shiftRepo.getShiftReportFullData(targetId);

      if (data == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'لم يتم العثور على بيانات تفصيلية للوردية رقم #$targetId.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء تحميل بيانات تقرير الوردية: $e';
      });
    }
  }

  Future<void> _printOrExportPdf() async {
    if (_reportData == null) return;
    final data = _reportData!;
    final numFormat = NumberFormat('#,##0.0', 'en_US');
    final currFormat = NumberFormat('#,##0', 'en_US');

    try {
      final doc = pw.Document();

      // Load Arabic fonts from assets (Offline)
      pw.Font regularFont;
      pw.Font boldFont;

      try {
        final fontData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
        regularFont = pw.Font.ttf(fontData);
        final boldData = await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf');
        boldFont = pw.Font.ttf(boldData);
        debugPrint('✅ [PDF Font Loader] تم تحميل الخطوط العربية محلياً بنجاح (Offline 100%): NotoNaskhArabic-Regular & NotoNaskhArabic-Bold');
      } catch (e) {
        debugPrint('⚠️ [PDF Font Loader] تعذر تحميل الخطوط المحلية ($e)، سيتم استخدام Fallback سحابي');
        regularFont = await PdfGoogleFonts.cairoRegular();
        boldFont = await PdfGoogleFonts.cairoBold();
      }

      final pdfTheme = pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        fontFallback: [
          pw.Font.helvetica(),
          pw.Font.helveticaBold(),
        ],
      );

      final benzinTank = data.benzinTank;
      final dieselTank = data.dieselTank;
      final shiftDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(data.shift.closeDatetime));

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: pdfTheme,
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return [
              // ==========================================
              // القسم الأول: الترويسة
              // ==========================================
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${StationConfig.stationName} - تقرير قفل الوردية (اليومية)',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'وردية رقم #${data.shift.id}',
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('التاريخ والوقت: $shiftDate', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('المسؤول: ${data.closedByUser?.name ?? "المدير العام"}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'سعر لتر البنزين: ${currFormat.format(data.benzinPrice)} ج.س | سعر لتر الجازولين: ${currFormat.format(data.dieselPrice)} ج.س',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'فارق البنزين: ${numFormat.format(benzinTank?.diffGallons ?? 0)} جالون | فارق الجازولين: ${numFormat.format(dieselTank?.diffGallons ?? 0)} جالون',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // ==========================================
              // القسم الثاني: جدول قياس المسطرة للخزانات
              // ==========================================
              pw.Text('القسم الثاني: جدول قياس المسطرة للخزانات',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(1.8),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfHeaderCell('النوع'),
                      _pdfHeaderCell('مسطرة سابقة (لتر)'),
                      _pdfHeaderCell('الوارد (لتر)'),
                      _pdfHeaderCell('مسطرة حالية (لتر)'),
                      _pdfHeaderCell('عجز / زيادة (+/-)'),
                    ],
                  ),
                  _pdfTankRow(dieselTank, currFormat, numFormat, 'جازولين'),
                  _pdfTankRow(benzinTank, currFormat, numFormat, 'بنزين'),
                ],
              ),
              pw.SizedBox(height: 12),

              // ==========================================
              // القسم الثالث: جدول العدادات (8 فوهات)
              // ==========================================
              pw.Text('القسم الثالث: جدول العدادات (الفوهات)',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.5),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfHeaderCell('العدادات (الفوهات)'),
                      _pdfHeaderCell('عداد سابق'),
                      _pdfHeaderCell('عداد حالي'),
                      _pdfHeaderCell('المباع (لتر)'),
                      _pdfHeaderCell('المجموع (ج.س)'),
                    ],
                  ),
                  // فوهات البنزين
                  ...data.benzinPumps.map((p) => _pdfPumpRow(p, currFormat, numFormat)),
                  // مجموع البنزين
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.orange50),
                    children: [
                      _pdfCell('مجموع البنزين', isBold: true),
                      _pdfCell('-'),
                      _pdfCell('-'),
                      _pdfCell(numFormat.format(data.totalBenzinLiters), isBold: true),
                      _pdfCell('${currFormat.format(data.totalBenzinAmount)} ج.س', isBold: true),
                    ],
                  ),
                  // فوهات الجازولين
                  ...data.dieselPumps.map((p) => _pdfPumpRow(p, currFormat, numFormat)),
                  // مجموع الجازولين
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green50),
                    children: [
                      _pdfCell('مجموع الجازولين', isBold: true),
                      _pdfCell('-'),
                      _pdfCell('-'),
                      _pdfCell(numFormat.format(data.totalDieselLiters), isBold: true),
                      _pdfCell('${currFormat.format(data.totalDieselAmount)} ج.س', isBold: true),
                    ],
                  ),
                  // المجموع الكلي للعدادات
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _pdfCell('المجموع الكلي للعدادات', isBold: true),
                      _pdfCell('-'),
                      _pdfCell('-'),
                      _pdfCell(numFormat.format(data.totalMetersLiters), isBold: true),
                      _pdfCell('${currFormat.format(data.totalMetersAmount)} ج.س', isBold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // ==========================================
              // القسم الرابع: التحويلات المالية
              // ==========================================
              pw.Text('القسم الرابع: التحويلات المالية والمتحصلات',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                  4: pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfHeaderCell('تحويل بنك صباح'),
                      _pdfHeaderCell('تحويل بنك مساء'),
                      _pdfHeaderCell('إيراد نقدي'),
                      _pdfHeaderCell('المجموع'),
                      _pdfHeaderCell('متبقي التواريد'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _pdfCell('${currFormat.format(data.bankMorning)} ج.س'),
                      _pdfCell('${currFormat.format(data.bankEvening)} ج.س'),
                      _pdfCell('${currFormat.format(data.cashAmount)} ج.س', isBold: true),
                      _pdfCell('${currFormat.format(data.totalFinancialRevenue)} ج.س', isBold: true),
                      _pdfCell(
                        '${currFormat.format(data.remainingDeliveries)} ج.س',
                        isBold: true,
                        color: data.remainingDeliveries == 0 ? PdfColors.green800 : PdfColors.red800,
                      ),
                    ],
                  ),
                ],
              ),
              if (data.creditAmount > 0) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  color: PdfColors.amber50,
                  child: pw.Text(
                    '* يتضمن الإجمالي مبيعات آجل بمبلغ: ${currFormat.format(data.creditAmount)} ج.س مسجلة بحسابات العملاء.',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),
              ],
              pw.SizedBox(height: 12),

              // ==========================================
              // القسم الخامس: الخلاصة والتوقيع
              // ==========================================
              pw.Text('القسم الخامس: الخلاصة والاعتماد النهائي',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _pdfHeaderCell('جملة المباع'),
                      _pdfHeaderCell('المنصرف (المصروفات)'),
                      _pdfHeaderCell('الصافي'),
                      _pdfHeaderCell('توقيع مدير المحطة'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _pdfCell('${currFormat.format(data.totalMetersAmount)} ج.س', isBold: true),
                      _pdfCell('${currFormat.format(data.totalExpenses)} ج.س', isBold: true),
                      _pdfCell('${currFormat.format(data.netAmount)} ج.س',
                          isBold: true, color: PdfColors.blue800),
                      pw.Container(
                        height: 36,
                        alignment: pw.Alignment.bottomCenter,
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('التوقيع والخاتم: ........................',
                            style: const pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'اليومية_قفل_وردية_${data.shift.id}_$shiftDate.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل أثناء توليد الـ PDF للطباعة: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  static pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.Widget _pdfCell(String text, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.black,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  static pw.TableRow _pdfPumpRow(
    ShiftPumpRowData p,
    NumberFormat currFormat,
    NumberFormat numFormat,
  ) {
    return pw.TableRow(
      children: [
        _pdfCell(p.pump.name),
        _pdfCell(numFormat.format(p.reading.previousMeter)),
        _pdfCell(numFormat.format(p.reading.currentMeter)),
        _pdfCell(numFormat.format(p.reading.litersSold), isBold: true),
        _pdfCell('${currFormat.format(p.reading.totalAmount)} ج.س'),
      ],
    );
  }

  static pw.TableRow _pdfTankRow(
    TankReportData? tank,
    NumberFormat currFormat,
    NumberFormat numFormat,
    String fallbackName,
  ) {
    if (tank == null) {
      return pw.TableRow(
        children: [
          _pdfCell(fallbackName, isBold: true),
          _pdfCell('0.0'),
          _pdfCell('0.0'),
          _pdfCell('0.0'),
          _pdfCell('0.0 لتر'),
        ],
      );
    }

    final diffSign = tank.diffLiters >= 0 ? '+' : '';
    final diffText =
        '$diffSign${numFormat.format(tank.diffLiters)} لتر ($diffSign${numFormat.format(tank.diffGallons)} جالون)';

    return pw.TableRow(
      children: [
        _pdfCell(tank.tank.fuelType, isBold: true),
        _pdfCell(currFormat.format(tank.previousDip)),
        _pdfCell(currFormat.format(tank.delivered)),
        _pdfCell(currFormat.format(tank.currentDip)),
        _pdfCell(
          diffText,
          isBold: true,
          color: tank.diffLiters >= 0 ? PdfColors.green800 : PdfColors.red800,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'en_US');
    final numberFormat = NumberFormat('#,##0.0', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          'تقرير قفل الوردية (نموذج اليومية المطبوع)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          if (_allShifts.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _currentShiftId,
                  hint: const Text('اختر الوردية'),
                  items: _allShifts.map((s) {
                    final d = DateFormat('MM-dd HH:mm').format(DateTime.parse(s.closeDatetime));
                    return DropdownMenuItem<int>(
                      value: s.id,
                      child: Text('وردية #${s.id} ($d)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _currentShiftId) {
                      setState(() {
                        _currentShiftId = val;
                      });
                      _loadReport();
                    }
                  },
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل',
            onPressed: _loadReport,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _reportData != null ? _printOrExportPdf : null,
              icon: const Icon(Icons.print_rounded, size: 20),
              label: const Text('طباعة / تصدير PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _buildBody(currencyFormat, numberFormat),
    );
  }

  Widget _buildBody(NumberFormat currencyFormat, NumberFormat numberFormat) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 54),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _reportData!;
    final benzinTank = data.benzinTank;
    final dieselTank = data.dieselTank;
    final shiftDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(data.shift.closeDatetime));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==============================================================
              // القسم الأول: الترويسة
              // ==============================================================
              _buildSectionBanner(
                title: 'القسم الأول: الترويسة العامة والأسعار',
                subtitle: 'بيانات المحطة والتسعيرة الرسمية وفارق الجالونات',
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_gas_station_rounded, color: AppTheme.primaryNavy, size: 26),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<String>(
                              valueListenable: StationConfig.stationNameNotifier,
                              builder: (context, name, _) => Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'اليومية - وردية رقم #${data.shift.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('التاريخ: $shiftDate', style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                        Text('المسؤول: ${data.closedByUser?.name ?? "المدير العام"} (${data.closedByUser?.roleArabic ?? "مدير"})',
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildPriceBadge('بنزين', data.benzinPrice, AppTheme.benzinColor, currencyFormat),
                            const SizedBox(width: 12),
                            _buildPriceBadge('جازولين', data.dieselPrice, AppTheme.dieselColor, currencyFormat),
                          ],
                        ),
                        Row(
                          children: [
                            _buildGallonDiffBadge('فارق البنزين', benzinTank?.diffGallons ?? 0, benzinTank?.diffLiters ?? 0, numberFormat),
                            const SizedBox(width: 12),
                            _buildGallonDiffBadge('فارق الجازولين', dieselTank?.diffGallons ?? 0, dieselTank?.diffLiters ?? 0, numberFormat),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==============================================================
              // القسم الثاني: جدول قياس المسطرة للخزانات
              // ==============================================================
              _buildSectionBanner(
                title: 'القسم الثاني: جدول قياس المسطرة للخزانات',
                subtitle: 'مقارنة منسوب المسطرة السابق والوارد والمنسوب الحالي مع العجز/الزيادة',
              ),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1.8),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(2.6),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TableCellHeader('النوع'),
                      _TableCellHeader('مسطرة سابقة (لتر)'),
                      _TableCellHeader('الوارد (لتر)'),
                      _TableCellHeader('مسطرة حالية (لتر)'),
                      _TableCellHeader('عجز / زيادة (+/-)'),
                    ],
                  ),
                  _buildTankTableRow(dieselTank, currencyFormat, numberFormat, 'جازولين', AppTheme.dieselColor),
                  _buildTankTableRow(benzinTank, currencyFormat, numberFormat, 'بنزين', AppTheme.benzinColor),
                ],
              ),
              const SizedBox(height: 24),

              // ==============================================================
              // القسم الثالث: جدول العدادات (8 فوهات)
              // ==============================================================
              _buildSectionBanner(
                title: 'القسم الثالث: جدول العدادات (الفوهات الثمانية)',
                subtitle: 'قراءات الفوهات السابقة والحالية والمباع والقيمة الإجمالية',
              ),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(2.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TableCellHeader('العدادات (الفوهات)'),
                      _TableCellHeader('عداد سابق'),
                      _TableCellHeader('عداد حالي'),
                      _TableCellHeader('المباع (لتر)'),
                      _TableCellHeader('المجموع (ج.س)'),
                    ],
                  ),
                  // فوهات البنزين
                  ...data.benzinPumps.map((p) => _buildPumpTableRow(p, currencyFormat, numberFormat, AppTheme.benzinColor)),
                  // صف مجموع البنزين
                  TableRow(
                    decoration: BoxDecoration(color: AppTheme.benzinColor.withValues(alpha: 0.08)),
                    children: [
                      const _TableCellText('مجموع البنزين (4 فوهات)', isBold: true, color: AppTheme.benzinColor),
                      const _TableCellText('-'),
                      const _TableCellText('-'),
                      _TableCellText(numberFormat.format(data.totalBenzinLiters), isBold: true, color: AppTheme.benzinColor),
                      _TableCellText('${currencyFormat.format(data.totalBenzinAmount)} ج.س', isBold: true, color: AppTheme.benzinColor),
                    ],
                  ),
                  // فوهات الجازولين
                  ...data.dieselPumps.map((p) => _buildPumpTableRow(p, currencyFormat, numberFormat, AppTheme.dieselColor)),
                  // صف مجموع الجازولين
                  TableRow(
                    decoration: BoxDecoration(color: AppTheme.dieselColor.withValues(alpha: 0.08)),
                    children: [
                      const _TableCellText('مجموع الجازولين (4 فوهات)', isBold: true, color: AppTheme.dieselColor),
                      const _TableCellText('-'),
                      const _TableCellText('-'),
                      _TableCellText(numberFormat.format(data.totalDieselLiters), isBold: true, color: AppTheme.dieselColor),
                      _TableCellText('${currencyFormat.format(data.totalDieselAmount)} ج.س', isBold: true, color: AppTheme.dieselColor),
                    ],
                  ),
                  // صف المجموع الكلي لكل العدادات
                  TableRow(
                    decoration: BoxDecoration(color: Colors.blueGrey.shade100),
                    children: [
                      const _TableCellText('المجموع الكلي للعدادات', isBold: true, color: AppTheme.primaryNavy),
                      const _TableCellText('-'),
                      const _TableCellText('-'),
                      _TableCellText(numberFormat.format(data.totalMetersLiters), isBold: true, color: AppTheme.primaryNavy),
                      _TableCellText('${currencyFormat.format(data.totalMetersAmount)} ج.س', isBold: true, color: AppTheme.primaryNavy),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ==============================================================
              // القسم الرابع: التحويلات المالية
              // ==============================================================
              _buildSectionBanner(
                title: 'القسم الرابع: التحويلات المالية والمتحصلات',
                subtitle: 'توزيع التوريدات بين بنكك (صباح/مساء) والنقدي ومتبقي التواريد',
              ),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TableCellHeader('تحويل بنك صباح'),
                      _TableCellHeader('تحويل بنك مساء'),
                      _TableCellHeader('إيراد نقدي'),
                      _TableCellHeader('المجموع'),
                      _TableCellHeader('متبقي التواريد'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _TableCellText('${currencyFormat.format(data.bankMorning)} ج.س'),
                      _TableCellText('${currencyFormat.format(data.bankEvening)} ج.س'),
                      _TableCellText('${currencyFormat.format(data.cashAmount)} ج.س', isBold: true),
                      _TableCellText('${currencyFormat.format(data.totalFinancialRevenue)} ج.س', isBold: true, color: AppTheme.primaryNavy),
                      _TableCellText(
                        '${currencyFormat.format(data.remainingDeliveries)} ج.س',
                        isBold: true,
                        color: data.remainingDeliveries == 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                      ),
                    ],
                  ),
                ],
              ),
              if (data.creditAmount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '* ملاحظة: تم احتساب مبيعات آجل بمبلغ ${currencyFormat.format(data.creditAmount)} ج.س ضمن مبيعات الوردية.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 24),

              // ==============================================================
              // القسم الخامس: الخلاصة والتوقيع
              // ==============================================================
              _buildSectionBanner(
                title: 'القسم الخامس: الخلاصة والاعتماد النهائي',
                subtitle: 'جملة المباع والمنصرف من المصروفات وصافي الدخل وتوقيع الإدارة',
              ),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      _TableCellHeader('جملة المباع'),
                      _TableCellHeader('المنصرف'),
                      _TableCellHeader('الصافي'),
                      _TableCellHeader('توقيع مدير المحطة'),
                    ],
                  ),
                  TableRow(
                    children: [
                      _TableCellText('${currencyFormat.format(data.totalMetersAmount)} ج.س', isBold: true),
                      _TableCellText('${currencyFormat.format(data.totalExpenses)} ج.س', isBold: true, color: AppTheme.dangerRed),
                      _TableCellText(
                        '${currencyFormat.format(data.netAmount)} ج.س',
                        isBold: true,
                        color: AppTheme.primaryBlue,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المسؤول: ${data.closedByUser?.name ?? "المدير العام"}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'التوقيع: ............................',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('رجوع'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _printOrExportPdf,
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('طباعة / تصدير PDF الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBanner({required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryNavy,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(String label, double price, Color color, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('${format.format(price)} ج.س/لتر', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGallonDiffBadge(String label, double gallons, double liters, NumberFormat format) {
    final isSurplus = liters >= 0;
    final color = isSurplus ? AppTheme.successGreen : AppTheme.dangerRed;
    final sign = isSurplus ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $sign${format.format(gallons)} جالون ($sign${format.format(liters)} لتر)',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  TableRow _buildTankTableRow(
    TankReportData? tank,
    NumberFormat currencyFormat,
    NumberFormat numberFormat,
    String fallbackName,
    Color color,
  ) {
    if (tank == null) {
      return TableRow(
        children: [
          _TableCellText(fallbackName, isBold: true, color: color),
          const _TableCellText('0.0'),
          const _TableCellText('0.0'),
          const _TableCellText('0.0'),
          const _TableCellText('0.0 لتر'),
        ],
      );
    }

    final diffSign = tank.diffLiters >= 0 ? '+' : '';
    final diffColor = tank.diffLiters >= 0 ? AppTheme.successGreen : AppTheme.dangerRed;

    return TableRow(
      children: [
        _TableCellText('${tank.tank.fuelType} (${tank.tank.name})', isBold: true, color: color),
        _TableCellText(currencyFormat.format(tank.previousDip)),
        _TableCellText(currencyFormat.format(tank.delivered)),
        _TableCellText(currencyFormat.format(tank.currentDip)),
        _TableCellText(
          '$diffSign${numberFormat.format(tank.diffLiters)} لتر ($diffSign${numberFormat.format(tank.diffGallons)} جالون)',
          isBold: true,
          color: diffColor,
        ),
      ],
    );
  }

  TableRow _buildPumpTableRow(
    ShiftPumpRowData p,
    NumberFormat currencyFormat,
    NumberFormat numberFormat,
    Color color,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  '${p.pump.nozzleNumber}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const SizedBox(width: 6),
              Text(p.pump.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        _TableCellText(numberFormat.format(p.reading.previousMeter)),
        _TableCellText(numberFormat.format(p.reading.currentMeter)),
        _TableCellText(numberFormat.format(p.reading.litersSold), isBold: true),
        _TableCellText('${currencyFormat.format(p.reading.totalAmount)} ج.س'),
      ],
    );
  }
}

class _TableCellHeader extends StatelessWidget {
  final String text;

  const _TableCellHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.primaryNavy,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TableCellText extends StatelessWidget {
  final String text;
  final bool isBold;
  final Color? color;

  const _TableCellText(this.text, {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
