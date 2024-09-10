import 'package:flutter/material.dart';
import '../models/pdf_memory.dart';

class PDFList extends StatelessWidget {
  final List<PDFMemory> pdfMemories;
  final VoidCallback onSelectionChanged;

  const PDFList({
    super.key,
    required this.pdfMemories,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        
        Wrap(
          spacing: 8,
          children: pdfMemories.map((memory) => Column(
            children: [
              const Text(
          'Selected PDFs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
              FilterChip(
                label: Text(memory.pdfName),
                selected: memory.isSelected,
                onSelected: (bool selected) {
                  memory.isSelected = selected;
                  onSelectionChanged();
                },
              ),
            ],
          )).toList(),
        ),
      ],
    );
  }
}