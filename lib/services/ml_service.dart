import 'dart:io';
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
      print('Model loaded - Input shape: $_inputShape, Output shape: $_outputShape\n\n\n\n');
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

      // Convert to input tensor
      final input = _imageToByteListFloat32(image, inputSize);
      
      // Prepare output
      final outputSize = _outputShape?[1] ?? 1000; // 1000 means 1000 classes
      final output = List.filled(1 * outputSize, 0.0).reshape([1, outputSize]);

      // Run inference
      _interpreter!.run(input, output);

      // Process results
      final results = output[0] as List<double>;
      return _processResults(results);
      
    } catch (e) {
      throw Exception('Inference failed: $e');
    }
  }

  Uint8List _imageToByteListFloat32(img.Image image, int inputSize) {
  final convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  final buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;

  for (int i = 0; i < inputSize; i++) {
    for (int j = 0; j < inputSize; j++) {
      final pixel = image.getPixel(j, i);
      // Normalize to [0, 1] just like Python
      buffer[pixelIndex++] = pixel.r / 255.0;
      buffer[pixelIndex++] = pixel.g / 255.0;
      buffer[pixelIndex++] = pixel.b / 255.0;
    }
  }

  return convertedBytes.buffer.asUint8List();
}

  List<Map<String, dynamic>> _processResults(List<double> results) {
  // Create list of predictions with indices
  final predictions = <Map<String, dynamic>>[];
  print('Raw results: $results');
  
  // Find the highest confidence class
  double maxConfidence = results.reduce((a, b) => a > b ? a : b);
  int predictedClassIndex = results.indexOf(maxConfidence);
  
  print('Max confidence value: $maxConfidence');
  print('Predicted class index: $predictedClassIndex');
  print('All values: ${results.asMap().entries.map((e) => 'Index ${e.key}: ${e.value}').join(', ')}');
  
  // IMPORTANT: Fix the label mapping to match Python
  final labels = ['Not Human', 'Human']; // Now matches Python: 0='Not Human', 1='Human'
  
  for (int i = 0; i < results.length; i++) {
    predictions.add({
      'index': i,
      'confidence': results[i],
      'label': i < labels.length ? labels[i] : 'Unknown',
      'isPredicted': i == predictedClassIndex,
    });
  }

  // Sort by confidence (highest first)
  predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));
  
  print('Final prediction: ${predictions.first['label']} with ${(predictions.first['confidence'] * 100).toStringAsFixed(2)}% confidence');
  
  return predictions;
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

  void dispose() {
    _interpreter?.close();
  }
}