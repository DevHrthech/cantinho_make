import 'pdf_export_io.dart' if (dart.library.html) 'pdf_export_web.dart' as impl;

/// Na web faz download do PDF; em mobile/desktop usa [Printing.sharePdf].
Future<void> exportOrSharePdfBytes({
  required List<int> bytes,
  required String filename,
}) =>
    impl.exportOrSharePdfBytes(bytes: bytes, filename: filename);
