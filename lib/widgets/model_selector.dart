import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ml_service.dart';

class ModelSelector extends StatefulWidget {
  final MLService mlService;
  final Function(String?) onModelChanged;

  const ModelSelector({
    super.key,
    required this.mlService,
    required this.onModelChanged,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  bool _isLoading = false;

  Future<void> _selectModelFile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;
        final fileName = file.name;

        // Copy model to app directory for persistent access
        final appModelPath = await widget.mlService.copyModelToAppDirectory(
          filePath, 
          fileName,
        );

        // Load the model
        final success = await widget.mlService.loadModelFromFile(
          appModelPath,
          fileName,
        );

        if (success) {
          widget.onModelChanged(fileName);
          _showSuccess('Model loaded successfully');
          Navigator.pop(context);
        } else {
          _showError('Failed to load the selected model');
        }
      }
    } catch (e) {
      _showError('Error selecting model: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Text(
            'Model Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Current Model Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.mlService.isModelLoaded 
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                        color: widget.mlService.isModelLoaded 
                          ? Colors.green 
                          : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Current Model',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.mlService.currentModelName ?? 'No model loaded',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Load New Model Button
          FilledButton.icon(
            onPressed: _isLoading ? null : _selectModelFile,
            icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
            label: Text(_isLoading ? 'Loading...' : 'Load New Model'),
          ),
          
          const SizedBox(height: 16),
          
          // Info Card
          Card(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Model Requirements',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Only .tflite files are supported\n'
                    '• Model will be saved as default\n'
                    '• Ensure your model is compatible with image input',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}