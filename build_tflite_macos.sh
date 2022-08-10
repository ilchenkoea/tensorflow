#!/usr/bin/env sh
mkdir -p _build/macos && cd _build/macos

cmake ../../tensorflow/lite/c  \
-DCMAKE_AR=/usr/local/opt/llvm/bin/llvm-ar \
-DCMAKE_BUILD_TYPE=Release \
-DTFLITE_C_BUILD_SHARED_LIBS=OFF \
-DTFLITE_ENABLE_RESOURCE=ON \
-DTFLITE_ENABLE_MMAP=OFF \
-DTFLITE_ENABLE_METAL=ON \
-DTFLITE_ENABLE_COREML=OFF \
-DTFLITE_ENABLE_XNNPACK=OFF \
-DTFLITE_ENABLE_EXTERNAL_DELEGATE=OFF \
-GNinja
ninja -j12 bundling_target

cd ../.. && mkdir -p tflite-osx/libs && mv _build/macos/libtensorflow-lite-bundled.a tflite-osx/libs/libtflite.a
mkdir -p tflite-osx/include/tensorflow/lite/c
mkdir -p tflite-osx/include/tensorflow/lite/delegates/gpu
cp tensorflow/lite/c/builtin_op_data.h tflite-osx/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api_experimental.h tflite-osx/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api_types.h tflite-osx/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api.h tflite-osx/include/tensorflow/lite/c/
cp tensorflow/lite/c/common.h tflite-osx/include/tensorflow/lite/c/
cp tensorflow/lite/builtin_ops.h tflite-osx/include/tensorflow/lite/
cp tensorflow/lite/delegates/gpu/metal_delegate.h tflite-osx/include/tensorflow/lite/delegates/gpu/
