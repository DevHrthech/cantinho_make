import '../../models/pending_batch_row.dart';
import '../../models/scanned_line.dart';
import '../../models/session_user.dart';
import '../../models/stock_submit_outcome.dart';

class StockSubmitService {
  const StockSubmitService();

  Future<StockSubmitOutcome> concludeSaida({
    required SessionUser user,
    required List<ScannedLine> lines,
    String? tipoPagamento,
    double? valorRecebido,
    String? desconto,
  }) async =>
      StockSubmitOutcome.failed('', 'Disponível apenas no aplicativo mobile.', null);

  Future<StockSubmitOutcome> concludeEntrada({
    required SessionUser user,
    required List<ScannedLine> lines,
  }) async =>
      StockSubmitOutcome.failed('', 'Disponível apenas no aplicativo mobile.', null);

  Future<List<PendingBatchRow>> listPendingVendas() async => const [];

  Future<List<PendingBatchRow>> listPendingInventarios() async => const [];

  Future<StockSubmitOutcome> retryBatch({
    required bool isVenda,
    required String batchId,
  }) async =>
      StockSubmitOutcome.failed(batchId, 'Disponível apenas no aplicativo mobile.', null);
}
