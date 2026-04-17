#!/bin/bash

# AlphaOps Agent Install Script
# This script downloads the prebuilt agent binary and sets it up.

set -e

echo "=========================================="
echo "   AlphaOps Agent Installation"
echo "=========================================="

# Default values
TOKEN=""
BACKEND="wss://alphaops-production.up.railway.app"
INSTALL_DIR="$HOME/.alphaops"
REPO="sohanworks10-byte/AlphaOps"
VERSION="latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$TOKEN" ]; then
  echo "Error: --token is required"
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        BINARY_NAME="alphaops-agent-linux-amd64"
        ;;
    aarch64|arm64)
        BINARY_NAME="alphaops-agent-linux-arm64"
        ;;
    *)
        echo "Error: Unsupported architecture $ARCH"
        exit 1
        ;;
esac

echo "✓ Detected architecture: $ARCH"

# Create install directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Get download URL for the binary
# If version is latest, we'll get it from the latest release
if [ "$VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$BINARY_NAME"
else
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/$BINARY_NAME"
fi

echo "✓ Downloading agent from $DOWNLOAD_URL..."
curl -L -o alphaops-agent "$DOWNLOAD_URL"
chmod +x alphaops-agent

echo "✓ Agent binary downloaded successfully."

# Run the agent with --install to setup screen session
echo "✓ Initializing agent..."
./alphaops-agent --token "$TOKEN" --backend "$BACKEND" --install

echo ""
echo "=========================================="
echo "   Installation Complete!"
echo "=========================================="
echo "The agent is now running in a detached screen session."
echo "To view logs: screen -r alphaops-agent"
echo "To detach: Press Ctrl+A then D"
echo "=========================================="
