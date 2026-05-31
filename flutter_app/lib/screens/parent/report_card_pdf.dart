import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:canteen_common/canteen_common.dart';

/// Generate and share a PDF report card.
Future<void> generateAndShareReportCardPdf({
  required StudentModel student,
  required ReportCardModel reportCard,
  required String schoolName,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header: School name + title
            pw.Center(
              child: pw.Text(
                schoolName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text(
                'REPORT CARD',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 16),

            // Student info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Name', student.displayName),
                    _infoRow('Grade / Class', student.gradeAndClass),
                    _infoRow('Student Code', student.studentCode),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _infoRow('Academic Year', reportCard.academicYear),
                    _infoRow('Term', reportCard.term),
                    if (reportCard.generatedAt != null)
                      _infoRow('Date', _formatDate(reportCard.generatedAt!)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Subject table
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 28,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              headers: ['Subject', 'Score', 'Full Marks', 'Grade', 'Result'],
              data: reportCard.subjects.map((s) {
                return [
                  s.subjectName,
                  s.score?.toStringAsFixed(0) ?? '-',
                  s.fullMarks.toString(),
                  s.letterGrade ?? '-',
                  s.isPassed ? 'Pass' : 'Fail',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  if (reportCard.totalScore != null && reportCard.totalFullMarks != null)
                    _summaryItem('Total Score', '${reportCard.totalScore!.toStringAsFixed(0)} / ${reportCard.totalFullMarks}'),
                  if (reportCard.percentage != null)
                    _summaryItem('Percentage', '${reportCard.percentage!.toStringAsFixed(1)}%'),
                  if (reportCard.rankInClass != null)
                    _summaryItem('Rank', '${reportCard.rankInClass}'),
                  if (reportCard.overallGrade != null)
                    _summaryItem('Grade', reportCard.overallGrade!),
                  if (reportCard.result != null)
                    _summaryItem('Result', reportCard.result!),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Grading scale legend
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('Grading Scale:  ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('A = 80-100   B = 65-79   C = 40-64   F = 0-39',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Teacher comment
            if (reportCard.teacherComment != null && reportCard.teacherComment!.isNotEmpty) ...[
              pw.Text("Teacher's Comment:", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(reportCard.teacherComment!, style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.SizedBox(height: 12),
            ],

            // Principal comment
            if (reportCard.principalComment != null && reportCard.principalComment!.isNotEmpty) ...[
              pw.Text("Principal's Comment:", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(reportCard.principalComment!, style: const pw.TextStyle(fontSize: 10)),
              ),
            ],

            pw.Spacer(),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  schoolName,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  final bytes = await pdf.save();
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'report_card_${student.studentCode}_${reportCard.term}.pdf',
  );
}

pw.Widget _infoRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      children: [
        pw.Text('$label: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}

pw.Widget _summaryItem(String label, String value) {
  return pw.Column(
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ],
  );
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
