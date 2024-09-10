import 'package:flutter/material.dart';

import 'components/button_box.dart';
import 'components/pdf_list.dart';
import 'components/topic_selection.dart';
import 'models/pdf_memory.dart';
import 'services/ai_service.dart';
import 'services/pdf_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<PDFMemory> _pdfMemories = [];
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  bool _isLoading = false;
  final PDFService _pdfService = PDFService();
  final AIService _aiService = AIService();

  Future<void> _pickPDFAndCreateRAG() async {
    try {
      PDFMemory? newMemory = await _pdfService.pickAndProcessPDF();
      if (newMemory != null) {
        setState(() {
          _pdfMemories.add(newMemory);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF processed: ${newMemory.pdfName}')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error processing PDF: ${e.toString()}');
    }
  }

  Future<void> _submitTopic() async {
    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      String question = _controller.text;
      if (question.isEmpty) {
        throw Exception('Please enter a question');
      }

      List<PDFMemory> selectedMemories = _pdfMemories.where((memory) => memory.isSelected).toList();
      _response = await _aiService.getResponse(question, selectedMemories);
    } catch (e) {
      _showErrorSnackBar(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write4Me'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: _pickPDFAndCreateRAG,
          tooltip: 'Add PDF',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            TopicSection(controller: _controller),
            PDFList(
              pdfMemories: _pdfMemories,
              onSelectionChanged: () => setState(() {}),
            ),
            ElevatedButton(
              onPressed: _submitTopic,
              child: const Text('Go'),
            ),
            const SizedBox(height: 20),
            if (_isLoading) 
              const CircularProgressIndicator() 
            else if (_response.isNotEmpty)
              ResponseBox(response: _response),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Image.asset(
      'assests/images/playstore.png',
      width: 150,
      height: 150,
      fit: BoxFit.contain,
    );
  }
}