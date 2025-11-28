# ML Service Documentation

## Overview

The `MLService` class is a comprehensive, modular TensorFlow Lite inference engine designed for Flutter applications. It provides a flexible architecture that automatically adapts to different model configurations, supporting both **float32** and **int8 quantized** models with automatic detection of tensor layouts (NCHW/NHWC).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Components](#core-components)
3. [Model Configuration Detection](#model-configuration-detection)
4. [Tensor Layout Handling](#tensor-layout-handling)
5. [Data Type Support](#data-type-support)
6. [Inference Pipeline](#inference-pipeline)
7. [Label Management](#label-management)
8. [Persistence & Preferences](#persistence--preferences)
9. [Error Handling](#error-handling)
10. [API Reference](#api-reference)
11. [Usage Examples](#usage-examples)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         MLService                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Interpreter │  │ ModelConfig │  │ SharedPreferences       │  │
│  │ (TFLite)    │  │ (Auto-det)  │  │ (Model Persistence)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    Processing Pipeline                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │  Image   │→ │ Resize & │→ │  Tensor  │→ │    Inference     │ │
│  │  Input   │  │ Validate │  │ Convert  │  │    (TFLite)      │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘ │
│                                                      ↓           │
│  ┌──────────────────┐  ┌──────────┐  ┌──────────────────────┐   │
│  │ Top 2 Predictions│← │ Softmax  │← │   Extract Logits     │   │
│  └──────────────────┘  └──────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. MLServiceException

A custom exception class for handling ML-specific errors with detailed context.

```dart
class MLServiceException implements Exception {
  final String message;    // Human-readable error message
  final String code;       // Error code for programmatic handling
  final dynamic originalError;  // Original exception if wrapped
}
```

**Error Codes:**
| Code | Description |
|------|-------------|
| `MODEL_NOT_LOADED` | Interpreter not initialized |
| `MODEL_NOT_FOUND` | Model file doesn't exist |
| `INVALID_INPUT_SHAPE` | Unsupported tensor dimensions |
| `FILE_NOT_FOUND` | Image file doesn't exist |
| `FILE_TOO_LARGE` | Image exceeds 50MB limit |
| `DECODE_ERROR` | Failed to decode image |
| `IMAGE_TOO_SMALL` | Image smaller than 32x32 |
| `INFERENCE_ERROR` | TFLite runtime error |
| `OUTPUT_FORMAT_ERROR` | Unexpected output tensor format |

### 2. TensorLayout Enum

Defines the two common tensor memory layouts:

```dart
enum TensorLayout {
  nchw,  // [batch, channels, height, width] - PyTorch style
  nhwc,  // [batch, height, width, channels] - TensorFlow style
}
```

### 3. ModelConfig

Automatically extracted configuration from the loaded model:

```dart
class ModelConfig {
  final List<int> inputShape;   // e.g., [1, 3, 384, 384]
  final List<int> outputShape;  // e.g., [1, 101]
  final TensorType inputType;   // float32, uint8, int8
  final TensorType outputType;  // float32, uint8, int8
  final TensorLayout layout;    // nchw or nhwc
  final int batchSize;          // Usually 1
  final int channels;           // Usually 3 (RGB)
  final int height;             // e.g., 384
  final int width;              // e.g., 384
  final int numClasses;         // e.g., 101
}
```

### 4. InferenceMetrics

Performance monitoring for inference operations:

```dart
class InferenceMetrics {
  final DateTime startTime;
  final DateTime endTime;
  final String modelName;
  final String imagePath;
  final bool success;
  
  Duration get duration;  // Computed inference time
}
```

---

## Model Configuration Detection

When a model is loaded, `ModelConfig.fromInterpreter()` automatically analyzes the model's tensors:

### Layout Detection Algorithm

```dart
// Input shape analysis for 4D tensors [dim0, dim1, dim2, dim3]
if (inputShape.length == 4) {
  batchSize = inputShape[0];  // Always first dimension
  
  // NCHW: dim[1] is small (channels), dim[2,3] are large (spatial)
  if (inputShape[1] <= 4 && inputShape[2] > 4 && inputShape[3] > 4) {
    layout = TensorLayout.nchw;
    channels = inputShape[1];  // 3 for RGB
    height = inputShape[2];    // e.g., 384
    width = inputShape[3];     // e.g., 384
  }
  // NHWC: dim[3] is small (channels), dim[1,2] are large (spatial)
  else if (inputShape[3] <= 4 && inputShape[1] > 4 && inputShape[2] > 4) {
    layout = TensorLayout.nhwc;
    height = inputShape[1];
    width = inputShape[2];
    channels = inputShape[3];
  }
}
```

### Output Shape Parsing

```dart
// Handles various output shapes
if (outputShape.length == 2) {
  numClasses = outputShape[1];  // [1, num_classes]
} else if (outputShape.length == 1) {
  numClasses = outputShape[0];  // [num_classes]
} else {
  numClasses = outputShape.last;  // Fallback
}
```

---

## Tensor Layout Handling

### NCHW Format (PyTorch Style)

Memory layout: `[batch][channel][row][column]`

```
For a 384x384 RGB image:
Shape: [1, 3, 384, 384]

Memory order:
[batch=0]
  [channel=R] → all 384x384 red values
  [channel=G] → all 384x384 green values  
  [channel=B] → all 384x384 blue values
```

### NHWC Format (TensorFlow Style)

Memory layout: `[batch][row][column][channel]`

```
For a 384x384 RGB image:
Shape: [1, 384, 384, 3]

Memory order:
[batch=0]
  [row=0]
    [col=0] → [R, G, B]
    [col=1] → [R, G, B]
    ...
  [row=1]
    ...
```

---

## Data Type Support

The service automatically handles different quantization schemes:

### Float32 Models

- Input: Normalized pixel values `[0.0, 1.0]`
- Output: Raw logits (applied softmax)
- Conversion: `pixel_value / 255.0`

```dart
List<List<List<List<double>>>> _imageToNCHWFloat(img.Image image, ModelConfig config) {
  // Returns nested list with double values [0.0, 1.0]
  return pixel.r / 255.0;  // Normalize
}
```

### Int8/Uint8 Quantized Models

- Input: Raw pixel values `[0, 255]`
- Output: Quantized logits (dequantized before softmax)
- Conversion: Direct integer mapping

```dart
List<List<List<List<int>>>> _imageToNCHWInt8(img.Image image, ModelConfig config) {
  // Returns nested list with int values [0, 255]
  return pixel.r.toInt();  // No normalization
}
```

### Type Detection

```dart
final isInt8 = config.inputType == TensorType.uint8 || 
               config.inputType == TensorType.int8;

if (config.layout == TensorLayout.nchw) {
  return isInt8 ? _imageToNCHWInt8(...) : _imageToNCHWFloat(...);
} else {
  return isInt8 ? _imageToNHWCInt8(...) : _imageToNHWCFloat(...);
}
```

---

## Inference Pipeline

### Complete Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     runInference(imageFile)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. VALIDATION                                                    │
│    ├─ Check model loaded                                         │
│    ├─ Verify file exists                                         │
│    ├─ Check file size (< 50MB)                                   │
│    └─ Validate image dimensions (> 32x32)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. PREPROCESSING                                                 │
│    ├─ Decode image (JPEG, PNG, etc.)                            │
│    ├─ Resize to model dimensions (e.g., 384x384)                │
│    ├─ Detect data type (float32 vs int8)                        │
│    ├─ Detect layout (NCHW vs NHWC)                              │
│    └─ Convert to appropriate tensor format                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. INFERENCE                                                     │
│    ├─ Create output buffer (matching output type)               │
│    ├─ Execute interpreter.run(input, output)                    │
│    └─ Handle any TFLite runtime errors                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. POSTPROCESSING                                                │
│    ├─ Extract logits from output buffer                         │
│    ├─ Dequantize if int8 output                                 │
│    ├─ Apply softmax for probabilities                           │
│    ├─ Map to class labels                                       │
│    ├─ Sort by confidence (descending)                           │
│    └─ Return top 2 predictions                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Softmax Implementation

Converts raw logits to probabilities with numerical stability:

```dart
List<double> _softmax(List<double> logits) {
  // Subtract max for numerical stability (prevents overflow)
  final maxLogit = logits.reduce(math.max);
  
  // Compute exp(x - max) for each logit
  final expScores = logits.map((x) => math.exp(x - maxLogit)).toList();
  
  // Normalize to get probabilities
  final sumExp = expScores.reduce((a, b) => a + b);
  return expScores.map((x) => x / sumExp).toList();
}
```

**Mathematical Formula:**
$$\text{softmax}(x_i) = \frac{e^{x_i - \max(x)}}{\sum_{j} e^{x_j - \max(x)}}$$

---

## Label Management

### Label Loading Priority

1. **Provided path** (custom labels file)
2. **Default assets path** (`assets/models/seefood_labels.txt`)
3. **Generated placeholders** (`Class 0`, `Class 1`, ...)

```dart
Future<void> _loadLabels(String? labelsPath) async {
  _classNames.clear();

  // Priority 1: Custom labels path
  if (labelsPath != null) {
    // Load from assets or file system
  }

  // Priority 2: Default labels
  if (_classNames.isEmpty) {
    // Load from _defaultLabelsPath
  }

  // Priority 3: Generate placeholders
  if (_classNames.isEmpty && _modelConfig != null) {
    _classNames = List.generate(
      _modelConfig!.numClasses,
      (i) => 'Class $i',
    );
  }
}
```

### Label File Format

Simple text file with one label per line:

```
apple_pie
baby_back_ribs
baklava
beef_carpaccio
...
```

---

## Persistence & Preferences

The service persists user's model selection using `SharedPreferences`:

### Stored Keys

| Key | Description |
|-----|-------------|
| `selected_model_path` | Path to the loaded model file |
| `selected_model_name` | Display name of the model |
| `selected_labels_path` | Path to labels file (optional) |

### Load/Save Flow

```dart
// On initialization
Future<void> _loadSavedModelOrDefault() async {
  final prefs = await SharedPreferences.getInstance();
  final savedPath = prefs.getString(_modelPathKey);
  
  if (savedPath != null) {
    await _loadModel(savedPath, ...);  // Try saved model
  } else {
    await _loadDefaultModel();  // Fall back to default
  }
}

// After loading a new model
Future<void> _saveModelPreference(...) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_modelPathKey, modelPath);
  await prefs.setString(_modelNameKey, modelName);
}
```

---

## Error Handling

### Exception Hierarchy

```
MLServiceException
├── MODEL_NOT_LOADED    → Model not initialized
├── MODEL_NOT_FOUND     → File doesn't exist
├── INVALID_INPUT_SHAPE → Wrong tensor dimensions
├── FILE_NOT_FOUND      → Image not found
├── FILE_TOO_LARGE      → Image > 50MB
├── DECODE_ERROR        → Can't decode image
├── IMAGE_TOO_SMALL     → Image < 32x32
├── INFERENCE_ERROR     → TFLite runtime error
└── OUTPUT_FORMAT_ERROR → Unexpected output format
```

### Graceful Degradation

```dart
// Warm-up failures don't crash the app
try {
  await warmUpModel();
} catch (e) {
  debugPrint('Model warm-up failed: $e');
  // Continue without warm-up
}

// Label mismatches are warnings, not errors
if (_classNames.length != _modelConfig!.numClasses) {
  debugPrint('Warning: Label count mismatch');
  // Continue with available labels
}
```

---

## API Reference

### Initialization

| Method | Description |
|--------|-------------|
| `initialize()` | Load saved model or default |
| `initializeWithWarmup()` | Initialize + run dummy inference |

### Model Loading

| Method | Description |
|--------|-------------|
| `loadModelFromFile(path, name, {labelsPath})` | Load model from path |
| `loadModelFromDirectory(dir, filename)` | Load model + labels.txt |

### Inference

| Method | Description |
|--------|-------------|
| `runInference(File)` | Run inference, return top 2 predictions |
| `runInferenceWithMetrics(File)` | Run inference with timing info |
| `processBatchImages(List<File>)` | Process multiple images |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isModelLoaded` | `bool` | Model ready for inference |
| `isWarmedUp` | `bool` | Model warmed up |
| `currentModelName` | `String?` | Loaded model name |
| `classNames` | `List<String>` | Available class labels |
| `modelConfig` | `ModelConfig?` | Detected configuration |
| `inputHeight` | `int` | Required image height |
| `inputWidth` | `int` | Required image width |
| `tensorLayout` | `TensorLayout` | NCHW or NHWC |

### Cleanup

| Method | Description |
|--------|-------------|
| `reset()` | Clear all state |
| `dispose()` | Release interpreter resources |

---

## Usage Examples

### Basic Usage

```dart
final mlService = MLService();

// Initialize (loads default or saved model)
await mlService.initialize();

// Run inference
final predictions = await mlService.runInference(File('path/to/image.jpg'));

// Access results
for (final pred in predictions) {
  print('${pred['label']}: ${(pred['confidence'] * 100).toStringAsFixed(1)}%');
}
```

### Loading Custom Model

```dart
// Load model with custom labels
await mlService.loadModelFromFile(
  '/path/to/custom_model.tflite',
  'My Custom Model',
  labelsPath: '/path/to/labels.txt',
);

// Or load from directory (expects model + labels.txt)
await mlService.loadModelFromDirectory(
  '/path/to/model_folder',
  'model.tflite',
);
```

### With Metrics

```dart
final result = await mlService.runInferenceWithMetrics(imageFile);

print('Predictions: ${result['predictions']}');
print('Inference time: ${result['inference_time_ms']}ms');
```

### Batch Processing

```dart
final images = [File('img1.jpg'), File('img2.jpg'), File('img3.jpg')];
final results = await mlService.processBatchImages(images);

for (final result in results) {
  if (result['success']) {
    print('${result['filename']}: ${result['predictions']}');
  } else {
    print('${result['filename']}: Error - ${result['error']}');
  }
}
```

### Model Info

```dart
final info = mlService.getModelInfo();
print('Model: ${info['model_name']}');
print('Input: ${info['input_shape']} (${info['layout']})');
print('Classes: ${info['class_count']}');
```

---

## Performance Considerations

### Model Warm-up

First inference is slower due to:
- Memory allocation
- Kernel compilation (on GPU delegates)
- Cache population

**Solution:** Call `warmUpModel()` after loading:

```dart
await mlService.initializeWithWarmup();
```

### Image Preprocessing

The `image` package is used for decoding/resizing. For production:
- Consider pre-resizing images before inference
- Use hardware-accelerated image processing if available

### Memory Management

- Always call `dispose()` when done
- `reset()` clears state without disposing interpreter
- Large images are rejected (> 50MB) to prevent OOM

---

## Supported Model Formats

| Format | Input Type | Layout | Support |
|--------|------------|--------|---------|
| Float32 | `float32` | NCHW | ✅ Full |
| Float32 | `float32` | NHWC | ✅ Full |
| Quantized | `uint8` | NCHW | ✅ Full |
| Quantized | `uint8` | NHWC | ✅ Full |
| Quantized | `int8` | NCHW | ✅ Full |
| Quantized | `int8` | NHWC | ✅ Full |

---

## File Structure

```
lib/
└── services/
    └── ml_service.dart    # Main service file

assets/
└── models/
    ├── fasternet_m.in1k_seefood.tflite  # Default model
    └── seefood_labels.txt               # Default labels
```

---

## Dependencies

```yaml
dependencies:
  tflite_flutter: ^0.10.0    # TensorFlow Lite runtime
  image: ^4.0.0              # Image processing
  shared_preferences: ^2.0.0 # Persistence
  path_provider: ^2.0.0      # File system paths
```

---

## Changelog

### Version 2.0 (Current)
- ✅ Automatic model configuration detection
- ✅ NCHW/NHWC layout auto-detection
- ✅ Float32 and Int8 quantization support
- ✅ Modular architecture
- ✅ Top 2 predictions only
- ✅ Comprehensive error handling
- ✅ Model warm-up support
- ✅ Batch processing
- ✅ Performance metrics

---

*Generated for Perceptron Flutter App - November 2025*
