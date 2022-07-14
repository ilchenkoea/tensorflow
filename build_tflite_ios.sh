#!/usr/bin/env sh
mkdir -p _build/ios && cd _build/ios

alias IOS_CMAKE_CMD="cmake ../../../tensorflow/lite/c  \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_TOOLCHAIN_FILE=../../../tensorflow/lite/tools/cmake/ios.toolchain.cmake \
-DENABLE_BITCODE=0 \
-DTFLITE_C_BUILD_SHARED_LIBS=OFF \
-DTFLITE_ENABLE_RESOURCE=ON \
-DTFLITE_ENABLE_MMAP=OFF \
-DTFLITE_ENABLE_METAL=ON \
-DTFLITE_ENABLE_COREML=OFF \
-DTFLITE_ENABLE_XNNPACK=OFF \
-DTFLITE_ENABLE_EXTERNAL_DELEGATE=OFF \
-GXcode"

alias IOS_BUILD_CMD="xcodebuild  \
ONLY_ACTIVE_ARCH=NO \
-scheme tensorflowlite_c \
-target tensorflowlite_c \
-configuration Release"

for arch in "arm64" "armv7" "armv7s"
do
    mkdir -p iphoneos-$arch && cd iphoneos-$arch
    IOS_CMAKE_CMD -DPLATFORM=OS -DARCHS=$arch -DDEPLOYMENT_TARGET=10.0
    IOS_BUILD_CMD -sdk iphoneos
    sed -i -e 's/\${EFFECTIVE_PLATFORM_NAME}/-iphoneos/g' "tensorflow-lite-bundled-Release.ar"
    /usr/local/opt/llvm/bin/llvm-ar -M < tensorflow-lite-bundled-Release.ar
    cd ..
done

mkdir -p iphonesimulator-arm64 && cd iphonesimulator-arm64
IOS_CMAKE_CMD -DPLATFORM=SIMULATORARM64 -DARCHS=arm64 -DDEPLOYMENT_TARGET=10.0
IOS_BUILD_CMD -sdk iphonesimulator
sed -i -e 's/\${EFFECTIVE_PLATFORM_NAME}/-iphonesimulator/g' "tensorflow-lite-bundled-Release.ar"
/usr/local/opt/llvm/bin/llvm-ar -M < tensorflow-lite-bundled-Release.ar

cd .. && mkdir -p iphonesimulator-x86_64 && cd iphonesimulator-x86_64
IOS_CMAKE_CMD -DPLATFORM=SIMULATOR64 -DARCHS=x86_64
IOS_BUILD_CMD -sdk iphonesimulator
sed -i -e 's/\${EFFECTIVE_PLATFORM_NAME}/-iphonesimulator/g' "tensorflow-lite-bundled-Release.ar"
/usr/local/opt/llvm/bin/llvm-ar -M < tensorflow-lite-bundled-Release.ar

cd .. && mkdir -p simulator && mkdir -p iphoneos

lipo -create iphonesimulator-x86_64/libtensorflow-lite-bundled.a \
iphonesimulator-arm64/libtensorflow-lite-bundled.a \
-output simulator/libtflite.a

lipo -create iphoneos-armv7/libtensorflow-lite-bundled.a \
iphoneos-armv7s/libtensorflow-lite-bundled.a \
iphoneos-arm64/libtensorflow-lite-bundled.a \
-output iphoneos/libtflite.a

xcodebuild -create-xcframework -library simulator/libtflite.a  -library iphoneos/libtflite.a -output tflite.xcframework

cd ../.. && mkdir -p tflite-ios && mv _build/ios/tflite.xcframework tflite-ios/
mkdir -p tflite-ios/include/tensorflow/lite/c
mkdir -p tflite-ios/include/tensorflow/lite/delegates/gpu
cp tensorflow/lite/c/builtin_op_data.h tflite-ios/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api_experimental.h tflite-ios/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api_types.h tflite-ios/include/tensorflow/lite/c/
cp tensorflow/lite/c/c_api.h tflite-ios/include/tensorflow/lite/c/
cp tensorflow/lite/c/common.h tflite-ios/include/tensorflow/lite/c/
cp tensorflow/lite/builtin_ops.h tflite-ios/include/tensorflow/lite/
cp tensorflow/lite/delegates/gpu/metal_delegate.h tflite-ios/include/tensorflow/lite/delegates/gpu/
