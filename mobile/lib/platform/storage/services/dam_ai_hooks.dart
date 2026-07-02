import 'dart:typed_data';
import '../models/digital_asset.dart';

abstract class DocumentOcrHook {
  Future<String> performOcr(Uint8List bytes);
}

abstract class ImageModerationHook {
  Future<bool> isSafe(Uint8List bytes);
}

abstract class FaceMatchingHook {
  Future<double> computeMatchConfidence(Uint8List face1, Uint8List face2);
}

abstract class DocumentClassifierHook {
  Future<String> classifyDocument(Uint8List bytes);
}

abstract class SemanticSearchHook {
  Future<List<double>> generateEmbeddings(String text);
}

class DamAiHooks {
  DocumentOcrHook? ocrHook;
  ImageModerationHook? moderationHook;
  FaceMatchingHook? faceHook;
  DocumentClassifierHook? classifierHook;
  SemanticSearchHook? searchHook;
}
