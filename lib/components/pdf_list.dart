import 'package:flutter/material.dart';
import 'package:write4me/models/pdf_memory.dart';

class PDFList extends StatelessWidget {
  final List<PDFMemory> pdfMemories;
  final VoidCallback onSelectionChanged;
  final Function(PDFMemory) onLongPress;
  final Function(PDFMemory) onRemove;

  const PDFList({
    super.key,
    required this.pdfMemories,
    required this.onSelectionChanged,
    required this.onLongPress,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: pdfMemories.length,
      itemBuilder: (context, index) {
        final memory = pdfMemories[index];
        final wordCount = memory.extractedText.split(RegExp(r'\s+')).length;
        final isLongText = wordCount > 700;

        return ListTile(
          title: Text(memory.pdfName, style: const TextStyle(fontSize: 10),),
          subtitle: isLongText
              ? Text(
                  'Warning: Only first 700 words will be used',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 8,
                  ),
                )
              : null,
          leading: Checkbox(
            value: memory.isSelected,
            onChanged: (bool? value) {
              memory.isSelected = value ?? false;
              onSelectionChanged();
            },
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => onRemove(memory),
            tooltip: 'Remove document',
          ),
          onLongPress: () => onLongPress(memory),
        );
      },
    );
  }
}
