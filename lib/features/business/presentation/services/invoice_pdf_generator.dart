import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/entities/invoice_entity.dart';

class InvoicePdfGenerator {
  /// Bundled Vazirmatn TTFs (also declared under flutter.assets) — loading
  /// them locally instead of PdfGoogleFonts keeps Persian text rendering
  /// offline-safe. The remote variant fails without internet and every
  /// Persian glyph collapses into □ boxes.
  static Future<pw.Font> _loadFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }

  static Future<Uint8List> generateInvoicePdf({
    required InvoiceEntity invoice,
    ContactEntity? contact,
    String sellerName = 'Kifino',
    String? sellerPhone,
    String? sellerAddress,
    bool isPersian = true,
  }) async {
    final pdf = pw.Document();

    final font = await _loadFont('assets/fonts/Vazirmatn-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/Vazirmatn-Bold.ttf');

    final primaryColor = PdfColor.fromHex('#10B981'); // Emerald
    final darkText = PdfColor.fromHex('#1F2937');
    final grayText = PdfColor.fromHex('#6B7280');
    final lightBg = PdfColor.fromHex('#F3F4F6');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: isPersian ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isPersian ? invoice.type.titleFa : 'INVOICE',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 24,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${isPersian ? 'شماره فاکتور:' : 'Invoice No:'} ${invoice.invoiceNumber}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          sellerName,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 14,
                            color: darkText,
                          ),
                        ),
                        if (sellerPhone != null)
                          pw.Text(
                            sellerPhone,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: grayText,
                            ),
                          ),
                        if (sellerAddress != null)
                          pw.Text(
                            sellerAddress,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: grayText,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: primaryColor, thickness: 1.5),
                pw.SizedBox(height: 12),

                // Parties & Dates info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Buyer info
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isPersian
                              ? 'مشخصات خریدار / طرف حساب:'
                              : 'Billed To:',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: grayText,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          contact?.name ??
                              invoice.contactName ??
                              (isPersian ? 'مشتری آزاد' : 'Guest'),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 13,
                            color: darkText,
                          ),
                        ),
                        if (contact?.companyName != null)
                          pw.Text(
                            contact!.companyName!,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: darkText,
                            ),
                          ),
                        if (contact?.phone != null)
                          pw.Text(
                            '${isPersian ? 'تلفن:' : 'Phone:'} ${contact!.phone}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: grayText,
                            ),
                          ),
                        if (contact?.address != null)
                          pw.Text(
                            contact!.address!,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: grayText,
                            ),
                          ),
                      ],
                    ),

                    // Dates & status
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          '${isPersian ? 'تاریخ صدور:' : 'Issue Date:'} ${AppDateFormatter.formatShort(invoice.issueDate, locale: isPersian ? 'fa' : 'en')}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${isPersian ? 'موعد پرداخت:' : 'Due Date:'} ${AppDateFormatter.formatShort(invoice.dueDate, locale: isPersian ? 'fa' : 'en')}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: pw.BoxDecoration(
                            color: lightBg,
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(4),
                            ),
                          ),
                          child: pw.Text(
                            isPersian
                                ? invoice.status.titleFa
                                : invoice.status.code.toUpperCase(),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 24),

                // Items Table
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#E5E7EB'),
                    width: 0.5,
                  ),
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightBg),
                      children: [
                        _buildTableHeaderCell(
                          isPersian ? 'شرح کالا / خدمات' : 'Description',
                          fontBold,
                        ),
                        _buildTableHeaderCell(
                          isPersian ? 'تعداد' : 'Qty',
                          fontBold,
                          align: pw.TextAlign.center,
                        ),
                        _buildTableHeaderCell(
                          isPersian ? 'قیمت واحد' : 'Unit Price',
                          fontBold,
                          align: pw.TextAlign.right,
                        ),
                        _buildTableHeaderCell(
                          isPersian ? 'تخفیف' : 'Discount',
                          fontBold,
                          align: pw.TextAlign.right,
                        ),
                        _buildTableHeaderCell(
                          isPersian ? 'مبلغ کل' : 'Total',
                          fontBold,
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                    // Item Rows
                    ...invoice.items.map((item) {
                      return pw.TableRow(
                        children: [
                          _buildTableCell(item.description, font),
                          _buildTableCell(
                            item.quantity.toStringAsFixed(
                              item.quantity % 1 == 0 ? 0 : 2,
                            ),
                            font,
                            align: pw.TextAlign.center,
                          ),
                          _buildTableCell(
                            item.unitPrice.formatted,
                            font,
                            align: pw.TextAlign.right,
                          ),
                          _buildTableCell(
                            item.discount.formatted,
                            font,
                            align: pw.TextAlign.right,
                          ),
                          _buildTableCell(
                            item.total.formatted,
                            fontBold,
                            align: pw.TextAlign.right,
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 16),

                // Totals Summary Box
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 240,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: lightBg,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          _buildSummaryRow(
                            isPersian ? 'جمع اقلام:' : 'Subtotal:',
                            invoice.subtotal.formatted,
                            font,
                          ),
                          if (invoice.discount.minorUnits > 0)
                            _buildSummaryRow(
                              isPersian ? 'مجموع تخفیف:' : 'Discount:',
                              '-${invoice.discount.formatted}',
                              font,
                            ),
                          if (invoice.tax.minorUnits > 0)
                            _buildSummaryRow(
                              isPersian
                                  ? 'مالیات بر ارزش افزوده:'
                                  : 'VAT / Tax:',
                              invoice.tax.formatted,
                              font,
                            ),
                          pw.Divider(color: PdfColor.fromHex('#D1D5DB')),
                          _buildSummaryRow(
                            isPersian ? 'مبلغ نهایی فاکتور:' : 'Grand Total:',
                            invoice.total.formatted,
                            fontBold,
                            isTotal: true,
                            color: primaryColor,
                          ),
                          if (invoice.paidAmount.minorUnits > 0)
                            _buildSummaryRow(
                              isPersian ? 'مبلغ پرداخت شده:' : 'Paid:',
                              invoice.paidAmount.formatted,
                              font,
                            ),
                          if (invoice.remainingBalance.minorUnits > 0)
                            _buildSummaryRow(
                              isPersian
                                  ? 'باقیمانده قابل پرداخت:'
                                  : 'Balance Due:',
                              invoice.remainingBalance.formatted,
                              fontBold,
                              color: PdfColors.red700,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),

                // Notes & Terms footer
                if (invoice.notes != null || invoice.terms != null) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.TableBorder.all(
                        color: PdfColor.fromHex('#E5E7EB'),
                        width: 0.5,
                      ),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (invoice.notes != null) ...[
                          pw.Text(
                            '${isPersian ? 'توضیحات:' : 'Notes:'} ${invoice.notes}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: grayText,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                        ],
                        if (invoice.terms != null)
                          pw.Text(
                            '${isPersian ? 'شرایط و ضوابط:' : 'Terms:'} ${invoice.terms}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: grayText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],

                pw.Center(
                  child: pw.Text(
                    isPersian
                        ? 'صادر شده توسط سیستم عامل مالی کیفینو | Kifino Financial OS'
                        : 'Generated by Kifino Financial OS',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: grayText,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeaderCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.start,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          color: PdfColor.fromHex('#374151'),
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.start,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value,
    pw.Font font, {
    bool isTotal = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: isTotal ? 11 : 9),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: isTotal ? 12 : 9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printOrShareInvoice({
    required InvoiceEntity invoice,
    ContactEntity? contact,
    bool isPersian = true,
  }) async {
    final pdfBytes = await generateInvoicePdf(
      invoice: invoice,
      contact: contact,
      isPersian: isPersian,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${invoice.invoiceNumber}.pdf',
    );
  }
}
