import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:write4me/services/web_service.dart';
import 'package:write4me/services/image_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
  final WebService _webService = WebService();
  final ImageService _imageService = ImageService();

  Future<void> _showAddOptions() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Content'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('Web'),
              onTap: () {
                Navigator.pop(context);
                _processWebContent();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_copy),
              title: const Text('Files'),
              onTap: () {
                Navigator.pop(context);
                _pickPDFAndCreateRAG();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                _processImageContent();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processWebContent() async {
    try {
      String? url = await _showURLInputDialog();
      if (url != null && url.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing web content from: $url')),
        );
        
        PDFMemory? newMemory = await _webService.processWebContent(url);
        
        setState(() {
          _isLoading = false;
        });
        
        setState(() {
          _pdfMemories.add(newMemory!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Web content processed: ${newMemory?.pdfName}')),
        );
            }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error processing web content: ${e.toString()}');
    }
  }

  Future<String?> _showURLInputDialog() async {
    String? url;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter URL'),
        content: TextField(
          onChanged: (value) {
            url = value;
          },
          decoration: const InputDecoration(hintText: "https://example.com"),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context, url),
          ),
        ],
      ),
    );
    return url;
  }

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

  Future<void> _processImageContent() async {
    try {
      final ImageSource? source = await _showImageSourceDialog();
      if (source != null) {
        setState(() {
          _isLoading = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image content')),
        );
        
        PDFMemory? newMemory = await _imageService.processImageContent(source);
        
        setState(() {
          _isLoading = false;
        });
        
        setState(() {
          _pdfMemories.add(newMemory!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image content processed: ${newMemory?.pdfName}')),
        );
            }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error processing image content: ${e.toString()}');
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select Image Source'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, ImageSource.camera); },
              child: const Text('Camera'),
            ),
            SimpleDialogOption(
              onPressed: () { Navigator.pop(context, ImageSource.gallery); },
              child: const Text('Gallery'),
            ),
          ],
        );
      }
    );
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

  void _showExtractedText(PDFMemory memory) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Extracted Text from ${memory.pdfName}'),
          content: SingleChildScrollView(
            child: Text(memory.extractedText),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

void _onSubmitApiKey(BuildContext context, String apiKey) async {
  bool isValid = await validateApiKey(apiKey);
  if (isValid) {
    // Save the key to shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', apiKey);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Key saved successfully!')),
    );
  } else {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid API Key. Please try again.')),
    );
  }
}



void _promptForApiKey() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController _apiKeyController = TextEditingController();

        return AlertDialog(
          title: const Text('Enter OpenAI API Key'),
          content: TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'Enter your OpenAI API key here',
            ),
            obscureText: true, // For security
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final apiKey = _apiKeyController.text;
                if (apiKey.isNotEmpty) {
                  _onSubmitApiKey(context, apiKey); // Validate and save the API key
                  Navigator.of(context).pop(); // Close the dialog
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API Key cannot be empty')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

Future<bool> validateApiKey(String apiKey) async {
  final url = Uri.parse('https://api.openai.com/v1/engines');
  try {
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );
    return response.statusCode == 200;
  } catch (e) {
    return false; // Handle network errors or unexpected issues
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Write4Me'),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.file_copy),
        onPressed: _showAddOptions,
        tooltip: 'Add Content',
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.key),
          onPressed: _promptForApiKey,
          tooltip: 'Key Action',
        ),
      ],
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
            if (_pdfMemories.isNotEmpty) ...[
              const Text('Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              PDFList(
                pdfMemories: _pdfMemories,
                onSelectionChanged: () => setState(() {}),
                onLongPress: _showExtractedText,
              ),
              const SizedBox(height: 20),
            ],
            TopicSection(controller: _controller),
            ElevatedButton(
              onPressed: _pdfMemories.isNotEmpty ? _submitTopic : null,
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
      'assets/images/playstore.png',
      width: 150,
      height: 150,
      fit: BoxFit.contain,
    );
  }
}