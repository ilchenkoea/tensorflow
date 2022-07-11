#!/usr/bin/env sh

alias ANDROID_CMAKE_CMD="cmake ../../../tensorflow/lite/c \
-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
-DCMAKE_BUILD_TYPE=Release \
-DTFLITE_C_BUILD_SHARED_LIBS=OFF \
-DTFLITE_ENABLE_XNNPACK=OFF \
-DTFLITE_ENABLE_RUY=OFF \
-DTFLITE_ENABLE_GL_CL=ON \
-DTFLITE_ENABLE_NNAPI=ON \
-DTFLITE_ENABLE_MMAP=OFF"

mkdir -p _build/android/arm64-v8a && cd _build/android/arm64-v8a
ANDROID_CMAKE_CMD -DANDROID_ABI="arm64-v8a"
make -j12 bundling_target

cd ../../.. && mkdir -p _build/android/armeabi-v7a && cd _build/android/armeabi-v7a
ANDROID_CMAKE_CMD -DANDROID_ABI="armeabi-v7a"
make -j12 bundling_target

cd ../../.. && mkdir -p _build/android/x86 && cd _build/android/x86
ANDROID_CMAKE_CMD -DANDROID_ABI="x86"
make -j12 bundling_target

cd ../../..

# Create separate directory and copy libs there
mkdir -p tflite-android/libs/arm64-v8a
cp _build/android/arm64-v8a/libtensorflow-lite-bundled.a tflite-android/libs/arm64-v8a/libtflite.a

mkdir -p tflite-android/libs/armeabi-v7a
cp _build/android/armeabi-v7a/libtensorflow-lite-bundled.a tflite-android/libs/armeabi-v7a/libtflite.a

mkdir -p tflite-android/libs/x86
cp _build/android/x86/libtensorflow-lite-bundled.a tflite-android/libs/x86/libtflite.a

mkdir -p tflite-android/include/tensorflow/lite/c
mkdir -p tflite-android/include/tensorflow/lite/delegates/gpu
cp tensorflow/lite/c/builtin_op_data.h tflite-android/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api_experimental.h tflite-android/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api_types.h tflite-android/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api.h tflite-android/include/tensorflow/lite/c/
cp tensorflow/lite/c/common.h tflite-android/include/tensorflow/lite/c/
cp tensorflow/lite/builtin_ops.h tflite-android/include/tensorflow/lite/
cp tensorflow/lite/delegates/gpu/delegate.h tflite-android/include/tensorflow/lite/delegates/gpu/

zip -r tflite-android-2.9.1.1.zip tflite-android
