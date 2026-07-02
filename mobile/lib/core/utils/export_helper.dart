import 'export_helper_stub.dart'
    if (dart.library.html) 'export_helper_web.dart'
    if (dart.library.io) 'export_helper_io.dart';

class ExportHelper {
  static Future<void> downloadFile(String filename, String content, {String mimeType = 'text/csv'}) async {
    await saveAndDownloadFile(filename, content, mimeType);
  }
}
