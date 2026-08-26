class StockSubmitOutcome {
  const StockSubmitOutcome._({
    required this.success,
    required this.batchId,
    this.message,
    this.httpStatus,
  });

  factory StockSubmitOutcome.ok(String batchId) =>
      StockSubmitOutcome._(success: true, batchId: batchId);

  factory StockSubmitOutcome.failed(
    String batchId,
    String message,
    int? httpStatus,
  ) =>
      StockSubmitOutcome._(
        success: false,
        batchId: batchId,
        message: message,
        httpStatus: httpStatus,
      );

  final bool success;
  final String batchId;
  final String? message;
  final int? httpStatus;
}
