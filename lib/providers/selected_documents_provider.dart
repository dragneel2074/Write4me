import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pdf_memory.dart';

final selectedDocumentsProvider = StateProvider<List<PDFMemory>>((ref) => []); 