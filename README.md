# Write4Me

![Write4Me Logo](assets/images/logo.png)

A powerful Flutter-based writing assistant that leverages advanced language models for text generation, document analysis, and image creation - available both online and offline.

## Features

### Text Generation
- **Free Cloud API**: Powered by OpenAI's 4o mini model through Pollinations API
- **Web Search Integration**: Optional web search capability using Jina API for up-to-date information
- **Conversation History**: Maintains chat history for contextual follow-up questions
- - **Document-Enhanced Responses**: Uses Retrieval Augmented Generation (RAG) to provide context-aware answers based on your documents (Future Update)

### Image Generation
- **AI Image Creation**: Generate images using Flux model (NSFW Filter is Turned On)

### Offline Capabilities
- **Fully Offline Mode**: Use the app without an internet connection
- **Downloadable Models**: Support for offline models:
  - Qwen 2.5b (0.5 quantized)
  - Deepseek R1 1.5b
- **Local Document Processing**: Process and search your documents entirely on-device

### Document Analysis
- **PDF Support**: Upload and analyze PDF documents
- **Image OCR Support**: Upload and extract text from documents
- **Semantic Search**: Find relevant information across your documents using vector similarity (Future Update)
- **Document Memory**: Save and manage document references for future use (Future Update)

## Architecture

The application follows a modular architecture designed for flexibility and extensibility:

### Core Components:


1. **AI Services**
   - `TextGenerationService`: Handles cloud-based text generation
   - `OfflineModelService`: Manages local model inference
   - `AIService`: Coordinates between online and offline modes

## Installation

### Prerequisites
- Flutter (latest stable version)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Setup
1. Clone the repository:
   ```
   git clone https://github.com/your-username/Write4me.git
   ```

2. Navigate to the project directory:
   ```
   cd Write4me
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the app:
   ```
   flutter run
   ```
5. Build APK for Android

 ```
   flutter build apk --release
```
### API Keys
For web search functionality, you'll need:
- Jina API key (configure in app settings)

## Usage

### Text Generation
1. Type your query in the chat interface
2. Toggle web search if needed
3. Select relevant documents to provide context
4. Receive AI-generated responses

### Document Management
1. Upload PDFs via the document interface
2. Select documents to include in your context
3. Use the search functionality to find specific information

### Offline Mode
1. Download models through the settings page
2. Toggle offline mode when internet is unavailable
3. Continue using the app with full functionality

## Models

### Online Models
- Text: OpenAI's 4o mini (via Pollinations API)
- Image: Flux

### Offline Models
- Qwen 2.5b (0.5 quantized)
- Deepseek R1 1.5b
- Download Others As You Like


## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the project's style guidelines and includes appropriate tests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Pollinations.AI](https://pollinations.ai) for the text generation API
- [Jina AI](https://jina.ai) for the search API
- [Langchain.dart](https://github.com/davidmigloz/langchain_dart) for RAG functionality
- [FONNX](https://github.com/fonnx/flutter) for ONNX runtime integration
- The Flutter community for their incredible tools and support

