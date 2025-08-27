import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final List<dynamic> predictions;

  const ResultCard({super.key, required this.predictions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
<<<<<<< HEAD
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
=======

    return Card(
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Predictions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
<<<<<<< HEAD
            
            Column(
              children: predictions.asMap().entries.map((entry) {
                final index = entry.key;
                final prediction = entry.value;
                final confidence = (prediction['confidence'] as double) * 100;
                final isTopPrediction = index == 0;
                
                return Padding(
                  padding: EdgeInsets.only(bottom: index < predictions.length - 1 ? 12 : 0),
                  child: TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 600 + (index * 200)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            // Add margin for second prediction to make it appear smaller
                            margin: isTopPrediction 
                              ? EdgeInsets.zero 
                              : const EdgeInsets.symmetric(horizontal: 16),
                            padding: EdgeInsets.all(isTopPrediction ? 12 : 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isTopPrediction
                                  ? [
                                      theme.colorScheme.primary.withOpacity(0.15),
                                      theme.colorScheme.secondary.withOpacity(0.1),
                                    ]
                                  : [
                                      theme.colorScheme.surfaceVariant.withOpacity(0.2),
                                      theme.colorScheme.surfaceVariant.withOpacity(0.05),
                                    ],
=======

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
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
                              ),
                              borderRadius: BorderRadius.circular(isTopPrediction ? 12 : 10),
                              border: Border.all(
                                color: isTopPrediction 
                                  ? theme.colorScheme.primary.withOpacity(0.3)
                                  : theme.colorScheme.outline.withOpacity(0.15),
                                width: isTopPrediction ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isTopPrediction 
                                    ? theme.colorScheme.primary.withOpacity(0.2)
                                    : theme.colorScheme.shadow.withOpacity(0.05),
                                  blurRadius: isTopPrediction ? 8 : 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Enhanced rank badge - smaller for second prediction
                                Container(
                                  width: isTopPrediction ? 32 : 28,
                                  height: isTopPrediction ? 32 : 28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isTopPrediction
                                        ? [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.primary.withOpacity(0.8),
                                          ]
                                        : [
                                            theme.colorScheme.outline.withOpacity(0.5),
                                            theme.colorScheme.outline.withOpacity(0.3),
                                          ],
                                    ),
                                    borderRadius: BorderRadius.circular(isTopPrediction ? 16 : 14),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: isTopPrediction 
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isTopPrediction ? null : 10,
                                          ),
                                        ),
                                      ),
                                      if (isTopPrediction)
                                        Positioned(
                                          top: 1,
                                          right: 1,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.circular(5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.amber.withOpacity(0.5),
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.star,
                                              size: 6,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(width: isTopPrediction ? 12 : 10),
                                
                                // Enhanced label and confidence - adjusted sizing
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prediction['label'] as String,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: isTopPrediction 
                                                  ? FontWeight.w700 
                                                  : FontWeight.w500,
                                                color: isTopPrediction
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface.withOpacity(0.8),
                                                fontSize: isTopPrediction ? null : 13,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isTopPrediction ? 6 : 5, 
                                              vertical: 2
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getConfidenceColor(confidence, theme).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(isTopPrediction ? 8 : 6),
                                              border: Border.all(
                                                color: _getConfidenceColor(confidence, theme).withOpacity(0.5),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${confidence.toStringAsFixed(1)}%',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: _getConfidenceColor(confidence, theme),
                                                fontSize: isTopPrediction ? 10 : 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: isTopPrediction ? 8 : 6),
                                      
                                      // Enhanced confidence bar - thinner for second prediction
                                      Container(
                                        height: isTopPrediction ? 6 : 4,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(isTopPrediction ? 3 : 2),
                                          color: theme.colorScheme.outline.withOpacity(0.2),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(isTopPrediction ? 3 : 2),
                                          child: TweenAnimationBuilder<double>(
                                            duration: Duration(milliseconds: 800 + (index * 200)),
                                            tween: Tween(begin: 0.0, end: confidence / 100),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, animValue, child) {
                                              return LinearProgressIndicator(
                                                value: animValue,
                                                backgroundColor: Colors.transparent,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  _getConfidenceColor(confidence, theme),
                                                ),
                                                minHeight: isTopPrediction ? 6 : 4,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
<<<<<<< HEAD
                      );
                    },
                  ),
                );
              }).toList(),
=======

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
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
            ),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD

  Color _getConfidenceColor(double confidence, ThemeData theme) {
    if (confidence >= 80) {
      return Colors.green;
    } else if (confidence >= 60) {
      return const Color.fromARGB(255, 72, 126, 226);
    } else {
      return Colors.red;
    }
  }
}
=======
}
>>>>>>> e485e7397d2fb8dccffaa41622af905c577cb1ac
