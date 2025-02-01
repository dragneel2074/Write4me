import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pdf_memory.dart';

class DocumentListContainer extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final doc = documents[index];
          return FilterChip(
            label: Text(
              doc.fileName,
              style: TextStyle(
                color: doc.isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
            selected: doc.isSelected,
            onSelected: (selected) {
              doc.isSelected = selected;
              onSelectionChanged();
            },
            onDeleted: () => onRemove(doc),
            onLongPress: () => onLongPress(doc),
            backgroundColor: Theme.of(context).cardColor,
            selectedColor: Theme.of(context).colorScheme.primary,
          );
        },
      ),
    );
  }
}
