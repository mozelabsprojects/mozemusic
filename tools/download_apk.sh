#!/bin/bash
# MozeMusic Android APK Downloader
# Mozelabs (https://mozelabs.com)

REPO="mozelabsprojects/mozemusic"
API_URL="https://api.github.com/repos/$REPO/releases/latest"

echo "========================================"
echo "   MozeMusic Android APK Downloader    "
echo "         Powered by Mozelabs           "
echo "========================================"
echo ""

echo "[1/2] Fetching latest release info..."
LATEST_TAG=$(curl -s $API_URL | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="latest"
fi

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/MozeMusic-Android.apk"
OUTPUT_FILE="MozeMusic-$LATEST_TAG.apk"

echo "[2/2] Downloading $OUTPUT_FILE from $DOWNLOAD_URL..."
curl -L -o "$OUTPUT_FILE" "$DOWNLOAD_URL"

echo ""
echo "Done! Saved to $OUTPUT_FILE"
