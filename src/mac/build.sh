#!/bin/bash -e

path=`dirname $0`

OUTPUT_DIR=$1
TARGET_NAME=plugin_apple_iap
OUTPUT_SUFFIX=dylib
CONFIG=Release

#
# Checks exit value for error
# 
checkError() {
    if [ $? -ne 0 ]
    then
        echo "Exiting due to errors (above)"
        exit -1
    fi
}

# 
# Canonicalize relative paths to absolute paths
# 
pushd $path > /dev/null
dir=`pwd`
path=$dir
popd > /dev/null

if [ -z "$OUTPUT_DIR" ]
then
    OUTPUT_DIR=.
fi

pushd $OUTPUT_DIR > /dev/null
dir=`pwd`
OUTPUT_DIR=$dir
popd > /dev/null

echo "OUTPUT_DIR: $OUTPUT_DIR"

xcodebuild -project "$path/Plugin.xcodeproj" -configuration $CONFIG clean
checkError

xcodebuild -project "$path/Plugin.xcodeproj" -configuration $CONFIG -target $TARGET_NAME
checkError

# xcodebuild -project "$path/Plugin.xcodeproj" -configuration $CONFIG -target plugin_apple_iap_cryptohelper
# checkError

cp "$path/build/Release/$TARGET_NAME.$OUTPUT_SUFFIX" "$OUTPUT_DIR"
# cp "$path/build/Release/plugin_apple_iap_cryptohelper.$OUTPUT_SUFFIX" "$OUTPUT_DIR"
