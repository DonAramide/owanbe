import 'dart:convert';
import 'dart:html' as html;

Future<String?> saveAndDownloadFile(String filename, String content, String mimeType) async {
  return saveAndDownloadBytes(filename, utf8.encode(content), mimeType);
}

Future<String?> saveAndDownloadBytes(String filename, List<int> bytes, String mimeType) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
