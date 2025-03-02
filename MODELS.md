# AI Models in Write4Me

This document provides information about the AI models used in Write4Me, including their capabilities, licenses, and configuration details.

## Text Generation Models

### Online Models

#### OpenAI 4o Mini (via Pollinations API)

- **Description**: OpenAI's compact but powerful language model, accessed through Pollinations API
- **Use Case**: Main text generation when in online mode
- **Capabilities**:
  - General question answering
  - Document context integration
  - Chat conversation handling
- **Limitations**:
  - Requires internet connection
  - Subject to API availability

### Offline Models

#### Qwen 2.5B (0.5 Quantized)

- **Description**: Alibaba Cloud's lightweight language model, quantized for mobile use
- **Size**: Approximately 1.4GB (post-quantization)
- **License**: [Qwen License Agreement](https://github.com/QwenLM/Qwen/blob/main/LICENSE)
- **Use Case**: Primary offline text generation model
- **Capabilities**:
  - General text generation
  - Document-based responses
  - Context understanding
- **Performance**:
  - Inference speed: ~1-2 tokens/sec on mid-range devices
  - Context window: 2048 tokens
- **Download**: Available through the app's model manager

#### Deepseek R1 1.5B

- **Description**: Deepseek's compact reasoning-enhanced language model
- **Size**: Approximately 900MB (quantized)
- **License**: [DeepSeek License](https://github.com/deepseek-ai/DeepSeek-LLM/blob/main/LICENSE)
- **Use Case**: Alternative offline text generation, optimized for reasoning tasks
- **Capabilities**:
  - Logical reasoning
  - Document analysis
  - Structured output
- **Performance**:
  - Inference speed: ~2-3 tokens/sec on mid-range devices
  - Context window: 1024 tokens
- **Download**: Available through the app's model manager

## Embedding Models

### MiniLM-L6-V2 (ONNX Format)

- **Description**: Sentence-transformers model for generating text embeddings
- **Size**: ~22MB
- **License**: [Apache 2.0](https://github.com/onnx/models/blob/master/LICENSE)
- **Use Case**: Document indexing and semantic search
- **Capabilities**:
  - Generate 384-dimensional embeddings
  - Semantic similarity matching
  - Cross-lingual capabilities
- **Performance**:
  - Embedding generation: ~50ms per chunk on mid-range devices
- **Integration**: Used by both online and offline modes for document processing

## Image Generation Models

### Flux Model (via API)

- **Description**: Image generation model accessed through API
- **Use Case**: Creating images from text descriptions
- **Capabilities**:
  - Generate images from text prompts
  - Style customization
- **Limitations**:
  - Requires internet connection
  - Subject to API usage limitations

## Model Storage and Management

The app handles model storage and management as follows:

1. **Download Management**:
   - Models are downloaded via the app's Settings page
   - Progress tracking is provided
   - Integrity verification after download

2. **Storage Location**:
   - Android: `[app_data_directory]/models/`
   - iOS: `[app_documents_directory]/models/`

3. **Versioning**:
   - Model versions are tracked in local storage
   - Update notifications when new versions are available

## Implementation Details

### Text Model Integration

Text generation models are loaded and managed through the `OfflineModelService`, which:
- Handles model initialization
- Manages tokenization
- Controls the generation parameters
- Provides streaming output

Example configuration for Qwen 2.5B:
```dart
// Temperature controls randomness (0.0-1.0)
final temperature = 0.7;

// Top-p controls diversity (0.0-1.0)
final topP = 0.9;

// Max tokens to generate
final maxTokens = 512;
```

### Embedding Model Integration

The embedding model is managed by the `EmbeddingGenerator` class, which:
- Handles model loading
- Tokenizes input text
- Generates embeddings
- Caches model files

## Adding New Models

To add support for a new offline model:

1. Implement model loading in `OfflineModelService`
2. Add model metadata to the model registry
3. Implement tokenization and generation logic
4. Add download support in the UI

Example of adding model metadata:
```dart
final newModel = OfflineModel(
  name: "Model Name",
  fileName: "model_file.bin",
  size: 1500000000, // Size in bytes
  description: "Description of the model",
  downloadUrl: "https://example.com/model_download_url",
  contextSize: 2048,
);
```

## Model Performance Optimization

The app implements several optimizations for model performance:

1. **Quantization**: Models are quantized to reduce size and improve inference speed
2. **Caching**: Model weights are cached to avoid reloading
3. **Chunk Processing**: Large documents are processed in chunks
4. **Background Processing**: Heavy operations run on background isolates

## Ethical Considerations

When using these models, be aware of:

1. **Bias**: All models may exhibit biases present in their training data
2. **Limitations**: Models may generate incorrect or misleading information
3. **Content Policy**: Avoid using models for generating harmful content

## Model Updates

Models will be periodically updated to improve performance and capabilities. The app will notify users when updates are available for download. 