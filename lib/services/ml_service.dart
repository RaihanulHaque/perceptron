import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class MLService {
  Interpreter? _interpreter;
  String? _currentModelPath;
  String? _currentModelName;
  List<int>? _inputShape;
  List<int>? _outputShape;

  static const String _modelPathKey = 'selected_model_path';
  static const String _modelNameKey = 'selected_model_name';
  static const String _defaultModelPath = 'assets/models/best_int8.tflite';

  bool get isModelLoaded => _interpreter != null;
  String? get currentModelName => _currentModelName;

  Future<void> initialize() async {
    await _loadSavedModel();
  }

  Future<void> _loadSavedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModelPath = prefs.getString(_modelPathKey);
    final savedModelName = prefs.getString(_modelNameKey);

    if (savedModelPath != null && savedModelName != null) {
      await _loadModelFromPath(savedModelPath, savedModelName);
    } else {
      // Try to load default model from assets
      await _loadDefaultModel();
    }
  }

  Future<void> _loadDefaultModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_defaultModelPath);
      _currentModelPath = _defaultModelPath;
      _currentModelName = 'Default Model';
      _extractModelDetails();
    } catch (e) {
      print('Default model not found or failed to load: $e');
      // This is okay - user can load a model manually
    }
  }

  Future<bool> loadModelFromFile(String filePath, String fileName) async {
    try {
      await _loadModelFromPath(filePath, fileName);
      await _saveModelPreference(filePath, fileName);
      return true;
    } catch (e) {
      print('Failed to load model: $e');
      return false;
    }
  }

  Future<void> _loadModelFromPath(String path, String name) async {
    _interpreter?.close();

    if (path.startsWith('assets/')) {
      _interpreter = await Interpreter.fromAsset(path);
    } else {
      _interpreter = await Interpreter.fromFile(File(path));
    }

    _currentModelPath = path;
    _currentModelName = name;
    _extractModelDetails();
  }

  void _extractModelDetails() {
    if (_interpreter == null) return;

    try {
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      print(
        'Model loaded - Input shape: $_inputShape, Output shape: $_outputShape\n\n\n\n',
      );
    } catch (e) {
      print('Failed to extract model details: $e');
    }
  }

  Future<void> _saveModelPreference(String path, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPathKey, path);
    await prefs.setString(_modelNameKey, name);
  }

  Future<List<dynamic>> runInference(File imageFile) async {
    if (_interpreter == null) {
      throw Exception('No model loaded');
    }

    try {
      // Read and decode image
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Always resize image to 224x224 for model input
      const inputSize = 224;
      image = img.copyResize(image, width: inputSize, height: inputSize);

      // Convert to input tensor with proper shape [1, 224, 224, 3]
      final input = _imageToByteListFloat32(image, inputSize);
      final inputTensor = input.buffer.asFloat32List().reshape([
        1,
        inputSize,
        inputSize,
        3,
      ]);

      // Prepare output - ensure proper shape [1, 2]
      final outputSize = _outputShape?[1] ?? 2;
      final outputTensor = List.filled(
        1 * outputSize,
        0.0,
      ).reshape([1, outputSize]);

      print('Input tensor shape: [1, $inputSize, $inputSize, 3]');
      print('Output tensor shape: [1, $outputSize]');

      // Run inference
      _interpreter!.run(inputTensor, outputTensor);

      // Extract results from the output tensor
      final results = (outputTensor[0] as List).cast<double>();

      print('Raw model output: $results');
      print('Output data type: ${results.runtimeType}');

      // Validate results before processing
      if (results.any((value) => !value.isFinite)) {
        print('Warning: Model returned invalid values (NaN or Infinity)');
        // Return safe fallback results
        return [
          {
            'index': 0,
            'confidence': 0.5,
            'label': 'Not Human',
            'isPredicted': true,
          },
          {
            'index': 1,
            'confidence': 0.5,
            'label': 'Human',
            'isPredicted': false,
          },
        ];
      }

      return _processResults(results);
    } catch (e) {
      print('Inference failed: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Inference failed: $e');
    }
  }

  Uint8List _imageToByteListFloat32(img.Image image, int inputSize) {
    final convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    final buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    print(
      'Image preprocessing - Original size: ${image.width}x${image.height}',
    );
    print('Target size: ${inputSize}x$inputSize');

    // EXACT MATCH with Python preprocessing: img_array = np.array(img) / 255.0
    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        final pixel = image.getPixel(j, i);

        // Normalize to [0, 1] exactly like Python: / 255.0
        final r = (pixel.r / 255.0).clamp(0.0, 1.0);
        final g = (pixel.g / 255.0).clamp(0.0, 1.0);
        final b = (pixel.b / 255.0).clamp(0.0, 1.0);

        buffer[pixelIndex++] = r.isFinite ? r : 0.0;
        buffer[pixelIndex++] = g.isFinite ? g : 0.0;
        buffer[pixelIndex++] = b.isFinite ? b : 0.0;
      }
    }

    // Log sample pixel values for debugging (should match Python normalization)
    print(
      'Sample normalized pixel values (should be [0,1]): R=${buffer[0].toStringAsFixed(3)}, G=${buffer[1].toStringAsFixed(3)}, B=${buffer[2].toStringAsFixed(3)}',
    );

    return convertedBytes.buffer.asUint8List();
  }

  Uint8List _imageToByteListInt8(img.Image image, int inputSize) {
    final convertedBytes = Int8List(1 * inputSize * inputSize * 3);
    final buffer = Int8List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    // Quantization parameters (replace with values from Python inspection)
    const inputScale =
        0.007874015748031496; // Example: replace with actual scale
    const inputZeroPoint = 0; // Example: replace with actual zero point

    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        final pixel = image.getPixel(j, i);
        // Normalize to [0, 1]
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;
        // Apply quantization: (value / scale) + zero_point
        buffer[pixelIndex++] = ((r / inputScale) + inputZeroPoint)
            .round()
            .clamp(-128, 127);
        buffer[pixelIndex++] = ((g / inputScale) + inputZeroPoint)
            .round()
            .clamp(-128, 127);
        buffer[pixelIndex++] = ((b / inputScale) + inputZeroPoint)
            .round()
            .clamp(-128, 127);
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  List<Map<String, dynamic>> _processResults(List<double> results) {
    // Create list of predictions with indices
    final predictions = <Map<String, dynamic>>[];
    print('Raw results: $results');
    print('Results length: ${results.length}');

    // EXACT MATCH with Python: Find max value and its index (like np.argmax)
    double maxValue = results.reduce((a, b) => a > b ? a : b);
    int maxIndex = results.indexOf(maxValue);

    print('Max value: $maxValue');
    print('Max index (predicted class): $maxIndex');

    // EXACT MATCH with Python class mapping: {0: 'human', 1: 'no-human'}
    final classNames = {0: 'Human', 1: 'No-Human'};

    print('Class mapping: $classNames');

    // Convert raw values to probabilities for display (optional, for UI purposes)
    List<double> probabilities;
    final sum = results.reduce((a, b) => a + b);
    if (sum > 0 && sum.isFinite) {
      probabilities = results.map((x) => x / sum).toList();
    } else {
      // Fallback: use softmax
      probabilities = _applySoftmax(results);
    }

    print('Probabilities for display: $probabilities');

    // Create predictions list exactly matching Python logic
    for (int i = 0; i < results.length; i++) {
      final className = classNames[i] ?? 'Unknown';
      predictions.add({
        'index': i,
        'confidence': probabilities[i], // Use probabilities for UI display
        'raw_value': results[i], // Keep raw value for reference
        'label': className,
        'isPredicted': i == maxIndex, // This matches Python's argmax logic
      });
    }

    // Sort by confidence (highest first) for UI display
    predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));

    // Log the final prediction exactly like Python
    final predictedClassName = classNames[maxIndex] ?? 'Unknown';
    print(
      'PYTHON MATCH - Predicted: $predictedClassName (index: $maxIndex), Raw value: $maxValue',
    );
    print('All predictions:');
    for (var pred in predictions) {
      print(
        '  Index ${pred['index']}: ${pred['label']} - Raw: ${pred['raw_value']}, Prob: ${(pred['confidence'] * 100).toStringAsFixed(2)}%',
      );
    }

    return predictions;
  }

  List<double> _applySoftmax(List<double> values) {
    // Find max value to prevent overflow
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    // Compute exponentials with numerical stability
    final exps = values.map((x) => math.exp(x - maxVal)).toList();
    final sumExps = exps.reduce((a, b) => a + b);

    // Handle edge case where sum is 0
    if (sumExps == 0.0 || !sumExps.isFinite) {
      // Return uniform distribution
      final uniform = 1.0 / values.length;
      return List.filled(values.length, uniform);
    }

    // Return normalized probabilities
    return exps.map((exp) => exp / sumExps).toList();
  }

  Future<String> copyModelToAppDirectory(
    String sourcePath,
    String fileName,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final targetPath = '${modelsDir.path}/$fileName';
    await File(sourcePath).copy(targetPath);

    return targetPath;
  }

  void dispose() {
    _interpreter?.close();
  }
}
