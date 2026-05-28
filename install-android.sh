#!/bin/bash
set -e
sudo mkdir -p /usr/local/lib/android/sdk
sudo chown -R codespace:codespace /usr/local/lib/android
unzip -q /workspaces/ytmusic-player/cmdline-tools.zip -d /tmp/cmdline-tools-out
mkdir -p /usr/local/lib/android/sdk/cmdline-tools
mv /tmp/cmdline-tools-out/cmdline-tools /usr/local/lib/android/sdk/cmdline-tools/latest
rm -f /workspaces/ytmusic-player/cmdline-tools.zip
rm -rf /tmp/cmdline-tools-out
echo "extracted"
