#!/bin/bash

# AlphaOps Agent Auto-Fix Script
# This script automatically fixes the agent connection issue

set -e

echo "=========================================="
echo "   AlphaOps Agent Auto-Fix"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. This is not recommended."
    print_info "The agent should run as a regular user."
    echo ""
fi

# Get token from user if not provided
if [ -z "$AlphaOps_AGENT_TOKEN" ]; then
    echo "Please enter your AlphaOps agent token:"
    echo "(You can find this in the AlphaOps UI connection dialog)"
    read -r TOKEN
    export AlphaOps_AGENT_TOKEN="$TOKEN"
else
    print_status "Using token from environment variable"
fi

if [ -z "$AlphaOps_AGENT_TOKEN" ]; then
    print_error "Token is required"
    exit 1
fi

# Set backend URL
if [ -z "$AlphaOps_BACKEND_URL" ]; then
    export AlphaOps_BACKEND_URL="https://alphaops-production.up.railway.app"
fi

print_status "Backend: $AlphaOps_BACKEND_URL"
echo ""

# Step 1: Check/Install Node.js
echo "Step 1: Checking Node.js..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d'.' -f1 | sed 's/v//')
    
    if [ "$NODE_MAJOR" -ge 18 ]; then
        print_status "Node.js $NODE_VERSION is installed"
    else
        print_warning "Node.js $NODE_VERSION is too old (need >= 18)"
        echo "Installing Node.js 20.x..."
        
        if [ -f /etc/debian_version ]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif [ -f /etc/redhat-release ]; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo yum install -y nodejs
        else
            print_error "Unsupported OS. Please install Node.js 18+ manually."
            exit 1
        fi
        
        print_status "Node.js $(node --version) installed"
    fi
else
    print_warning "Node.js not found. Installing..."
    
    if [ -f /etc/debian_version ]; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif [ -f /etc/redhat-release ]; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    else
        print_error "Unsupported OS. Please install Node.js 18+ manually."
        exit 1
    fi
    
    print_status "Node.js $(node --version) installed"
fi

echo ""

# Step 2: Stop existing agent
echo "Step 2: Stopping existing agent..."
if screen -list 2>/dev/null | grep -q "alphaops-agent"; then
    screen -X -S alphaops-agent quit || true
    print_status "Stopped existing screen session"
else
    print_info "No existing screen session found"
fi

# Kill any orphaned processes
if pkill -f "node.*agent.js" 2>/dev/null; then
    print_status "Killed orphaned agent processes"
    sleep 2
fi

echo ""

# Step 3: Setup agent directory
echo "Step 3: Setting up agent directory..."
INSTALL_DIR="$HOME/.alphaops"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
print_status "Agent directory: $INSTALL_DIR"

echo ""

# Step 4: Download agent files
echo "Step 4: Downloading agent files..."
REPO_RAW="https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent"

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/agent.js" -o agent.js
    curl -fsSL "$REPO_RAW/package.json" -o package.json
elif command -v wget >/dev/null 2>&1; then
    wget -q "$REPO_RAW/agent.js" -O agent.js
    wget -q "$REPO_RAW/package.json" -O package.json
else
    print_error "Neither curl nor wget found"
    exit 1
fi

if [ ! -f agent.js ] || [ ! -f package.json ]; then
    print_error "Failed to download agent files"
    exit 1
fi

print_status "Agent files downloaded"

echo ""

# Step 5: Install dependencies
echo "Step 5: Installing dependencies..."
npm install --production --silent

if [ ! -d node_modules ] || [ ! -d node_modules/ws ]; then
    print_error "Failed to install dependencies"
    exit 1
fi

print_status "Dependencies installed"

echo ""

# Step 6: Install screen
echo "Step 6: Checking screen..."
if command -v screen >/dev/null 2>&1; then
    print_status "Screen is installed"
else
    print_warning "Screen not found. Installing..."
    
    if [ -f /etc/debian_version ]; then
        sudo apt-get update && sudo apt-get install -y screen
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y screen
    else
        print_error "Could not install screen automatically"
        print_info "Install screen manually, then run:"
        print_info "  cd $INSTALL_DIR"
        print_info "  node agent.js --token \"\$AlphaOps_AGENT_TOKEN\" --backend \"\$AlphaOps_BACKEND_URL\""
        exit 1
    fi
    
    print_status "Screen installed"
fi

echo ""

# Step 7: Start agent
echo "Step 7: Starting agent..."
screen -dmS alphaops-agent node agent.js --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL"

sleep 3

# Step 8: Verify
echo ""
echo "Step 8: Verifying agent status..."

if screen -list 2>/dev/null | grep -q "alphaops-agent"; then
    print_status "Agent screen session is running"
    
    # Try to capture some output
    screen -S alphaops-agent -X hardcopy /tmp/agent_check.txt 2>/dev/null || true
    sleep 1
    
    if [ -f /tmp/agent_check.txt ]; then
        if grep -q "Connected to AlphaOps backend" /tmp/agent_check.txt 2>/dev/null; then
            print_status "Agent is connected to backend!"
        elif grep -q "AlphaOps Agent starting" /tmp/agent_check.txt 2>/dev/null; then
            print_warning "Agent is starting... (may take a few seconds to connect)"
        else
            print_warning "Agent is running but status unclear"
        fi
        rm -f /tmp/agent_check.txt
    fi
    
    echo ""
    echo "=========================================="
    echo "   Success!"
    echo "=========================================="
    echo ""
    print_status "Agent is running in screen session 'alphaops-agent'"
    echo ""
    echo "Useful commands:"
    echo "  ${BLUE}View logs:${NC}    screen -r alphaops-agent"
    echo "  ${BLUE}Detach:${NC}       Press Ctrl+A then D"
    echo "  ${BLUE}Stop agent:${NC}   screen -X -S alphaops-agent quit"
    echo "  ${BLUE}Restart:${NC}      Run this script again"
    echo ""
    print_info "The agent should connect to the backend within 10-15 seconds."
    print_info "Check the AlphaOps UI to confirm the connection."
    echo ""
    echo "=========================================="
    
else
    print_error "Agent failed to start"
    echo ""
    echo "Try running manually to see error messages:"
    echo "  cd $INSTALL_DIR"
    echo "  node agent.js --token \"\$AlphaOps_AGENT_TOKEN\" --backend \"\$AlphaOps_BACKEND_URL\""
    echo ""
    exit 1
fi

# Step 9: Test backend connectivity
echo ""
echo "Testing backend connectivity..."
if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$AlphaOps_BACKEND_URL/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_status "Backend is reachable (HTTP $HTTP_CODE)"
    else
        print_warning "Backend returned HTTP $HTTP_CODE"
        print_info "This may be normal if the backend is starting up"
    fi
fi

echo ""
print_info "To view live agent logs, run: ${BLUE}screen -r alphaops-agent${NC}"
echo ""
