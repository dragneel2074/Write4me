import 'package:flutter/material.dart';
import '../models/pdf_memory.dart';
import '../models/image_memory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/selected_documents_provider.dart';

class DocumentListContainer extends ConsumerWidget {
  final List<dynamic> documents;
  final VoidCallback onSelectionChanged;
  final Function(dynamic) onLongPress;
  final Function(dynamic) onRemove;

  const DocumentListContainer({
    super.key,
    required this.documents,
    required this.onSelectionChanged,
    required this.onLongPress,
    required this.onRemove,
  });

  Color _getChipColor(BuildContext context, bool isImage, bool isPDF) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isImage) return colorScheme.secondary.withValues(alpha:0.1);
    if (isPDF) return colorScheme.tertiary.withValues(alpha:0.1);
    return colorScheme.primary.withValues(alpha:0.1);
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: documents.map((doc) {
            final isImage = doc is ImageMemory;
            final isPDF = doc is PDFMemory;
            
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
                    
                    // Update the selectedDocumentsProvider
                    final provider = ref.read(selectedDocumentsProvider.notifier);
                    if (doc.isSelected) {
                      // Add to provider if selected
                      provider.state = [...provider.state, doc];
                      debugPrint("Document selected: ${doc.name}");
                    } else {
                      // Remove from provider if deselected
                      provider.state = provider.state.where((m) => m.name != doc.name).toList();
                      debugPrint("Document deselected: ${doc.name}");
                    }
                  },
                  onDeleted: () => onRemove(doc),
                  backgroundColor: doc.isSelected 
                      ? _getSelectedChipColor(context, isImage, isPDF)
                      : _getChipColor(context, isImage, isPDF),
                  deleteIconColor: doc.isSelected 
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                  side: BorderSide(
                    color: _getSelectedChipColor(context, isImage, isPDF).withValues(alpha:0.5),
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
