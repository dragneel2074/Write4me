import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../file_processing/file_processor.dart';

/// Provider that maintains a single instance of FileProcessor throughout the app.
/// This ensures that all document processing uses the same vector store.
final fileProcessorProvider = Provider<FileProcessor>((ref) {
  return FileProcessor();
}); 