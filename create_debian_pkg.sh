#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Error: Exactly 2 arguments required."
    echo "Usage $0 <version> <architecture>"
    echo ""
    echo "Example: $0 \"0.0.0\" \"amd64\""
    exit 1
fi

set -e
set -o pipefail

echo "BUILDING DEBIAN PKG $1 $2"
mkdir -p build
echo "PREPARE ARTIFACTS"
cp -r ./res/debian-pkg build/
cp -r ./dist/CycloneDDS\ Insight/* ./build/debian-pkg/cyclonedds-insight/usr/share/CycloneDDS\ Insight
cp ./res/images/cyclonedds.png ./build/debian-pkg/cyclonedds-insight/usr/share/CycloneDDS\ Insight/cyclonedds.png 
echo -e "\nVersion: $1" >> build/debian-pkg/cyclonedds-insight/DEBIAN/control
echo "BUILD PKG"
dpkg-deb --build --root-owner-group ./build/debian-pkg/cyclonedds-insight
echo "RENAME"
mv ./build/debian-pkg/cyclonedds-insight.deb "./dist/cyclonedds-insight_$1_$2.deb"
echo "DONE"
