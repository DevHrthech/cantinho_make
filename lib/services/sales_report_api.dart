import 'package:intl/intl.dart';

import '../models/sale_report_row.dart';
import 'query_api.dart';

abstract final class SalesReportApi {
  static final _dfSql = DateFormat('yyyy-MM-dd');

  static Future<List<SaleReportRow>> list({
    required DateTime dataInicial,
    required DateTime dataFinal,
    required String depositoNome,
  }) async {
    final di = QueryApi.sqlEscape(_dfSql.format(dataInicial));
    final df = QueryApi.sqlEscape(_dfSql.format(dataFinal));
    final dep = QueryApi.sqlEscape(depositoNome);

    final orderBy = SaleReportRow.showsVendaGroupingForDeposito(depositoNome)
        ? 'ORDER BY (vp.id_venda IS NULL) ASC, vp.id_venda ASC, vp.id ASC'
        : 'ORDER BY vp.dia ASC, vp.id ASC';

    final sql =
        "Select vp.dia, vp.codigo_barra, vp.produto, vp.quantidade, "
        "vp.valor_unitario, vp.valor_total, vp.desconto, vp.valor_total_venda, "
        "vp.deposito, vp.usuario, "
        "vp.id_venda, vp.tipo_pagamento "
        "from VendaProdutos vp "
        "WHERE vp.dia BETWEEN '$di' AND '$df' AND vp.deposito ='$dep' "
        '$orderBy';

    final payload = await QueryApi.postSql(sql);
    final rows = QueryApi.coerceRows(payload);
    return rows.map(SaleReportRow.fromRow).toList();
  }
}
