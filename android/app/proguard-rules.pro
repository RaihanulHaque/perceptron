# Keep TensorFlow Lite classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.**

# Suppress warnings for GpuDelegateFactory$Options as per missing_rules.txt
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options