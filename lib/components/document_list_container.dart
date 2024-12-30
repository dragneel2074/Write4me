import 'package:flutter/material.dart';
import '../models/pdf_memory.dart';
import 'pdf_list.dart';

class DocumentListContainer extends StatelessWidget {
  final List<PDFMemory> documents;
  final VoidCallback onSelectionChanged;
  final Function(PDFMemory) onLongPress;
  final Function(PDFMemory) onRemove;

  const DocumentListContainer({
    super.key,
    required this.documents,
    required this.onSelectionChanged,
    required this.onLongPress,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: PDFList(
        pdfMemories: documents,
        onSelectionChanged: onSelectionChanged,
        onLongPress: onLongPress,
        onRemove: onRemove,
      ),
    );
  }
}
