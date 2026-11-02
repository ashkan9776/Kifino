import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../domain/entities/accounting_document_entity.dart';

class AccountingVoucherPdfGenerator {
  static Future<pw.Font> _loadFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }

  static Future<Uint8List> generateVoucherPdf({
    required AccountingDocumentEntity document,
    String organizationName = 'سیستم مالی و حسابداری کیفینو (Kifino)',
    bool isPersian = true,
  }) async {
    final pdf = pw.Document();

    final font = await _loadFont('assets/fonts/Vazirmatn-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/Vazirmatn-Bold.ttf');

    final primaryColor = PdfColor.fromHex('#3F51B5'); // Indigo
    final darkText = PdfColor.fromHex('#1F2937');
    final grayText = PdfColor.fromHex('#6B7280');
    final lightBg = PdfColor.fromHex('#F8FAFC');
    final borderGray = PdfColor.fromHex('#E2E8F0');

    final jalali = JalaliDate.fromDateTime(document.date);
    final jalaliDateStr =
        '${TextNormalizer.toPersianDigits(jalali.year.toString())}/${TextNormalizer.toPersianDigits(jalali.month.toString().padLeft(2, '0'))}/${TextNormalizer.toPersianDigits(jalali.day.toString().padLeft(2, '0'))}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: isPersian ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Top Header Box
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  color: lightBg,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          organizationName,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'برگه سند حسابداری دوبل (Accounting Voucher)',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'شماره سند: #${TextNormalizer.toPersianDigits(document.number.toString())}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'تاریخ سند: $jalaliDateStr',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: grayText,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'وضعیت: ${document.status.titleFa} (${document.isManual ? 'ثبت دستی' : 'ثبت خودکار سیستمی'})',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: grayText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // 2. Voucher Description / Subject
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                  border: pw.Border.all(color: borderGray, width: 0.8),
                ),
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(
                        text: 'شرح کلی سند: ',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: primaryColor,
                        ),
                      ),
                      pw.TextSpan(
                        text: document.title,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 12),

              // 3. Transactions Table (آرتیکل‌های سند)
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28), // ردیف
                  1: const pw.FixedColumnWidth(60), // کد حساب
                  2: const pw.FlexColumnWidth(2.5), // عنوان سرفصل
                  3: const pw.FlexColumnWidth(3.5), // شرح آرتیکل
                  4: const pw.FlexColumnWidth(2.0), // بدهکار
                  5: const pw.FlexColumnWidth(2.0), // بستانکار
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _buildHeaderCell('#', fontBold),
                      _buildHeaderCell('کد حساب', fontBold),
                      _buildHeaderCell('نام حساب (معین / تفصیلی)', fontBold),
                      _buildHeaderCell('شرح آرتیکل', fontBold),
                      _buildHeaderCell('بدهکار (تومان)', fontBold),
                      _buildHeaderCell('بستانکار (تومان)', fontBold),
                    ],
                  ),
                  // Rows
                  ...document.transactions.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final tx = entry.value;
                    final isDeb = tx.debit.minorUnits > 0;
                    final rowBg = entry.key % 2 == 0
                        ? PdfColors.white
                        : lightBg;

                    final subjectCode = tx.subject != null
                        ? tx.subject!.formattedCode
                        : '-';
                    final subjectName = tx.subject != null
                        ? tx.subject!.name
                        : tx.subjectId;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowBg),
                      children: [
                        _buildCell(
                          TextNormalizer.toPersianDigits(index.toString()),
                          font,
                          align: pw.TextAlign.center,
                        ),
                        _buildCell(
                          subjectCode,
                          font,
                          align: pw.TextAlign.center,
                        ),
                        _buildCell(
                          subjectName,
                          font,
                          align: pw.TextAlign.right,
                        ),
                        _buildCell(
                          tx.description.isNotEmpty ? tx.description : '-',
                          font,
                          align: pw.TextAlign.right,
                        ),
                        _buildCell(
                          isDeb
                              ? tx.debit.format(
                                  includeSymbol: false,
                                  usePersianDigits: true,
                                )
                              : '-',
                          font,
                          align: pw.TextAlign.left,
                        ),
                        _buildCell(
                          !isDeb
                              ? tx.credit.format(
                                  includeSymbol: false,
                                  usePersianDigits: true,
                                )
                              : '-',
                          font,
                          align: pw.TextAlign.left,
                        ),
                      ],
                    );
                  }),
                  // Totals Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightBg),
                    children: [
                      _buildCell('', fontBold),
                      _buildCell('', fontBold),
                      _buildCell(
                        'جمع کل سند:',
                        fontBold,
                        align: pw.TextAlign.right,
                      ),
                      _buildCell(
                        document.isBalanced
                            ? 'سند کاملاً تراز است'
                            : 'اختلاف تراز!',
                        fontBold,
                        align: pw.TextAlign.center,
                      ),
                      _buildCell(
                        document.totalDebit.format(
                          includeSymbol: false,
                          usePersianDigits: true,
                        ),
                        fontBold,
                        align: pw.TextAlign.left,
                      ),
                      _buildCell(
                        document.totalCredit.format(
                          includeSymbol: false,
                          usePersianDigits: true,
                        ),
                        fontBold,
                        align: pw.TextAlign.left,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Spacer(),

              // 4. Signatures Box (امضاهای قانونی مطابق با هلو و سپیدار)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderGray, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSignatureBox('تنظیم‌کننده سند', fontBold, font),
                    _buildSignatureBox('حسابدار', fontBold, font),
                    _buildSignatureBox('رئیس حسابداری', fontBold, font),
                    _buildSignatureBox('مدیر مالی / عامل', fontBold, font),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'تولید شده توسط سیستم عامل مالی کیفینو (Kifino Financial OS)',
                  style: pw.TextStyle(font: font, fontSize: 8, color: grayText),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.right,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          color: PdfColor.fromHex('#1F2937'),
        ),
      ),
    );
  }

  static pw.Widget _buildSignatureBox(
    String title,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 9,
            color: PdfColor.fromHex('#374151'),
          ),
        ),
        pw.SizedBox(height: 28),
        pw.Text(
          'امضاء / تاریخ',
          style: pw.TextStyle(
            font: font,
            fontSize: 7,
            color: PdfColor.fromHex('#9CA3AF'),
          ),
        ),
      ],
    );
  }

  static Future<void> printOrShareVoucher({
    required AccountingDocumentEntity document,
    String organizationName = 'سیستم مالی و حسابداری کیفینو',
  }) async {
    final pdfBytes = await generateVoucherPdf(
      document: document,
      organizationName: organizationName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Voucher_${document.number}.pdf',
    );
  }
}
