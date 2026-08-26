import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/sale_report_row.dart';
import '../utils/format_money.dart';

abstract final class SalesReportPdf {
  static const String logoAssetPath = 'assets/branding/espelho_logo.png';
  static final _periodFmt = DateFormat('dd-MM-yyyy');

  static Future<Uint8List> buildBytes({
    required DateTime dataInicial,
    required DateTime dataFinal,
    required String depositoNome,
    required List<SaleReportRow> rows,
    bool showVendaGroupingColumns = false,
  }) async {
    final logoRaw = await rootBundle.load(logoAssetPath);
    final logoImg = pw.MemoryImage(logoRaw.buffer.asUint8List());

    final periodo =
        '${_periodFmt.format(dataInicial)} a ${_periodFmt.format(dataFinal)}';

    final pdf = pw.Document();

    pw.Widget logoBox() =>
        pw.Center(child: pw.Image(logoImg, width: 88, height: 88));

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          margin: pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
        ),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            logoBox(),
            pw.SizedBox(height: 12),
            pw.Text(
              'Espelho Espelho Meu',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Período: $periodo',
                style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Depósito: $depositoNome',
                style: const pw.TextStyle(fontSize: 11)),
            pw.Divider(thickness: 0.8, color: PdfColors.grey700),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) {
          final data = rows
              .map(
                (r) {
                  final base = <String>[
                    r.diaDisplay,
                    r.codigoBarra,
                    r.produto,
                    _qtdFmt(r.quantidade),
                    r.valorUnitario != null ? formatBrl(r.valorUnitario!) : '—',
                    r.valorTotalLinha != null ? formatBrl(r.valorTotalLinha!) : '—',
                    r.desconto ?? '—',
                    r.valorTotalVenda != null ? formatBrl(r.valorTotalVenda!) : '—',
                    r.deposito,
                    r.usuario,
                  ];
                  if (showVendaGroupingColumns) {
                    base.addAll([
                      r.idVenda?.toString() ?? '—',
                      r.tipoPagamento ?? '—',
                    ]);
                  }
                  return base;
                },
              )
              .toList();

          final headers = <String>[
            'Dia',
            'Código de barras',
            'Produto',
            'Qtd',
            'Valor unitário',
            'Valor total',
            'Desconto',
            'Valor total venda',
            'Depósito',
            'Usuário',
            if (showVendaGroupingColumns) ...[
              'ID venda',
              'Forma pagamento',
            ],
          ];

          // Totais exibidos no rodapé do PDF.
          final sumVendas = rows.fold<double>(
            0,
            (s, r) => s + (r.valorTotalLinha ?? 0),
          );
          final descontoPorVendaPdf = <int, double>{};
          double descontoSemIdPdf = 0;
          final valorTotalVendaPorVendaPdf = <int, double>{};
          double valorTotalVendaSemIdPdf = 0;
          for (final r in rows) {
            final d = r.desconto;
            if (d != null && d.isNotEmpty) {
              final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(d);
              if (m != null) {
                final v = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
                final id = r.idVenda;
                if (id == null) {
                  descontoSemIdPdf += v;
                } else if (!descontoPorVendaPdf.containsKey(id)) {
                  descontoPorVendaPdf[id] = v;
                }
              }
            }
            // Processa valor total da venda
            final vtv = r.valorTotalVenda;
            if (vtv != null) {
              final id = r.idVenda;
              if (id == null) {
                valorTotalVendaSemIdPdf += vtv;
              } else if (!valorTotalVendaPorVendaPdf.containsKey(id)) {
                valorTotalVendaPorVendaPdf[id] = vtv;
              }
            }
          }
          final sumDesconto = descontoPorVendaPdf.values.fold<double>(
                0,
                (s, v) => s + v,
              ) +
              descontoSemIdPdf;
          final sumValorTotalVenda = valorTotalVendaPorVendaPdf.values.fold<double>(
                0,
                (s, v) => s + v,
              ) +
              valorTotalVendaSemIdPdf;

          final totals = <pw.Widget>[
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 14),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _totalCol('Soma valor total', formatBrl(sumVendas)),
                  _totalCol('Soma descontos', formatBrl(sumDesconto)),
                  _totalCol('Soma valor total venda', formatBrl(sumValorTotalVenda)),
                ],
              ),
            ),
          ];

          return [
            if (rows.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12),
                child: pw.Text(
                  'Nenhuma linha registrada neste período.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              )
            else ...[
              pw.TableHelper.fromTextArray(
                context: context,
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
                headers: headers,
                data: data,
              ),
              ...totals,
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static String _qtdFmt(double q) {
    if (q == q.roundToDouble()) return '${q.toInt()}';
    return q.toStringAsFixed(2).replaceAll('.', ',');
  }

  static pw.Widget _totalCol(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey900,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
