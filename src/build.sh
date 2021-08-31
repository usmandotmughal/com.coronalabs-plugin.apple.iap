#!/bin/bash -e

CURDIR="$(pwd)"

cd "$(dirname $0)"
WD="$(pwd)"

#build

cd "$WD/ios"
./build.sh

cd "$WD/mac"
./build.sh

cd "$WD/tvos"
./build.sh

#copy

cd "$WD"
rm -rf OUT


mkdir -p OUT/iap/mac-sim/ OUT/helper/mac-sim/
cp mac/build/Release/plugin_apple_iap.dylib OUT/iap/mac-sim/
# cp mac/build/Release/plugin_apple_iap_cryptohelper.dylib OUT/helper/mac-sim/
# Reconsider doing this
cp plugins-hosted-openssl/plugins/2016.2883/mac-sim/plugin_openssl.dylib OUT/helper/mac-sim

cp -r ios/BuiltPlugin/iphone OUT/iap/
cp -r ios/BuiltPlugin/iphone-sim OUT/iap/
cp -r ios/BuiltCryptohelperPlugin/iphone OUT/helper/
cp -r ios/BuiltCryptohelperPlugin/iphone-sim OUT/helper/

mkdir -p OUT/iap/appletvos/ OUT/helper/appletvos/  OUT/iap/appletvsimulator/  OUT/helper/appletvsimulator/
cp -r tvos/build/Release-appletvos/Corona_plugin_apple_iap.framework OUT/iap/appletvos/
cp -r tvos/build/Release-appletvos/Corona_plugin_apple_iap_cryptohelper.framework OUT/helper/appletvos/
cp -r tvos/build/Release-appletvsimulator/Corona_plugin_apple_iap.framework OUT/iap/appletvsimulator/
cp -r tvos/build/Release-appletvsimulator/Corona_plugin_apple_iap_cryptohelper.framework OUT/helper/appletvsimulator/
cp tvos/metadata.lua OUT/iap/appletvos/
cp tvos/metadata.lua OUT/iap/appletvsimulator/
cp tvos/metadata_cryptohelper.lua OUT/helper/appletvos/metadata.lua
cp tvos/metadata_cryptohelper.lua OUT/helper/appletvsimulator/metadata.lua

mkdir -p OUT/helper/win32-sim OUT/iap/win32-sim
cp win32-stub/plugin_apple_iap.lua OUT/helper/win32-sim
cp win32-stub/plugin_apple_iap.lua OUT/iap/win32-sim

mkdir -p OUT/helper/android OUT/iap/android
cp win32-stub/plugin_apple_iap.lua OUT/helper/android
cp win32-stub/plugin_apple_iap.lua OUT/iap/android

cd "$CURDIR"