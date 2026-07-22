#!/bin/bash
# После castle-engine package --os=android --cpu=aarch64
# добавляет android:usesCleartextTraffic="true" в AndroidManifest.xml
MANIFEST="castle-engine-output/android/project/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  sed -i 's|<application android:label|<application android:usesCleartextTraffic="true" android:label|' "$MANIFEST"
fi
cd castle-engine-output/android/project
ANDROID_HOME=/home/vano/Android/Sdk JAVA_HOME=/usr/lib/jvm/java-17-openjdk ./gradlew assembleDebug
cp app/build/outputs/apk/debug/app-debug.apk ../../../Extract-0.1-android-debug.apk 2>/dev/null
