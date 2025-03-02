# Write4Me Architecture

This document provides an in-depth explanation of the Write4Me app architecture. It's intended for developers who want to understand the codebase and potentially contribute to it.

## System Overview

Write4Me is a Flutter application that provides AI-powered text generation with document context enhancement (RAG). The app is designed to function in both online and offline modes, with a focus on privacy and flexibility.

## Core Components

### 1. Main Application Structure

The application entry point is `lib/main.dart`, which sets up the Flutter app with provider-based state management using Riverpod. The app uses Hive for local storage.

### 2. File Processing

#### `FileProcessor` (`lib/file_processing/file_processor.dart`)

Responsible for:
- Reading and processing documents (currently text files)
- Chunking documents using semantic boundaries
- Generating embeddings for each chunk via `FonnxEmbeddings`
- Storing documents in the vector store
- Querying the vector store for relevant document chunks

Key methods:
- `processText()`: Processes raw text content
- `processFile()`: Processes a file from the file system
- `queryFile()`: Retrieves relevant documents based on semantic similarity

### 3. Vector Store

#### `ChromaVectorStore` (`lib/vector_store/chroma_vector_store.dart`)

A Langchain-compatible vector store implementation that:
- Stores document chunks and their embeddings
- Provides similarity search functionality
- Supports filtering by metadata (e.g., file names)

### 4. Embeddings

#### `EmbeddingGenerator` (`lib/embedding_generator.dart`)

Low-level utility that:
- Manages the MiniLM-L6-V2 ONNX model
- Handles model loading and caching
- Generates embeddings for text inputs

#### `FonnxEmbeddings` (`lib/embeddings/fonnx_embeddings.dart`)

Langchain-compatible wrapper that:
- Implements the `Embeddings` interface
- Uses `EmbeddingGenerator` to create embeddings
- Provides batch embedding generation for documents

### 5. AI Services

#### `AIService` (`lib/services/ai_service.dart`)

Orchestration layer that:
- Coordinates between online and offline text generation
- Manages web search when enabled
- Integrates document context from vector store
- Handles streaming responses

#### `TextGenerationService` (`lib/services/text_generation_service.dart`)

Online text generation service that:
- Communicates with the Pollinations API (OpenAI 4o mini)
- Provides web search capabilities via Jina API
- Formats prompts with appropriate context and history
- Handles streaming responses

#### `OfflineModelService` (`lib/services/offline_model_service.dart`)

Manages offline text generation using:
- Downloadable models (Qwen 2.5b, Deepseek R1 1.5b)
- Local inference without internet connection
- Model selection and configuration

### 6. RAG Controller

#### `RAGController` (`lib/app/rag_controller.dart`)

Ties together the RAG system:
- Accepts user queries
- Gets selected document files
- Retrieves relevant document chunks via vector similarity
- Formats context for the text generation services
- Returns generated answers

### 7. Models

#### Document Models

- `Document`: Represents a chunk of text with metadata and embeddings
- `PDFMemory` (`lib/models/pdf_memory.dart`): Represents a PDF file with extracted text
- `ChatMessage` (`lib/models/chat_message.dart`): Represents a message in the chat history

## Data Flow

1. **Document Processing Flow**:
   - User uploads a document
   - `PDFService` extracts text
   - `FileProcessor` chunks the text
   - `FonnxEmbeddings` generates embeddings
   - `ChromaVectorStore` stores the chunks and embeddings

2. **Query Flow**:
   - User submits a query
   - Selected documents are retrieved
   - `FileProcessor.queryFile()` finds relevant chunks
   - `AIService` combines query + chunks into a prompt
   - Model generates a response (online or offline)
   - Response is streamed to the UI

3. **Offline Mode Flow**:
   - User enables offline mode
   - `OfflineModelService` handles inference
   - Document retrieval still works via local embeddings
   - All processing happens on-device

## Technical Decisions

### Embedding Model Choice

MiniLM-L6-V2 was chosen for embeddings because:
- Small size (22MB) for mobile devices
- Good performance for document retrieval
- Available in ONNX format for cross-platform compatibility

### Chunking Strategy

Documents are chunked with:
- Semantic boundary awareness (paragraphs/sentences)
- Overlap between chunks to preserve context
- Size limits for efficient processing

### Vector Similarity

The system uses cosine similarity to find relevant document chunks, which:
- Works well with the chosen embedding model
- Is computationally efficient
- Provides good semantic matching

## Extending the System

### Adding New Document Types

To add support for new document types:
1. Create a new service for extraction (similar to `PDFService`)
2. Use the existing `FileProcessor` for chunking and embedding
3. Update the UI to support the new document type

### Adding New Models

To integrate new language models:
1. Update `OfflineModelService` with the new model details
2. Implement the loading and inference logic
3. Update the UI to allow model selection

### Improving RAG

To enhance the RAG system:
1. Experiment with different chunking strategies
2. Implement re-ranking of retrieved documents
3. Add support for hybrid search (keyword + semantic) 