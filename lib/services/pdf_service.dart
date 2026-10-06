import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/student.dart';

class PdfService {
  Future<void> generateAndPrintReport(
    String title,
    List<Map<String, dynamic>> hodorRanking,
    List<Map<String, dynamic>> hifdRanking,
    List<Map<String, dynamic>> overallRanking,
    DateTime start,
    DateTime end,
  ) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Taqrir Report',
              style: pw.TextStyle(font: fontBold, fontSize: 18),
            ),
          ),
          pw.Paragraph(
            text:
                'Period: ${start.toIso8601String().split('T').first} to ${end.toIso8601String().split('T').first}',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
          pw.SizedBox(height: 10),
          pw.Header(level: 1, text: 'Best Hodor (Attendance)'),
          pw.TableHelper.fromTextArray(
            headers: ['Rank', 'Name', 'Present/Total', 'Score %'],
            data: List<List<String>>.generate(
              hodorRanking.length,
              (i) => [
                '${i + 1}',
                (hodorRanking[i]['student'] as Student).fullName,
                '${hodorRanking[i]['present']}/${hodorRanking[i]['total_days']}',
                '${(hodorRanking[i]['hodor_score'] as double).toStringAsFixed(1)}%',
              ],
            ),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            border: pw.TableBorder.all(),
          ),
          pw.SizedBox(height: 10),
          pw.Header(level: 1, text: 'Best Hifd (Memorization)'),
          pw.TableHelper.fromTextArray(
            headers: ['Rank', 'Name', 'Avg Grade', 'Score %'],
            data: List<List<String>>.generate(
              hifdRanking.length,
              (i) => [
                '${i + 1}',
                (hifdRanking[i]['student'] as Student).fullName,
                '${(hifdRanking[i]['avg_grade'] as double).toStringAsFixed(2)}/3',
                '${(hifdRanking[i]['hifd_score'] as double).toStringAsFixed(1)}%',
              ],
            ),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            border: pw.TableBorder.all(),
          ),
          pw.SizedBox(height: 10),
          pw.Header(level: 1, text: 'Best Overall (Taqrir)'),
          pw.TableHelper.fromTextArray(
            headers: ['Rank', 'Name', 'Overall Score %'],
            data: List<List<String>>.generate(
              overallRanking.length,
              (i) => [
                '${i + 1}',
                (overallRanking[i]['student'] as Student).fullName,
                '${(overallRanking[i]['overall_score'] as double).toStringAsFixed(1)}%',
              ],
            ),
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
            cellStyle: pw.TextStyle(font: font, fontSize: 9),
            border: pw.TableBorder.all(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'taqrir_report.pdf',
    );
  }
}
