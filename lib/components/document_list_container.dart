import 'package:flutter/material.dart';
import '../models/pdf_memory.dart';

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

  Color _getChipColor(BuildContext context, bool isImage, bool isPDF) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isImage) return colorScheme.secondary.withOpacity(0.1);
    if (isPDF) return colorScheme.tertiary.withOpacity(0.1);
    return colorScheme.primary.withOpacity(0.1);
  }

  Color _getSelectedChipColor(BuildContext context, bool isImage, bool isPDF) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isImage) return colorScheme.secondary;
    if (isPDF) return colorScheme.tertiary;
    return colorScheme.primary;
  }

  IconData _getFileIcon(bool isImage, bool isPDF) {
    if (isImage) return Icons.image;
    if (isPDF) return Icons.picture_as_pdf;
    return Icons.file_present;
  }

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: documents.map((doc) {
            final isImage = doc.name.startsWith('Image:');
            final isPDF = doc.name.endsWith('.pdf');
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () => onLongPress(doc),
                child: InputChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFileIcon(isImage, isPDF),
                        size: 16,
                        color: doc.isSelected 
                            ? Theme.of(context).colorScheme.onPrimary
                            : _getSelectedChipColor(context, isImage, isPDF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _truncateFileName(doc.name),
                        style: TextStyle(
                          color: doc.isSelected 
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                      ),
                    ],
                  ),
                  selected: doc.isSelected,
                  onPressed: () {
                    doc.isSelected = !doc.isSelected;
                    onSelectionChanged();
                  },
                  onDeleted: () => onRemove(doc),
                  backgroundColor: doc.isSelected 
                      ? _getSelectedChipColor(context, isImage, isPDF)
                      : _getChipColor(context, isImage, isPDF),
                  deleteIconColor: doc.isSelected 
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                  side: BorderSide(
                    color: _getSelectedChipColor(context, isImage, isPDF).withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _truncateFileName(String fileName) {
    if (fileName.startsWith('Image:')) {
      return 'Image ${fileName.split(':').last.split('.').first}';
    }
    if (fileName.length > 20) {
      return '${fileName.substring(0, 17)}...';
    }
    return fileName;
  }
}
