import 'dart:io';
import 'dart:math' as math;
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
<<<<<<< HEAD
  List<String> _classNames = [];
  
=======

>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
  static const String _modelPathKey = 'selected_model_path';
  static const String _modelNameKey = 'selected_model_name';
  static const String _defaultModelPath = 'assets/models/fasternet_m.in1k_seefood.tflite';
  static const String _defaultLabelsPath = 'assets/models/seefood_labels.txt';

  bool get isModelLoaded => _interpreter != null;
  String? get currentModelName => _currentModelName;
  List<String> get classNames => _classNames;

  Future<void> initialize() async {
    await _loadLabels();
    await _loadSavedModel();
  }

  Future<void> _loadLabels() async {
    try {
      // Try to load labels from assets first
      final labelsString = await rootBundle.loadString(_defaultLabelsPath);
      _classNames = labelsString.trim().split('\n').map((line) => line.trim()).toList();
      print('Loaded ${_classNames.length} labels: $_classNames');
    } catch (e) {
      print('Failed to load labels from assets: $e');
      // Fallback to default labels
      _classNames = ['human', 'no-human'];
      print('Using default labels: $_classNames');
    }
  }

  Future<void> _loadLabelsFromFile(String labelsPath) async {
    try {
      final labelsFile = File(labelsPath);
      if (await labelsFile.exists()) {
        final labelsString = await labelsFile.readAsString();
        _classNames = labelsString.trim().split('\n').map((line) => line.trim()).toList();
        print('Loaded ${_classNames.length} labels from file: $_classNames');
      } else {
        print('Labels file not found at: $labelsPath');
        // Keep existing labels or use defaults
        if (_classNames.isEmpty) {
          _classNames = ['human', 'no-human'];
          print('Using default labels: $_classNames');
        }
      }
    } catch (e) {
      print('Failed to load labels from file: $e');
      // Keep existing labels or use defaults
      if (_classNames.isEmpty) {
        _classNames = ['human', 'no-human'];
        print('Using default labels: $_classNames');
      }
    }
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

  Future<bool> loadModelFromFile(String filePath, String fileName, {String? labelsPath}) async {
    try {
      // Load labels if provided
      if (labelsPath != null) {
        await _loadLabelsFromFile(labelsPath);
      }
      
      await _loadModelFromPath(filePath, fileName);
      await _saveModelPreference(filePath, fileName);
      return true;
    } catch (e) {
      print('Failed to load model: $e');
      return false;
    }
  }

  /// Load model and labels from a directory containing both model and labels.txt
  Future<bool> loadModelFromDirectory(String directoryPath, String modelFileName) async {
    try {
      final modelPath = '$directoryPath/$modelFileName';
      final labelsPath = '$directoryPath/labels.txt';
      
      // Load labels first
      await _loadLabelsFromFile(labelsPath);
      
      // Then load model
      return await loadModelFromFile(modelPath, modelFileName);
    } catch (e) {
      print('Failed to load model from directory: $e');
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
<<<<<<< HEAD
      print('Model loaded - Input shape: $_inputShape, Output shape: $_outputShape');
      print('Available classes: $_classNames');
=======
      print(
        'Model loaded - Input shape: $_inputShape, Output shape: $_outputShape\n\n\n\n',
      );
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
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

    if (_classNames.isEmpty) {
      throw Exception('No class labels loaded');
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

<<<<<<< HEAD
      // Convert to input tensor (quantized)
      final inputBuffer = _imageToInputBuffer(image, inputSize);
      
      // Prepare output buffer (raw bytes for quantized output)
      final outputSize = _outputShape?[1] ?? _classNames.length;
      final outputBytes = Uint8List(outputSize);

      // Run inference
      _interpreter!.run(inputBuffer, outputBytes);

      // Interpret output as Int8List
      final quantizedOutput = Int8List.view(outputBytes.buffer);

      // Dequantize
      const double outputScale = 0.00390625;
      const int outputZeroPoint = -128;
      List<double> dequantized = [];
      for (int i = 0; i < quantizedOutput.length; i++) {
        dequantized.add(outputScale * (quantizedOutput[i] - outputZeroPoint));
      }

      // Apply softmax to get probabilities
      double maxLogit = dequantized.reduce((a, b) => a > b ? a : b);
      List<double> expScores = dequantized.map((score) => math.exp(score - maxLogit)).toList();
      double sumExp = expScores.reduce((a, b) => a + b);
      List<double> probabilities = expScores.map((e) => e / sumExp).toList();

      // Process results
      return _processResults(probabilities);
      
=======
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
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
    } catch (e) {
      print('Inference failed: $e');
      print('Stack trace: ${StackTrace.current}');
      throw Exception('Inference failed: $e');
    }
  }

<<<<<<< HEAD
  Uint8List _imageToInputBuffer(img.Image image, int inputSize) {
    final convertedBytes = Int8List(inputSize * inputSize * 3);
    final buffer = Int8List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    const double inputScale = 0.003921568859368563;
    const int inputZeroPoint = -128;

    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        final pixel = image.getPixel(j, i);
        // Normalize to [0, 1]
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        // Quantize (matching Python's formula and truncation)
        int qr = ((r / inputScale) + inputZeroPoint).toInt().clamp(-128, 127);
        int qg = ((g / inputScale) + inputZeroPoint).toInt().clamp(-128, 127);
        int qb = ((b / inputScale) + inputZeroPoint).toInt().clamp(-128, 127);
        buffer[pixelIndex++] = qr;
        buffer[pixelIndex++] = qg;
        buffer[pixelIndex++] = qb;
      }
    }

    return convertedBytes.buffer.asUint8List();
  }

  List<Map<String, dynamic>> _processResults(List<double> probabilities) {
    // Create list of predictions with indices
    final allPredictions = <Map<String, dynamic>>[];
    print('Probabilities: $probabilities');
    
    // Find the highest confidence class
    double maxConfidence = probabilities.reduce((a, b) => a > b ? a : b);
    int predictedClassIndex = probabilities.indexOf(maxConfidence);
    
    print('Max confidence value: $maxConfidence');
    print('Predicted class index: $predictedClassIndex');
    print('All values: ${probabilities.asMap().entries.map((e) => 'Index ${e.key}: ${e.value}').join(', ')}');
    
    // Create all predictions
    for (int i = 0; i < probabilities.length && i < _classNames.length; i++) {
      allPredictions.add({
        'index': i,
        'confidence': probabilities[i],
        'label': _classNames[i],
        'isPredicted': i == predictedClassIndex,
      });
    }

    // Sort by confidence (highest to lowest) and take top predictions
    allPredictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
    final topPredictions = allPredictions.take(math.min(2, allPredictions.length)).toList();
    
    if (topPredictions.isNotEmpty) {
      print('Final prediction: ${topPredictions[0]['label']} with ${(topPredictions[0]['confidence'] * 100).toStringAsFixed(2)}% confidence');
    }
    
    return topPredictions;
  }

  Future<String> copyModelToAppDirectory(String sourcePath, String fileName) async {
=======
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
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final targetPath = '${modelsDir.path}/$fileName';
    await File(sourcePath).copy(targetPath);

    return targetPath;
  }

  /// Copy both model and labels files to app directory
  Future<String> copyModelAndLabelsToAppDirectory(String modelSourcePath, String labelsSourcePath, String modelFileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    // Copy model file
    final targetModelPath = '${modelsDir.path}/$modelFileName';
    await File(modelSourcePath).copy(targetModelPath);
    
    // Copy labels file
    final targetLabelsPath = '${modelsDir.path}/labels.txt';
    await File(labelsSourcePath).copy(targetLabelsPath);
    
    return targetModelPath;
  }

  void dispose() {
    _interpreter?.close();
  }
}
