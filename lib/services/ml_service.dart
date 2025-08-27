import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
  List<String> _classNames = [];
  
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
      print('Model loaded - Input shape: $_inputShape, Output shape: $_outputShape');
      print('Available classes: $_classNames');
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
      
    } catch (e) {
      throw Exception('Inference failed: $e');
    }
  }

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