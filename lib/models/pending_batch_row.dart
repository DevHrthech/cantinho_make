class PendingBatchRow {
  const PendingBatchRow({
    required this.batchId,
    required this.dia,
    required this.usuario,
    required this.deposito,
    required this.itemCount,
    required this.lastError,
    required this.httpStatus,
  });

  /// Valor da coluna `lote_id` no SQLite (agrupa linhas da mesma operação).
  /// O campo `id` é a chave primária auto incrementada por linha.
  final String batchId;  final String dia;
  final String usuario;
  final String deposito;
  final int itemCount;
  final String? lastError;
  final int? httpStatus;
}
