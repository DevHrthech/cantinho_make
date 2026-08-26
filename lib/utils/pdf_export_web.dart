// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> exportOrSharePdfBytes({
  required List<int> bytes,
  required String filename,
}) async {
  final u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = html.Blob([u8], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
