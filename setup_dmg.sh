#!/bin/sh

APP_VERSION=$1
ARCH=$2
DMG_NAME=cyclonedds-insight-$APP_VERSION-darwin-$ARCH.dmg

mkdir -p dist/dmg
rm -r dist/dmg/*
cp -r "dist/CycloneDDS Insight.app" dist/dmg
test -f "dist/$DMG_NAME" && rm "dist/$DMG_NAME"
create-dmg \
  --volname "CycloneDDS Insight" \
  --volicon "res/images/icon.icns" \
  --window-pos 200 120 \
  --window-size 600 300 \
  --icon-size 100 \
  --icon "CycloneDDS Insight.app" 175 120 \
  --hide-extension "CycloneDDS Insight.app" \
  --app-drop-link 425 120 \
  "dist/$DMG_NAME" \
  "dist/dmg/"
