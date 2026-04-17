#!/bin/bash

# AlphaOps Agent Install Script (Node.js Version)
# This script installs Node.js and runs the agent as a Node.js application

set -e

echo "=========================================="
echo "   AlphaOps Agent Installation"
echo "=========================================="

# Default values
TOKEN=""
BACKEND="https://alphaops-production.up.railway.app"
INSTALL_DIR="$HOME/.alphaops"
REPO_RAW="https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent"

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
  echo "Usage: $0 --token YOUR_TOKEN [--backend BACKEND_URL]"
  exit 1
fi

echo "✓ Token received"
echo "✓ Backend: $BACKEND"

# Check if Node.js is installed
if ! command -v node >/dev/null 2>&1; then
    echo ""
    echo "Node.js not found. Installing Node.js 20.x..."
    
    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    else
        echo "Error: Unsupported OS. Please install Node.js 18+ manually."
        echo "Visit: https://nodejs.org/"
        exit 1
    fi
    
    if ! command -v node >/dev/null 2>&1; then
        echo "Error: Node.js installation failed"
        exit 1
    fi
fi

NODE_VERSION=$(node --version)
echo "✓ Node.js installed: $NODE_VERSION"

# Check Node.js version (must be >= 18)
NODE_MAJOR=$(node --version | cut -d'.' -f1 | sed 's/v//')
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "Error: Node.js version must be >= 18 (current: $NODE_VERSION)"
    echo "Please upgrade Node.js: https://nodejs.org/"
    exit 1
fi

# Create install directory
echo ""
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Stop existing agent if running
if screen -list 2>/dev/null | grep -q "alphaops-agent"; then
    echo "✓ Stopping existing agent session..."
    screen -X -S alphaops-agent quit || true
    sleep 2
fi

# Kill any orphaned processes
pkill -f "node.*agent.js" || true

# Download agent files
echo ""
echo "Downloading agent files..."

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/agent.js" -o agent.js
    curl -fsSL "$REPO_RAW/package.json" -o package.json
elif command -v wget >/dev/null 2>&1; then
    wget -q "$REPO_RAW/agent.js" -O agent.js
    wget -q "$REPO_RAW/package.json" -O package.json
else
    echo "Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

if [ ! -f agent.js ] || [ ! -f package.json ]; then
    echo "Error: Failed to download agent files"
    exit 1
fi

echo "✓ Agent files downloaded"

# Install dependencies
echo ""
echo "Installing dependencies..."
npm install --production --silent

if [ ! -d node_modules ]; then
    echo "Error: Failed to install dependencies"
    exit 1
fi

echo "✓ Dependencies installed"

# Install screen if not present
if ! command -v screen >/dev/null 2>&1; then
    echo ""
    echo "Installing screen..."
    if [ -f /etc/debian_version ]; then
        sudo apt-get update && sudo apt-get install -y screen
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y screen
    else
        echo "Warning: Could not install screen automatically"
        echo "Please install screen manually and run:"
        echo "  cd $INSTALL_DIR"
        echo "  node agent.js --token \"$TOKEN\" --backend \"$BACKEND\""
        exit 1
    fi
fi

echo "✓ Screen installed"

# Start agent in screen session
echo ""
echo "Starting agent..."
screen -dmS alphaops-agent node agent.js --token "$TOKEN" --backend "$BACKEND"

# Wait a moment for the agent to start
sleep 3

# Verify it's running
if screen -list 2>/dev/null | grep -q "alphaops-agent"; then
    echo ""
    echo "=========================================="
    echo "   Installation Complete!"
    echo "=========================================="
    echo ""
    echo "✓ Agent is running in screen session 'alphaops-agent'"
    echo ""
    echo "Useful commands:"
    echo "  View logs:    screen -r alphaops-agent"
    echo "  Detach:       Press Ctrl+A then D"
    echo "  Stop agent:   screen -X -S alphaops-agent quit"
    echo "  Restart:      Run this install script again"
    echo ""
    echo "The agent should connect to the backend within 10-15 seconds."
    echo "=========================================="
    exit 0
else
    echo ""
    echo "=========================================="
    echo "   Warning: Agent may not have started"
    echo "=========================================="
    echo ""
    echo "Try running manually to see error messages:"
    echo "  cd $INSTALL_DIR"
    echo "  node agent.js --token \"$TOKEN\" --backend \"$BACKEND\""
    echo ""
    echo "Or check the logs:"
    echo "  screen -r alphaops-agent"
    echo ""
    exit 1
fi
