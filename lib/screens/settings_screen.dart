import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ml_service.dart';

class SettingsScreen extends StatefulWidget {
  final MLService mlService;
  final VoidCallback onModelChanged;

  const SettingsScreen({
    super.key,
    required this.mlService,
    required this.onModelChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _selectModelFile() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final filePath = file.path!;
        final fileName = file.name;

        // Copy model to app directory
        final appModelPath = await widget.mlService.copyModelToAppDirectory(
          filePath,
          fileName,
        );

        // Load the model
        final success = await widget.mlService.loadModelFromFile(
          appModelPath,
          fileName,
        );

        if (success && mounted) {
          widget.onModelChanged();
          _showSuccessSnackBar('Model loaded successfully!');
          setState(() {}); // Refresh UI
        } else if (mounted) {
          _showErrorSnackBar('Failed to load the model');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectModelWithLabels() async {
    try {
      setState(() => _isLoading = true);

      // First pick the model
      final modelResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['tflite'],
        allowMultiple: false,
        dialogTitle: 'Select TFLite Model',
      );

      if (modelResult == null || modelResult.files.single.path == null) {
        setState(() => _isLoading = false);
        return;
      }

      final modelFile = modelResult.files.single;
      final modelPath = modelFile.path!;
      final modelName = modelFile.name;

      // Ask if user wants to add labels
      if (!mounted) return;
      
      final addLabels = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Labels File?'),
          content: const Text(
            'Would you like to select a labels.txt file for this model?\n\n'
            'Labels help identify what each class means.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add Labels'),
            ),
          ],
        ),
      );

      String? labelsPath;
      if (addLabels == true) {
        final labelsResult = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['txt'],
          allowMultiple: false,
          dialogTitle: 'Select Labels File',
        );

        if (labelsResult != null && labelsResult.files.single.path != null) {
          labelsPath = labelsResult.files.single.path;
        }
      }

      // Copy and load
      final appModelPath = await widget.mlService.copyModelToAppDirectory(
        modelPath,
        modelName,
      );

      final success = await widget.mlService.loadModelFromFile(
        appModelPath,
        modelName,
        labelsPath: labelsPath,
      );

      if (success && mounted) {
        widget.onModelChanged();
        _showSuccessSnackBar('Model loaded successfully!');
        setState(() {});
      } else if (mounted) {
        _showErrorSnackBar('Failed to load the model');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelInfo = widget.mlService.getModelInfo();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Model Status Card
                _buildModelStatusCard(theme, modelInfo),
                
                const SizedBox(height: 24),
                
                // Model Details Card
                if (widget.mlService.isModelLoaded) ...[
                  _buildModelDetailsCard(theme, modelInfo),
                  const SizedBox(height: 24),
                ],
                
                // Actions Section
                _buildActionsSection(theme),
                
                const SizedBox(height: 24),
                
                // Info Card
                _buildInfoCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelStatusCard(ThemeData theme, Map<String, dynamic> modelInfo) {
    final isLoaded = modelInfo['is_loaded'] as bool;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.95, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isLoaded
                ? [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                  ]
                : [
                    theme.colorScheme.errorContainer,
                    theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isLoaded
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error)
                  .withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Animated Icon
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isLoaded
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isLoaded
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error)
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isLoaded
                            ? Icons.psychology_rounded
                            : Icons.psychology_outlined,
                        color: isLoaded
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onError,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoaded ? 'Model Active' : 'No Model Loaded',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isLoaded
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      modelInfo['model_name'] ?? 'Select a model to get started',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: (isLoaded
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onErrorContainer)
                            .withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isLoaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ready',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelDetailsCard(ThemeData theme, Map<String, dynamic> modelInfo) {
    final config = widget.mlService.modelConfig;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Model Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(
                  theme,
                  Icons.aspect_ratio_rounded,
                  'Input Shape',
                  '${config?.inputShape ?? 'Unknown'}',
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  theme,
                  Icons.output_rounded,
                  'Output Shape',
                  '${config?.outputShape ?? 'Unknown'}',
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  theme,
                  Icons.layers_rounded,
                  'Layout',
                  config?.layout.name.toUpperCase() ?? 'Unknown',
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  theme,
                  Icons.photo_size_select_large_rounded,
                  'Image Size',
                  modelInfo['input_size'] ?? 'Unknown',
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  theme,
                  Icons.category_rounded,
                  'Classes',
                  '${modelInfo['class_count'] ?? 0}',
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  theme,
                  Icons.memory_rounded,
                  'Input Type',
                  config?.inputType.name ?? 'Unknown',
                ),
              ],
            ),
          ),
          // Class Labels Preview
          if (widget.mlService.classNames.isNotEmpty) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.label_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Class Labels Preview',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.mlService.classNames
                        .take(8)
                        .map((label) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  if (widget.mlService.classNames.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+${widget.mlService.classNames.length - 8} more',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Load Model Button
        _buildActionButton(
          theme: theme,
          icon: Icons.upload_file_rounded,
          title: 'Load Model',
          subtitle: 'Select a .tflite file from storage',
          onTap: _isLoading ? null : _selectModelFile,
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        // Load Model with Labels Button
        _buildActionButton(
          theme: theme,
          icon: Icons.folder_open_rounded,
          title: 'Load Model with Labels',
          subtitle: 'Select model and labels.txt file',
          onTap: _isLoading ? null : _selectModelWithLabels,
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPrimary
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary
                ? null
                : Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.2)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoading && isPrimary
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isPrimary
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        icon,
                        color: isPrimary
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPrimary
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isPrimary
                            ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isPrimary
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tips',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(theme, '• Only .tflite model files are supported'),
          _buildTipItem(theme, '• Models are saved and persist across app restarts'),
          _buildTipItem(theme, '• Supports both float32 and int8 quantized models'),
          _buildTipItem(theme, '• Labels file should have one class per line'),
          _buildTipItem(theme, '• NCHW and NHWC layouts are auto-detected'),
        ],
      ),
    );
  }

  Widget _buildTipItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }
}
