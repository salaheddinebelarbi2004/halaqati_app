import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/student.dart';

class PdfService {
  static const _primary = PdfColor.fromInt(0xFF1F5F4A);
  static const _zebra = PdfColor.fromInt(0xFFF1F6F4);
  static const _gradeLabels = {3: 'ممتاز', 2: 'جيد', 1: 'ضعيف'};

  Future<void> generateAndPrintReport(
    String title,
    List<Map<String, dynamic>> hodorRanking,
    List<Map<String, dynamic>> hifdRanking,
    List<Map<String, dynamic>> overallRanking,
    DateTime start,
    DateTime end,
  ) async {
    final arabic = await PdfGoogleFonts.notoNaskhArabicRegular();
    final arabicBold = await PdfGoogleFonts.notoNaskhArabicBold();
    final latin = await PdfGoogleFonts.nunitoRegular();
    final latinBold = await PdfGoogleFonts.nunitoBold();

    // Theme applies the Arabic font to EVERYTHING (Header, Paragraph, tables).
    // This is what removes the broken symbols.
    final theme = pw.ThemeData.withFont(
      base: arabic,
      bold: arabicBold,
      fontFallback: [latin, latinBold],
    );

    pw.TextStyle s(double size, {bool bold = false, PdfColor? color}) =>
        pw.TextStyle(
          font: bold ? arabicBold : arabic,
          fontFallback: [bold ? latinBold : latin],
          fontSize: size,
          color: color,
        );

    String d(DateTime x) => x.toIso8601String().split('T').first;
    String pct(Object? v, [int digits = 1]) =>
        '${(v as double).toStringAsFixed(digits)}%';

    pw.Widget sectionTitle(String text) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          padding: const pw.EdgeInsets.only(bottom: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _primary, width: 1.2)),
          ),
          child: pw.Text(text, style: s(13, bold: true, color: _primary)),
        );

    pw.Widget table(
      List<String> headers,
      List<List<String>> rows, {
      Map<int, pw.TableColumnWidth>? widths,
    }) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: s(9, bold: true, color: PdfColors.white),
          cellStyle: s(9),
          headerDecoration: const pw.BoxDecoration(color: _primary),
          oddRowDecoration: const pw.BoxDecoration(color: _zebra),
          cellAlignment: pw.Alignment.center,
          headerAlignment: pw.Alignment.center,
          cellAlignments: {1: pw.Alignment.centerRight},
          columnWidths: widths,
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          tableDirection: pw.TextDirection.rtl,
          headerDirection: pw.TextDirection.rtl,
        );

    String name(Map<String, dynamic> e) => (e['student'] as Student).fullName;

    final nameWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(32),
      1: const pw.FlexColumnWidth(3),
    };

    final pdf = pw.Document(title: title);
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
            style: s(8, color: PdfColors.grey700),
          ),
        ),
        build: (ctx) => [
          // Header banner
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _primary,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: s(20, bold: true, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('الفترة: ${d(start)} إلى ${d(end)}',
                    style: s(10, color: PdfColors.white)),
                pw.Text('تاريخ الإصدار: ${d(DateTime.now())}',
                    style: s(9, color: PdfColors.white)),
              ],
            ),
          ),

          // Overall
          sectionTitle('الترتيب العام'),
          table(
            ['الترتيب', 'الاسم', 'الحضور', 'التحفيظ', 'النتيجة العامة'],
            [
              for (var i = 0; i < overallRanking.length; i++)
                [
                  '${i + 1}',
                  name(overallRanking[i]),
                  pct(overallRanking[i]['hodor_score'], 0),
                  pct(overallRanking[i]['hifd_score'], 0),
                  pct(overallRanking[i]['overall_score']),
                ],
            ],
            widths: nameWidths,
          ),

          // Attendance
          sectionTitle('تفاصيل الحضور'),
          table(
            ['الترتيب', 'الاسم', 'حاضر', 'متأخر', 'غائب', 'بعذر', 'الحصص', 'النسبة'],
            [
              for (var i = 0; i < hodorRanking.length; i++)
                [
                  '${i + 1}',
                  name(hodorRanking[i]),
                  '${hodorRanking[i]['present']}',
                  '${hodorRanking[i]['late']}',
                  '${hodorRanking[i]['absent']}',
                  '${hodorRanking[i]['excused']}',
                  '${hodorRanking[i]['expected_sessions']}',
                  pct(hodorRanking[i]['hodor_score']),
                ],
            ],
            widths: nameWidths,
          ),

          // Hifd
          sectionTitle('تفاصيل التحفيظ'),
          table(
            [
              'الترتيب', 'الاسم', 'السجلات', 'الحصص', 'الآيات',
              'المتوسط', 'ممتاز', 'جيد', 'ضعيف', 'الجودة', 'الكمية', 'النتيجة',
            ],
            [
              for (var i = 0; i < hifdRanking.length; i++)
                () {
                  final e = hifdRanking[i];
                  final g = (e['grade_counts'] as Map).cast<int, int>();
                  return [
                    '${i + 1}',
                    name(e),
                    '${e['hifdh_records']}',
                    '${e['hifdh_sessions']}',
                    '${e['hifdh_ayahs']}',
                    '${(e['avg_grade'] as double).toStringAsFixed(2)}',
                    '${g[3] ?? 0}',
                    '${g[2] ?? 0}',
                    '${g[1] ?? 0}',
                    pct(e['hifd_quality'], 0),
                    pct(e['hifd_volume'], 0),
                    pct(e['hifd_score']),
                  ];
                }(),
            ],
            widths: nameWidths,
          ),

          pw.SizedBox(height: 10),
          pw.Text(
            'ملاحظة: نتيجة التحفيظ = ٧٠٪ جودة (متوسط التقييم من ٣) + ٣٠٪ كمية (عدد السجلات مقارنة بالأكثر حفظاً). '
            'لا تُحتسب الأيام غير المسجّلة غياباً، والحصص المعذورة لا تدخل في نسبة الحضور.',
            style: s(8, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'taqrir_report_${d(start)}_${d(end)}.pdf',
    );
  }
}