import 'package:intl/intl.dart';

import '../models/sale_report_row.dart';
import 'api_client.dart';

abstract final class SalesReportApi {
  static final _dfSql = DateFormat('yyyy-MM-dd');

  /// Para usuário não administrador o servidor usa sempre o depósito dele.
  static Future<List<SaleReportRow>> list({
    required DateTime dataInicial,
    required DateTime dataFinal,
    required String depositoNome,
  }) async {
    final payload = await ApiClient.get('/relatorios/vendas', query: {
      'inicio': _dfSql.format(dataInicial),
      'fim': _dfSql.format(dataFinal),
      'deposito': depositoNome,
    });
    return ApiClient.rows(payload).map(SaleReportRow.fromRow).toList();
  }
}
