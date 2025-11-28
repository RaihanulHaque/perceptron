import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

// ============================================================================
// EXCEPTIONS
// ============================================================================

/// Custom exception class for ML service errors
class MLServiceException implements Exception {
  final String message;
  final String code;
  final dynamic originalError;

  MLServiceException(this.message, this.code, [this.originalError]);

  @override
  String toString() => 'MLServiceException($code): $message';
}

// ============================================================================
// MODEL CONFIGURATION
// ============================================================================

/// Enum to represent tensor data layout
enum TensorLayout {
  nchw, // [batch, channels, height, width] - PyTorch style
  nhwc, // [batch, height, width, channels] - TensorFlow style
}

/// Configuration extracted from the loaded model
class ModelConfig {
  final List<int> inputShape;
  final List<int> outputShape;
  final TensorType inputType;
  final TensorType outputType;
  final TensorLayout layout;
  final int batchSize;
  final int channels;
  final int height;
  final int width;
  final int numClasses;

  ModelConfig({
    required this.inputShape,
    required this.outputShape,
    required this.inputType,
    required this.outputType,
    required this.layout,
    required this.batchSize,
    required this.channels,
    required this.height,
    required this.width,
    required this.numClasses,
  });

  /// Parse model configuration from interpreter tensors
  factory ModelConfig.fromInterpreter(Interpreter interpreter) {
    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final outputShape = outputTensor.shape;

    // Determine layout and extract dimensions
    // NCHW: [1, 3, H, W] - channels before spatial dims
    // NHWC: [1, H, W, 3] - channels after spatial dims
    late TensorLayout layout;
    late int batchSize, channels, height, width;

    if (inputShape.length == 4) {
      batchSize = inputShape[0];
      
      // Heuristic: if dim[1] is small (1-4) and dim[2,3] are larger, it's NCHW
      // If dim[3] is small (1-4) and dim[1,2] are larger, it's NHWC
      if (inputShape[1] <= 4 && inputShape[2] > 4 && inputShape[3] > 4) {
        layout = TensorLayout.nchw;
        channels = inputShape[1];
        height = inputShape[2];
        width = inputShape[3];
      } else if (inputShape[3] <= 4 && inputShape[1] > 4 && inputShape[2] > 4) {
        layout = TensorLayout.nhwc;
        height = inputShape[1];
        width = inputShape[2];
        channels = inputShape[3];
      } else {
        // Default assumption: NCHW for PyTorch models
        layout = TensorLayout.nchw;
        channels = inputShape[1];
        height = inputShape[2];
        width = inputShape[3];
      }
    } else {
      throw MLServiceException(
        'Unsupported input shape: $inputShape (expected 4D tensor)',
        'INVALID_INPUT_SHAPE',
      );
    }

    // Extract number of classes from output shape
    int numClasses;
    if (outputShape.length == 2) {
      numClasses = outputShape[1];
    } else if (outputShape.length == 1) {
      numClasses = outputShape[0];
    } else {
      numClasses = outputShape.last;
    }

    return ModelConfig(
      inputShape: inputShape,
      outputShape: outputShape,
      inputType: inputTensor.type,
      outputType: outputTensor.type,
      layout: layout,
      batchSize: batchSize,
      channels: channels,
      height: height,
      width: width,
      numClasses: numClasses,
    );
  }

  @override
  String toString() => '''
ModelConfig:
  Input Shape: $inputShape (${layout.name.toUpperCase()})
  Output Shape: $outputShape
  Input Type: $inputType
  Output Type: $outputType
  Image Size: ${width}x$height
  Channels: $channels
  Classes: $numClasses
''';
}

// ============================================================================
// INFERENCE METRICS
// ============================================================================

/// Performance monitoring class
class InferenceMetrics {
  final DateTime startTime;
  final DateTime endTime;
  final String modelName;
  final String imagePath;
  final bool success;

  InferenceMetrics({
    required this.startTime,
    required this.endTime,
    required this.modelName,
    required this.imagePath,
    required this.success,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
        'duration_ms': duration.inMilliseconds,
        'model_name': modelName,
        'image_path': imagePath,
        'success': success,
        'timestamp': startTime.toIso8601String(),
      };
}

// ============================================================================
// ML SERVICE
// ============================================================================

class MLService {
  Interpreter? _interpreter;
  ModelConfig? _modelConfig;
  String? _currentModelPath;
  String? _currentModelName;
  List<String> _classNames = [];
  bool _isWarmedUp = false;

  // Preference keys
  static const String _modelPathKey = 'selected_model_path';
  static const String _modelNameKey = 'selected_model_name';
  static const String _labelsPathKey = 'selected_labels_path';

  // Default paths
  static const String _defaultModelPath = 'assets/models/fasternet_m.in1k_seefood.tflite';
  static const String _defaultLabelsPath = 'assets/models/seefood_labels.txt';

  // ============================================================================
  // GETTERS
  // ============================================================================

  bool get isModelLoaded => _interpreter != null && _modelConfig != null;
  String? get currentModelName => _currentModelName;
  List<String> get classNames => List.unmodifiable(_classNames);
  bool get isWarmedUp => _isWarmedUp;
  ModelConfig? get modelConfig => _modelConfig;

  /// Get input image size required by the model
  int get inputHeight => _modelConfig?.height ?? 224;
  int get inputWidth => _modelConfig?.width ?? 224;
  TensorLayout get tensorLayout => _modelConfig?.layout ?? TensorLayout.nchw;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize the ML service with model loading
  Future<void> initialize() async {
    await _loadSavedModelOrDefault();
  }

  /// Initialize with model warm-up for better performance
  Future<void> initializeWithWarmup() async {
    await initialize();
    await warmUpModel();
  }

  /// Load previously saved model or fall back to default
  Future<void> _loadSavedModelOrDefault() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModelPath = prefs.getString(_modelPathKey);
    final savedModelName = prefs.getString(_modelNameKey);
    final savedLabelsPath = prefs.getString(_labelsPathKey);

    if (savedModelPath != null && savedModelName != null) {
      try {
        await _loadModel(savedModelPath, savedModelName, savedLabelsPath);
        return;
      } catch (e) {
        debugPrint('Failed to load saved model, falling back to default: $e');
      }
    }

    await _loadDefaultModel();
  }

  /// Load the default model from assets
  Future<void> _loadDefaultModel() async {
    await _loadModel(_defaultModelPath, 'Default Model', _defaultLabelsPath);
  }

  // ============================================================================
  // MODEL LOADING
  // ============================================================================

  /// Load a model from file path with optional labels
  Future<bool> loadModelFromFile(
    String filePath,
    String fileName, {
    String? labelsPath,
  }) async {
    try {
      await _loadModel(filePath, fileName, labelsPath);
      await _saveModelPreference(filePath, fileName, labelsPath);
      return true;
    } catch (e) {
      debugPrint('Failed to load model: $e');
      return false;
    }
  }

  /// Load a model from a directory containing model and labels.txt
  Future<bool> loadModelFromDirectory(
    String directoryPath,
    String modelFileName,
  ) async {
    final modelPath = '$directoryPath/$modelFileName';
    final labelsPath = '$directoryPath/labels.txt';
    return loadModelFromFile(modelPath, modelFileName, labelsPath: labelsPath);
  }

  /// Internal method to load model and labels
  Future<void> _loadModel(
    String modelPath,
    String modelName,
    String? labelsPath,
  ) async {
    // Close existing interpreter
    _interpreter?.close();
    _interpreter = null;
    _modelConfig = null;
    _isWarmedUp = false;

    // Load the model
    if (modelPath.startsWith('assets/')) {
      _interpreter = await Interpreter.fromAsset(modelPath);
    } else {
      final file = File(modelPath);
      if (!await file.exists()) {
        throw MLServiceException('Model file not found: $modelPath', 'MODEL_NOT_FOUND');
      }
      _interpreter = await Interpreter.fromFile(file);
    }

    // Extract model configuration
    _modelConfig = ModelConfig.fromInterpreter(_interpreter!);
    _currentModelPath = modelPath;
    _currentModelName = modelName;

    debugPrint('Loaded model: $modelName');
    debugPrint(_modelConfig.toString());

    // Load labels
    await _loadLabels(labelsPath);

    // Validate labels match output
    if (_classNames.length != _modelConfig!.numClasses) {
      debugPrint(
        'Warning: Label count (${_classNames.length}) does not match '
        'model output classes (${_modelConfig!.numClasses})',
      );
    }
  }

  /// Load labels from file or assets
  Future<void> _loadLabels(String? labelsPath) async {
    _classNames.clear();

    // Try provided path first
    if (labelsPath != null) {
      try {
        if (labelsPath.startsWith('assets/')) {
          final content = await rootBundle.loadString(labelsPath);
          _classNames = _parseLabels(content);
        } else {
          final file = File(labelsPath);
          if (await file.exists()) {
            final content = await file.readAsString();
            _classNames = _parseLabels(content);
          }
        }
      } catch (e) {
        debugPrint('Failed to load labels from $labelsPath: $e');
      }
    }

    // Fall back to default labels if none loaded
    if (_classNames.isEmpty) {
      try {
        final content = await rootBundle.loadString(_defaultLabelsPath);
        _classNames = _parseLabels(content);
      } catch (e) {
        debugPrint('Failed to load default labels: $e');
      }
    }

    // Generate placeholder labels if still empty
    if (_classNames.isEmpty && _modelConfig != null) {
      _classNames = List.generate(
        _modelConfig!.numClasses,
        (i) => 'Class $i',
      );
      debugPrint('Using placeholder labels: $_classNames');
    }

    debugPrint('Loaded ${_classNames.length} labels: $_classNames');
  }

  /// Parse labels from text content
  List<String> _parseLabels(String content) {
    return content
        .trim()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Save model preferences
  Future<void> _saveModelPreference(
    String modelPath,
    String modelName,
    String? labelsPath,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPathKey, modelPath);
    await prefs.setString(_modelNameKey, modelName);
    if (labelsPath != null) {
      await prefs.setString(_labelsPathKey, labelsPath);
    } else {
      await prefs.remove(_labelsPathKey);
    }
  }

  // ============================================================================
  // MODEL WARM-UP
  // ============================================================================

  /// Warm up the model with a dummy inference for better performance
  Future<void> warmUpModel() async {
    if (!isModelLoaded || _isWarmedUp) return;

    try {
      final config = _modelConfig!;
      final input = _createDummyInput(config);
      final output = _createOutputBuffer(config);

      _interpreter!.run(input, output);
      _isWarmedUp = true;
      debugPrint('Model warmed up successfully');
    } catch (e) {
      debugPrint('Model warm-up failed: $e');
    }
  }

  /// Create a dummy input tensor for warm-up
  dynamic _createDummyInput(ModelConfig config) {
    final isInt8 = config.inputType == TensorType.uint8 || config.inputType == TensorType.int8;
    final fillValue = isInt8 ? 0 : 0.0;
    
    if (config.layout == TensorLayout.nchw) {
      return List.generate(
        config.batchSize,
        (_) => List.generate(
          config.channels,
          (_) => List.generate(
            config.height,
            (_) => List.filled(config.width, fillValue),
          ),
        ),
      );
    } else {
      return List.generate(
        config.batchSize,
        (_) => List.generate(
          config.height,
          (_) => List.generate(
            config.width,
            (_) => List.filled(config.channels, fillValue),
          ),
        ),
      );
    }
  }

  /// Create output buffer based on model configuration
  dynamic _createOutputBuffer(ModelConfig config) {
    final isInt8 = config.outputType == TensorType.uint8 || config.outputType == TensorType.int8;
    final fillValue = isInt8 ? 0 : 0.0;
    
    if (config.outputShape.length == 2) {
      return List.generate(
        config.outputShape[0],
        (_) => List.filled(config.outputShape[1], fillValue),
      );
    } else if (config.outputShape.length == 1) {
      return List.filled(config.outputShape[0], fillValue);
    } else {
      // For other shapes, create nested lists
      return _createNestedList(config.outputShape, fillValue);
    }
  }

  /// Recursively create nested list for arbitrary shape
  dynamic _createNestedList(List<int> shape, dynamic fillValue) {
    if (shape.length == 1) {
      return List.filled(shape[0], fillValue);
    }
    return List.generate(
      shape[0],
      (_) => _createNestedList(shape.sublist(1), fillValue),
    );
  }

  // ============================================================================
  // IMAGE PREPROCESSING
  // ============================================================================

  /// Validate and load image from file
  Future<img.Image> _loadAndValidateImage(File imageFile) async {
    if (!await imageFile.exists()) {
      throw MLServiceException('Image file not found', 'FILE_NOT_FOUND');
    }

    final fileSizeBytes = await imageFile.length();
    const maxSizeMB = 50;
    if (fileSizeBytes > maxSizeMB * 1024 * 1024) {
      throw MLServiceException(
        'Image file too large: ${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB (max: ${maxSizeMB}MB)',
        'FILE_TOO_LARGE',
      );
    }

    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw MLServiceException('Failed to decode image', 'DECODE_ERROR');
    }

    if (image.width < 32 || image.height < 32) {
      throw MLServiceException(
        'Image too small: ${image.width}x${image.height} (minimum: 32x32)',
        'IMAGE_TOO_SMALL',
      );
    }

    return image;
  }

  /// Convert image to input tensor based on model configuration
  dynamic _imageToInputTensor(img.Image image, ModelConfig config) {
    // Resize image to model's expected size
    final resized = img.copyResize(
      image,
      width: config.width,
      height: config.height,
      interpolation: img.Interpolation.linear,
    );

    final isInt8 = config.inputType == TensorType.uint8 || config.inputType == TensorType.int8;
    
    if (config.layout == TensorLayout.nchw) {
      return isInt8 ? _imageToNCHWInt8(resized, config) : _imageToNCHWFloat(resized, config);
    } else {
      return isInt8 ? _imageToNHWCInt8(resized, config) : _imageToNHWCFloat(resized, config);
    }
  }

  /// Convert image to NCHW format with float values [0.0, 1.0]
  List<List<List<List<double>>>> _imageToNCHWFloat(img.Image image, ModelConfig config) {
    return List.generate(
      config.batchSize,
      (_) => List.generate(
        config.channels,
        (c) => List.generate(
          config.height,
          (y) => List.generate(
            config.width,
            (x) {
              final pixel = image.getPixel(x, y);
              switch (c) {
                case 0:
                  return pixel.r / 255.0;
                case 1:
                  return pixel.g / 255.0;
                case 2:
                  return pixel.b / 255.0;
                default:
                  return 0.0;
              }
            },
          ),
        ),
      ),
    );
  }

  /// Convert image to NCHW format with int8 values [0, 255]
  List<List<List<List<int>>>> _imageToNCHWInt8(img.Image image, ModelConfig config) {
    return List.generate(
      config.batchSize,
      (_) => List.generate(
        config.channels,
        (c) => List.generate(
          config.height,
          (y) => List.generate(
            config.width,
            (x) {
              final pixel = image.getPixel(x, y);
              switch (c) {
                case 0:
                  return pixel.r.toInt();
                case 1:
                  return pixel.g.toInt();
                case 2:
                  return pixel.b.toInt();
                default:
                  return 0;
              }
            },
          ),
        ),
      ),
    );
  }

  /// Convert image to NHWC format with float values [0.0, 1.0]
  List<List<List<List<double>>>> _imageToNHWCFloat(img.Image image, ModelConfig config) {
    return List.generate(
      config.batchSize,
      (_) => List.generate(
        config.height,
        (y) => List.generate(
          config.width,
          (x) {
            final pixel = image.getPixel(x, y);
            return List.generate(config.channels, (c) {
              switch (c) {
                case 0:
                  return pixel.r / 255.0;
                case 1:
                  return pixel.g / 255.0;
                case 2:
                  return pixel.b / 255.0;
                default:
                  return 0.0;
              }
            });
          },
        ),
      ),
    );
  }

  /// Convert image to NHWC format with int8 values [0, 255]
  List<List<List<List<int>>>> _imageToNHWCInt8(img.Image image, ModelConfig config) {
    return List.generate(
      config.batchSize,
      (_) => List.generate(
        config.height,
        (y) => List.generate(
          config.width,
          (x) {
            final pixel = image.getPixel(x, y);
            return List.generate(config.channels, (c) {
              switch (c) {
                case 0:
                  return pixel.r.toInt();
                case 1:
                  return pixel.g.toInt();
                case 2:
                  return pixel.b.toInt();
                default:
                  return 0;
              }
            });
          },
        ),
      ),
    );
  }

  // ============================================================================
  // INFERENCE
  // ============================================================================

  /// Run inference on an image file
  Future<List<Map<String, dynamic>>> runInference(File imageFile) async {
    if (!isModelLoaded) {
      throw MLServiceException('Model not loaded', 'MODEL_NOT_LOADED');
    }

    final config = _modelConfig!;

    // Load and preprocess image
    final image = await _loadAndValidateImage(imageFile);
    final inputTensor = _imageToInputTensor(image, config);

    // Create output buffer
    final outputBuffer = _createOutputBuffer(config);

    // Run inference
    try {
      _interpreter!.run(inputTensor, outputBuffer);
    } catch (e) {
      throw MLServiceException(
        'TensorFlow Lite inference failed: $e',
        'INFERENCE_ERROR',
        e,
      );
    }

    // Process results
    final logits = _extractLogits(outputBuffer, config);
    final probabilities = _softmax(logits);
    return _processResults(probabilities);
  }

  /// Extract logits from output buffer (handles various shapes and types)
  List<double> _extractLogits(dynamic output, ModelConfig config) {
    final isInt8 = config.outputType == TensorType.uint8 || config.outputType == TensorType.int8;
    
    List<dynamic> rawValues;
    
    if (output is List && output.isNotEmpty) {
      final first = output[0];
      if (first is List) {
        rawValues = first;
      } else {
        rawValues = output;
      }
    } else {
      throw MLServiceException('Unexpected output format', 'OUTPUT_FORMAT_ERROR');
    }
    
    // Convert to doubles, handling int8 quantized output
    if (isInt8) {
      // For int8 output, dequantize: value / 255.0 (simple scaling)
      return rawValues.map((v) => (v as num).toDouble() / 255.0).toList();
    } else {
      return rawValues.map((v) => (v as num).toDouble()).toList();
    }
  }

  /// Apply softmax to convert logits to probabilities
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final expScores = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expScores.reduce((a, b) => a + b);
    return expScores.map((x) => x / sumExp).toList();
  }

  /// Process probabilities into prediction results
  List<Map<String, dynamic>> _processResults(List<double> probabilities) {
    final predictions = <Map<String, dynamic>>[];

    for (int i = 0; i < probabilities.length; i++) {
      final label = i < _classNames.length ? _classNames[i] : 'Class $i';
      predictions.add({
        'index': i,
        'label': label,
        'confidence': probabilities[i],
      });
    }

    // Sort by confidence descending
    predictions.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));

    // Mark top prediction
    if (predictions.isNotEmpty) {
      predictions[0]['isPredicted'] = true;
      debugPrint(
        'Prediction: ${predictions[0]['label']} '
        '(${(predictions[0]['confidence'] * 100).toStringAsFixed(2)}%)',
      );
    }

    // Return top 2 results only
    return predictions.take(math.min(2, predictions.length)).toList();
  }

  // ============================================================================
  // CONVENIENCE METHODS
  // ============================================================================

  /// Run inference with performance metrics
  Future<Map<String, dynamic>> runInferenceWithMetrics(File imageFile) async {
    final startTime = DateTime.now();
    bool success = false;
    List<Map<String, dynamic>> predictions = [];

    try {
      predictions = await runInference(imageFile);
      success = true;
    } finally {
      final endTime = DateTime.now();
      final metrics = InferenceMetrics(
        startTime: startTime,
        endTime: endTime,
        modelName: _currentModelName ?? 'Unknown',
        imagePath: imageFile.path,
        success: success,
      );
      debugPrint('Inference completed in ${metrics.duration.inMilliseconds}ms');
    }

    return {
      'predictions': predictions,
      'inference_time_ms': DateTime.now().difference(startTime).inMilliseconds,
    };
  }

  /// Process multiple images in batch
  Future<List<Map<String, dynamic>>> processBatchImages(List<File> imageFiles) async {
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final predictions = await runInference(imageFiles[i]);
        results.add({
          'index': i,
          'filename': imageFiles[i].path.split('/').last,
          'predictions': predictions,
          'success': true,
        });
      } catch (e) {
        results.add({
          'index': i,
          'filename': imageFiles[i].path.split('/').last,
          'error': e.toString(),
          'success': false,
        });
      }

      // Small delay to prevent overwhelming the system
      await Future.delayed(const Duration(milliseconds: 50));
    }

    return results;
  }

  /// Run inference in a separate isolate
  static Future<List<dynamic>> runInferenceInIsolate(String imagePath) async {
    return compute(_isolateInference, imagePath);
  }

  static Future<List<dynamic>> _isolateInference(String imagePath) async {
    final mlService = MLService();
    await mlService.initialize();
    return mlService.runInference(File(imagePath));
  }

  // ============================================================================
  // FILE MANAGEMENT
  // ============================================================================

  /// Copy model to app documents directory
  Future<String> copyModelToAppDirectory(String sourcePath, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final targetPath = '${modelsDir.path}/$fileName';
    await File(sourcePath).copy(targetPath);

    return targetPath;
  }

  /// Copy model and labels to app documents directory
  Future<Map<String, String>> copyModelAndLabelsToAppDirectory(
    String modelSourcePath,
    String labelsSourcePath,
    String modelFileName,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final targetModelPath = '${modelsDir.path}/$modelFileName';
    final targetLabelsPath = '${modelsDir.path}/labels.txt';

    await File(modelSourcePath).copy(targetModelPath);
    await File(labelsSourcePath).copy(targetLabelsPath);

    return {
      'modelPath': targetModelPath,
      'labelsPath': targetLabelsPath,
    };
  }

  // ============================================================================
  // STATUS & CLEANUP
  // ============================================================================

  /// Get comprehensive model information
  Map<String, dynamic> getModelInfo() {
    return {
      'is_loaded': isModelLoaded,
      'is_warmed_up': _isWarmedUp,
      'model_name': _currentModelName,
      'model_path': _currentModelPath,
      'input_shape': _modelConfig?.inputShape,
      'output_shape': _modelConfig?.outputShape,
      'layout': _modelConfig?.layout.name,
      'input_size': '${_modelConfig?.width}x${_modelConfig?.height}',
      'channels': _modelConfig?.channels,
      'class_count': _classNames.length,
      'class_names': _classNames,
    };
  }

  /// Reset model state
  void reset() {
    _interpreter?.close();
    _interpreter = null;
    _modelConfig = null;
    _currentModelPath = null;
    _currentModelName = null;
    _classNames.clear();
    _isWarmedUp = false;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
