import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final List<dynamic> predictions;

  const ResultCard({super.key, required this.predictions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Predictions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: ListView.separated(
                itemCount: predictions.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final prediction = predictions[index];
                  final confidence = (prediction['confidence'] as double) * 100;

                  // Handle NaN and invalid confidence values
                  final isValidConfidence = confidence.isFinite;
                  final displayConfidence =
                      isValidConfidence ? confidence : 0.0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          index == 0
                              ? Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.5,
                                ),
                                width: 1.5,
                              )
                              : null,
                    ),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                index == 0
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(
                                      0.3,
                                    ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    index == 0
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Label and confidence
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction['label'] as String,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight:
                                      index == 0
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Show error message for invalid predictions
                              if (!isValidConfidence)
                                Text(
                                  'Invalid prediction',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                // Confidence bar
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (displayConfidence / 100)
                                              .clamp(0.0, 1.0),
                                          backgroundColor: theme
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.2),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                index == 0
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme
                                                        .secondary,
                                              ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${displayConfidence.toStringAsFixed(1)}%',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
