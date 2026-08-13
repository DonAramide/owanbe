import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveAndDownloadFile(String filename, String content, String mimeType) async {
  return saveAndDownloadBytes(filename, utf8.encode(content), mimeType);
}

Future<String?> saveAndDownloadBytes(String filename, List<int> bytes, String mimeType) async {
  final directory = await getApplicationDocumentsDirectory();
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final file = File('${directory.path}/$safeName');
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return file.path;
}
