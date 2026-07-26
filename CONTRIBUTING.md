# Contributing to Write4Me

Thank you for your interest in contributing to Write4Me! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to keep our community respectful and inclusive.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```
   git clone https://github.com/YOUR_USERNAME/Write4me.git
   cd Write4me
   ```
3. **Set up the development environment**:
   ```
   flutter pub get
   ```
4. **Create a branch** for your contribution:
   ```
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Environment Setup

- **Flutter**: Use the latest stable version
- **IDE**: VS Code or Android Studio with Flutter plugins recommended
- **Emulators/Devices**: Test on an Android API 26+ device. Physical-device
  testing is strongly recommended for GGUF memory and lifecycle behavior.

### Running the App

```
flutter run
```

For specific device:
```
flutter run -d [device_id]
```

### Testing

Run the test suite:
```
flutter test
```

### Building

For Android APK:
```
flutter build apk
```

The current local GGUF integration is Android-only.

## Making Changes

1. Make your changes in your feature branch
2. Add or update tests as necessary
3. Ensure the code follows the project's style guide
4. Make sure all tests pass
5. Update documentation as needed

## Submitting Changes

1. **Commit your changes** with descriptive commit messages:
   ```
   git commit -m "Add feature: your feature description"
   ```

2. **Push to your fork**:
   ```
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** from your fork to the main repository
   - Provide a clear description of the changes
   - Reference any related issues
   - Fill out the PR template

## Pull Request Process

1. Update the README.md or documentation with details of changes if appropriate
2. The PR will be reviewed by maintainers who may suggest changes
3. Once approved, a maintainer will merge your PR
4. Celebrate your contribution!

## Style Guidelines

### Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Write comments for complex logic
- Keep functions small and focused

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Keep messages clear and descriptive
- Reference issues and pull requests where appropriate

### Documentation

- Update documentation for public APIs
- Add comments to explain complex code
- Document any workarounds or technical debt

## Working with Issues

- Look for issues labeled "good first issue" if you're new to the project
- Comment on an issue if you're working on it
- Create an issue if you find a bug or have a feature request

## Adding New Features

When adding new features:

1. **Discuss first**: Open an issue to discuss the feature before implementing
2. **Consider architecture**: Read the [ARCHITECTURE.md](ARCHITECTURE.md) document
3. **Maintain compatibility**: Preserve both cloud and on-device workflows
4. **Add tests**: Include unit and/or integration tests
5. **Document**: Update relevant documentation

## Feature Specific Guidelines

### Adding Models

When adding support for a new model:

1. Do not hardcode cloud model IDs; load them from the provider API
2. Document model capabilities, memory expectations, and license
3. Implement credential, loading, cancellation, and error states
4. Test local GGUF changes on Android API 26+ hardware

### Document Processing

When enhancing document processing:

1. Follow existing chunking patterns
2. Consider memory usage on mobile devices
3. Test with various document sizes and formats

### User Interface

When modifying the UI:

1. Follow Material Design guidelines
2. Ensure accessibility compliance
3. Test on different screen sizes
4. Consider dark/light theme compatibility

## Getting Help

If you need help with the contribution process or have questions:

- Open a Discussion on GitHub
- Comment on the relevant issue
- Contact the maintainers via email

## Thank You

Your contributions to Write4Me help make it a better tool for everyone!
