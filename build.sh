#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP=NoSleep.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp AppIcon.icns $APP/Contents/Resources/
swiftc -O main.swift -o $APP/Contents/MacOS/NoSleep -framework Cocoa -framework IOKit -framework ServiceManagement
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>NoSleep</string>
<key>CFBundleIdentifier</key><string>local.nosleep.app</string>
<key>CFBundleExecutable</key><string>NoSleep</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
codesign --force --deep -s - $APP
echo "Built $(pwd)/$APP"
