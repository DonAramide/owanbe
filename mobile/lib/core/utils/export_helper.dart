import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart'
    if (dart.library.io) 'export_helper_io.dart';

class ExportHelper {
  static Future<String?> downloadFile(
    String filename,
    String content, {
    String mimeType = 'text/csv',
  }) {
    return saveAndDownloadFile(filename, content, mimeType);
  }

  static Future<String?> downloadBytes(
    String filename,
    List<int> bytes, {
    String mimeType = 'text/csv',
  }) {
    return saveAndDownloadBytes(filename, bytes, mimeType);
  }
}
