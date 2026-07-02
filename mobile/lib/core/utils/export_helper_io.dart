import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveAndDownloadFile(String filename, String content, String mimeType) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
  } catch (e) {
    // print or ignore in release
  }
}
