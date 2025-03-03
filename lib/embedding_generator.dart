import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:fonnx/models/minilml6v2/mini_lm_l6_v2.dart';
import 'package:flutter/foundation.dart';

/// A utility class to generate text embeddings using the MiniLmL6V2 model and fonnx package.
class EmbeddingGenerator {
  /// Generates an embedding for the given [text].
  ///
  /// Returns a [Future] that resolves to a list of doubles representing the embedding.
  static Future<List<double>> generateEmbedding(String text) async {
    if (kDebugMode) {
      print("EmbeddingGenerator: Generating embedding for text: $text");
    }
    
    // Get the model file path, ensuring it's copied locally from assets if necessary.
    final modelPath = await getModelPath();
    if (kDebugMode) {
      print("EmbeddingGenerator: Model loaded from: $modelPath");
    }
    
    // Load the MiniLmL6V2 model.
    final model = MiniLmL6V2.load(modelPath);
    
    // Tokenize the input text.
    final tokens = MiniLmL6V2.tokenizer.tokenize(text).first.tokens;
    if (kDebugMode) {
      print("EmbeddingGenerator: Tokenized text into ${tokens.length} tokens");
    }
    
    // Obtain the embedding as a vector.
    final embeddingVector = await model.getEmbeddingAsVector(tokens);
    final embedding = embeddingVector.toList();
    if (kDebugMode) {
      print("EmbeddingGenerator: Embedding generated with length: ${embedding.length}");
    }
    
    return embedding;
  }

  /// Public method to get the model path
  static Future<String> getModelPath() async {
    // Get the directory for caching assets.
    final assetCacheDirectory =
        await path_provider.getApplicationSupportDirectory();
    final modelPath = path.join(assetCacheDirectory.path, 'models', 'miniLmL6V2.onnx');

    File file = File(modelPath);
    final bool fileExists = await file.exists();
    final int fileLength = fileExists ? await file.length() : 0;

    // The asset path should match your folder structure.
    const assetPath = 'assets/models/miniLmL6V2.onnx';
    final assetByteData = await rootBundle.load(assetPath);
    final int assetLength = assetByteData.lengthInBytes;
    final bool fileSameSize = fileExists && fileLength == assetLength;

    // If the file doesn't exist or is outdated, write it to the cache directory.
    if (!fileExists || !fileSameSize) {
      await file.parent.create(recursive: true);
      
      List<int> bytes = assetByteData.buffer.asUint8List(
        assetByteData.offsetInBytes,
        assetByteData.lengthInBytes,
      );
      await file.writeAsBytes(bytes, flush: true);
      if (kDebugMode) {
        debugPrint("EmbeddingGenerator: Model copied to: $modelPath");
      }
    }
    return modelPath;
  }
} 