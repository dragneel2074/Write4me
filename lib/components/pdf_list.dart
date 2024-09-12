import 'package:flutter/material.dart';
import 'package:write4me/models/pdf_memory.dart';

class PDFList extends StatelessWidget {
  final List<PDFMemory> pdfMemories;
  final VoidCallback onSelectionChanged;
  final Function(PDFMemory) onLongPress;

  const PDFList({
    Key? key,
    required this.pdfMemories,
    required this.onSelectionChanged,
    required this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: pdfMemories.length,
      itemBuilder: (context, index) {
        final memory = pdfMemories[index];
        return ListTile(
          title: Text(memory.pdfName),
          leading: Checkbox(
            value: memory.isSelected,
            onChanged: (bool? value) {
              memory.isSelected = value ?? false;
              onSelectionChanged();
            },
          ),
          onLongPress: () => onLongPress(memory),
        );
      },
    );
  }
}