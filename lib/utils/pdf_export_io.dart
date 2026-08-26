import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> exportOrSharePdfBytes({
  required List<int> bytes,
  required String filename,
}) {
  return Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
}
