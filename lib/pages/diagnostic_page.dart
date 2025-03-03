import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/file_processor_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A diagnostic page to check the status of the vector store and document processing.
class DiagnosticPage extends ConsumerStatefulWidget {
  const DiagnosticPage({super.key});

  @override
  ConsumerState<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends ConsumerState<DiagnosticPage> {
  final TextEditingController _testController = TextEditingController();
  String _testQuery = '';
  bool _isLoading = false;
  Map<String, dynamic> _stats = {};
  List<String> _diagnosticMessages = [];
  List<Document> _searchResults = [];
  bool _isSearching = false;
  bool _isRunningDiagnosticTest = false;
  Map<String, dynamic> _diagnosticTestResults = {};

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
    
    // Initialize the controller with the current value
    _testController.text = _testQuery;
    
    // Add listener to update _testQuery when controller changes
    _testController.addListener(() {
      setState(() {
        _testQuery = _testController.text;
      });
    });
  }
  
  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    _testController.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _diagnosticMessages = ['Loading vector store statistics...'];
    });

    try {
      final fileProcessor = ref.read(fileProcessorProvider);
      _stats = await fileProcessor.getVectorStoreStats();
      
      setState(() {
        _diagnosticMessages.add('Vector store statistics loaded');
        _diagnosticMessages.add('Document count: ${_stats['documentCount']}');
        _diagnosticMessages.add('Collections: ${_stats['collections']}');
        _diagnosticMessages.add('Status: ${_stats['status']}');
        
        if (_stats['documentCount'] == 0) {
          _diagnosticMessages.add('WARNING: No documents found in the vector store.');
          _diagnosticMessages.add('Try uploading a document first.');
        } else if (_stats['documentCount'] < 10) {
          _diagnosticMessages.add('NOTE: Small number of documents in the vector store.');
          _diagnosticMessages.add('For better results, try adding more content.');
        } else {
          _diagnosticMessages.add('Vector store looks healthy with ${_stats['documentCount']} documents.');
        }
      });
    } catch (e) {
      setState(() {
        _diagnosticMessages.add('Error loading diagnostics: $e');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performTestSearch() async {
    if (_testQuery.trim().isEmpty) {
      return;
    }
    
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });
    
    try {
      final fileProcessor = ref.read(fileProcessorProvider);
      
      if (kDebugMode) {
        print("DiagnosticPage: Performing test search with query: '$_testQuery'");
      }
      
      // Run the comprehensive diagnostic test
      final diagnosticResults = await fileProcessor.runDiagnosticTest(_testQuery);
      
      if (kDebugMode) {
        print("DiagnosticPage: Diagnostic test results: $diagnosticResults");
      }
      
      // Add diagnostic results to messages
      setState(() {
        _diagnosticMessages.add("📊 Diagnostic Test Results:");
        _diagnosticMessages.add("• Test Summary: ${diagnosticResults['testSummary']}");
        _diagnosticMessages.add("• Document Added: ${diagnosticResults['documentAdded']}");
        _diagnosticMessages.add("• Vector Search: ${diagnosticResults['vectorSearchSuccess'] ? '✅ Working' : '❌ Failed'}");
        _diagnosticMessages.add("• Marker Search: ${diagnosticResults['markerSearchSuccess'] ? '✅ Working' : '❌ Failed'}");
        _diagnosticMessages.add("• Fallback Search: ${diagnosticResults['fallbackSearchSuccess'] ? '✅ Working' : '❌ Failed'}");
        _diagnosticMessages.add("• Document Count: ${diagnosticResults['docCountBefore']} → ${diagnosticResults['docCountAfter']}");
      });
      
      // Also perform a regular search to see actual results
      final results = await fileProcessor.queryFile(_testQuery);
      
      setState(() {
        _isSearching = false;
        _searchResults = results;
        
        if (results.isEmpty) {
          _diagnosticMessages.add("❌ No results found for query: '$_testQuery'");
        } else {
          _diagnosticMessages.add("✅ Found ${results.length} results for query: '$_testQuery'");
          
          // Add details about the first result
          if (results.isNotEmpty) {
            final firstResult = results[0];
            final snippet = firstResult.pageContent.length > 100 
                ? "${firstResult.pageContent.substring(0, 100)}..." 
                : firstResult.pageContent;
            
            _diagnosticMessages.add("📄 First result: $snippet");
            _diagnosticMessages.add("📋 Metadata: ${firstResult.metadata}");
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("DiagnosticPage: Error performing test search: $e");
      }
      
      setState(() {
        _isSearching = false;
        _diagnosticMessages.add("❌ Error performing test search: $e");
      });
    }
  }

  Future<void> _runDiagnosticTest() async {
    setState(() {
      _isRunningDiagnosticTest = true;
      _diagnosticTestResults = {};
    });

    try {
      final fileProcessor = ref.read(fileProcessorProvider);
      final results = await fileProcessor.runDiagnosticTest('test diagnostic document');
      
      setState(() {
        _diagnosticTestResults = results;
      });
    } catch (e) {
      setState(() {
        _diagnosticTestResults = {
          'success': false,
          'error': e.toString(),
        };
      });
    } finally {
      setState(() {
        _isRunningDiagnosticTest = false;
      });
    }
  }

  // Add a test document to the vector store for diagnostic purposes
  Future<Map<String, dynamic>> _createTestDocument() async {
    try {
      final fileProcessor = ref.read(fileProcessorProvider);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testKey = "diagnostic_$timestamp";
      
      final testContent = """
This is a diagnostic test document created at ${DateTime.now().toString()}.
It contains a unique identifier: $testKey
This document is used to test the vector store and embedding functionality.
If you can see this in search results, the system is working properly.
The test includes common search terms: diagnostics, test, vector, embedding, search.

Recent headlines underscore a multifaceted shift in global geopolitics. Gold prices edged higher 
today amid a weaker dollar and lingering uncertainty 
over a delayed Ukraine peace deal citeturn0news19. At the same time, strategic discussions about 
critical minerals are intensifying—with experts warning that control over Ukraine’s mineral wealth could 

reshape trade dependencies and realign alliances citeturn0news18
. Commentators have noted that President Trump’s unpredictable, transactional approach is deepening 
transatlantic fissures, spurring European leaders to push for greater strategic autonomy and a rethinking of 
traditional security arrangements citeturn0news32. Meanwhile, as trade frictions resurface, some European 
policymakers are advocating for targeted deregulation to bolster competitiveness and fend off potential tariff shocks.
 Together, these developments paint a picture of an increasingly fragmented, competitive world order where economic and 
 resource strategies are becoming key drivers of geopolitical realignment.
      """.trim();
      
      if (kDebugMode) {
        print("DiagnosticPage: Creating test document with key $testKey");
      }
      
      await fileProcessor.processText(testContent, "diagnostic_test.txt");
      
      // Add to diagnostic messages
      setState(() {
        _diagnosticMessages.add("✅ Created test document with key: $testKey");
      });
      
      return {
        'success': true,
        'testKey': testKey,
        'content': testContent,
      };
    } catch (e) {
      if (kDebugMode) {
        print("DiagnosticPage: Error creating test document: $e");
      }
      
      setState(() {
        _diagnosticMessages.add("❌ Failed to create test document: $e");
      });
      
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vector Store Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Add Test Document",
            onPressed: () async {
              final result = await _createTestDocument();
              if (result['success'] == true) {
                final testKey = result['testKey'];
                _testController.text = "Find the document with key $testKey";
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Diagnostics",
            onPressed: () => _loadDiagnostics(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vector store stats section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vector Store Statistics',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Document Count: ${_stats['documentCount'] ?? 'Unknown'}'),
                          Text('Last Updated: ${_stats['lastUpdated'] ?? 'Unknown'}'),
                          Text('Status: ${_stats['documentCount'] != null && _stats['documentCount'] > 0 ? 'Active' : 'Empty or Error'}'),
                          
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.bug_report),
                                label: const Text('Run Full Diagnostic Test'),
                                onPressed: () async {
                                  setState(() {
                                    _diagnosticMessages.add("🔍 Running full diagnostic test...");
                                  });
                                  
                                  try {
                                    final fileProcessor = ref.read(fileProcessorProvider);
                                    final results = await fileProcessor.runDiagnosticTest("test diagnostic vector search");
                                    
                                    setState(() {
                                      _diagnosticMessages.add("📊 Diagnostic Test Results:");
                                      _diagnosticMessages.add("• Test Summary: ${results['testSummary']}");
                                      _diagnosticMessages.add("• Document Added: ${results['documentAdded']}");
                                      _diagnosticMessages.add("• Vector Search: ${results['vectorSearchSuccess'] ? '✅ Working' : '❌ Failed'}");
                                      _diagnosticMessages.add("• Marker Search: ${results['markerSearchSuccess'] ? '✅ Working' : '❌ Failed'}");
                                      _diagnosticMessages.add("• Fallback Search: ${results['fallbackSearchSuccess'] ? '✅ Working' : '❌ Failed'}");
                                      _diagnosticMessages.add("• Document Count: ${results['docCountBefore']} → ${results['docCountAfter']}");
                                      
                                      if (results['success']) {
                                        _diagnosticMessages.add("✅ Diagnostic test completed successfully");
                                      } else {
                                        _diagnosticMessages.add("❌ Diagnostic test failed");
                                      }
                                    });
                                  } catch (e) {
                                    setState(() {
                                      _diagnosticMessages.add("❌ Error running diagnostic test: $e");
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Vector Store Status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final message in _diagnosticMessages)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(message),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'System Diagnostic Test',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton(
                        onPressed: _isRunningDiagnosticTest ? null : _runDiagnosticTest,
                        child: _isRunningDiagnosticTest
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Run Test'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_diagnosticTestResults.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test ${_diagnosticTestResults['success'] == true ? 'Passed ✅' : 'Failed ❌'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _diagnosticTestResults['success'] == true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_diagnosticTestResults.containsKey('error'))
                              Text(
                                'Error: ${_diagnosticTestResults['error']}',
                                style: const TextStyle(color: Colors.red),
                              )
                            else ...[
                              Text('Results count: ${_diagnosticTestResults['resultsCount']}'),
                              Text('Embedding generated: ${_diagnosticTestResults['embeddingGenerated']}'),
                              Text('Embedding length: ${_diagnosticTestResults['embeddingLength']}'),
                              if (_diagnosticTestResults['firstResultSnippet'] != null)
                                Text('First result: ${_diagnosticTestResults['firstResultSnippet']}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Test Vector Search',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _testController,
                    decoration: const InputDecoration(
                      labelText: 'Test Query',
                      hintText: 'Enter a query to test the vector store',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _testQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _performTestSearch,
                    child: _isSearching 
                        ? const CircularProgressIndicator()
                        : const Text('Test Search'),
                  ),
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Search Results:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print Results'),
                          onPressed: () => _printSearchResults(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Export'),
                          onPressed: () => _exportSearchResults(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const Text(
                          'Search Results:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._searchResults.map((doc) {
                          final source = doc.metadata['source'] ?? 'Unknown';
                          final file = doc.metadata['file'] ?? 'Unknown';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Source: $source (File: $file)',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doc.pageContent.length > 200
                                        ? '${doc.pageContent.substring(0, 200)}...'
                                        : doc.pageContent,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Troubleshooting Tips',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• If no documents are found, try uploading a PDF first'),
                          Text('• If search results are poor, try using more specific queries'),
                          Text('• Large PDFs are processed in batches, so all content might not be immediately available'),
                          Text('• Check logs for any errors during document processing'),
                          Text('• Try restarting the app if vector store is not working correctly'),
                          Text('• Run the diagnostic test to verify embedding and vector store functionality'),
                          Text('• Make sure the embedding model is properly initialized'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Set a predefined test query and run the test
          setState(() {
            _testController.text = "diagnostic test vector embedding";
            _testQuery = _testController.text;
          });
          _performTestSearch(); // Use the existing method
        },
        icon: const Icon(Icons.bug_report),
        label: const Text('Quick Test'),
        tooltip: 'Run a quick diagnostic test with a pre-defined query',
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  /// Print detailed search results to console and show a snackbar
  void _printSearchResults() {
    if (_searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results to print')),
      );
      return;
    }

    if (kDebugMode) {
      print('\n====== VECTOR SEARCH RESULTS ======');
      print('Query: "$_testQuery"');
      print('Found ${_searchResults.length} results');
      print('====================================');
      
      for (int i = 0; i < _searchResults.length; i++) {
        final doc = _searchResults[i];
        final source = doc.metadata['source'] ?? 'Unknown';
        final file = doc.metadata['file'] ?? 'Unknown';
        final chunkIndex = doc.metadata['chunkIndex'] ?? 'N/A';
        final totalChunks = doc.metadata['totalChunks'] ?? 'N/A';
        
        print('\nRESULT #${i+1}:');
        print('Source: $source');
        print('File: $file');
        print('Chunk: $chunkIndex of $totalChunks');
        
        // Print all metadata keys
        print('Metadata:');
        doc.metadata.forEach((key, value) {
          if (key != 'embedding') { // Skip embedding vector which is too long
            if (kDebugMode) {
              print('  $key: $value');
            }
          } else {
            if (kDebugMode) {
              print('  embedding: [vector with ${(value as List?)?.length ?? 0} dimensions]');
            }
          }
        });
        
        print('Content:');
        print('"""\n${doc.pageContent}\n"""');
        print('------------------------------------');
      }
      
      print('====== END OF RESULTS ======\n');
    }
    
    // Show a snackbar to confirm
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printed ${_searchResults.length} results to debug console'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Export search results to a text file and share it
  Future<void> _exportSearchResults() async {
    if (_searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results to export')),
      );
      return;
    }
    
    try {
      // Create content for the file
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('VECTOR SEARCH RESULTS');
      buffer.writeln('Date: ${DateTime.now().toLocal()}');
      buffer.writeln('Query: "$_testQuery"');
      buffer.writeln('Result Count: ${_searchResults.length}');
      buffer.writeln('-' * 50);
      
      for (int i = 0; i < _searchResults.length; i++) {
        final doc = _searchResults[i];
        final source = doc.metadata['source'] ?? 'Unknown';
        final file = doc.metadata['file'] ?? 'Unknown';
        
        buffer.writeln('\nRESULT #${i+1}:');
        buffer.writeln('Source: $source');
        buffer.writeln('File: $file');
        
        // Add metadata (except for embedding which is too large)
        buffer.writeln('Metadata:');
        doc.metadata.forEach((key, value) {
          if (key != 'embedding') {
            buffer.writeln('  $key: $value');
          }
        });
        
        buffer.writeln('Content:');
        buffer.writeln('"""');
        buffer.writeln(doc.pageContent);
        buffer.writeln('"""');
        buffer.writeln('-' * 50);
      }
      
      final String content = buffer.toString();
      
      // Create the file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/search_results_$timestamp.txt';
      final file = File(path);
      await file.writeAsString(content);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Vector Search Results',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results exported successfully')),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting results: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting results: $e')),
      );
    }
  }
} 