#!/bin/bash

echo "=========================================="
echo "   AlphaOps Agent Connection Fix"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Step 1: Stop existing agent
echo "Step 1: Stopping existing agent..."
if screen -list | grep -q "alphaops-agent"; then
    screen -X -S alphaops-agent quit
    print_status "Stopped existing agent screen session"
else
    print_warning "No existing agent screen session found"
fi

# Kill any orphaned processes
if pkill -f "alphaops-agent"; then
    print_status "Killed orphaned agent processes"
    sleep 2
fi

# Step 2: Check if agent binary exists
echo ""
echo "Step 2: Checking agent binary..."
if [ -f "$HOME/.alphaops/alphaops-agent" ]; then
    print_status "Agent binary found at $HOME/.alphaops/alphaops-agent"
    
    # Check if executable
    if [ -x "$HOME/.alphaops/alphaops-agent" ]; then
        print_status "Agent binary is executable"
    else
        print_warning "Agent binary is not executable, fixing..."
        chmod +x "$HOME/.alphaops/alphaops-agent"
        print_status "Made agent binary executable"
    fi
else
    print_error "Agent binary NOT found at $HOME/.alphaops/alphaops-agent"
    echo ""
    echo "Please run the install command from the AlphaOps UI first."
    exit 1
fi

# Step 3: Check architecture
echo ""
echo "Step 3: Verifying architecture compatibility..."
ARCH=$(uname -m)
print_status "Detected architecture: $ARCH"

# Try to run the binary to see if it works
if timeout 2 "$HOME/.alphaops/alphaops-agent" --help >/dev/null 2>&1; then
    print_status "Agent binary is compatible with this system"
else
    print_error "Agent binary may not be compatible with this architecture"
    echo ""
    echo "Expected architecture:"
    case $ARCH in
        x86_64)
            echo "  - alphaops-agent-linux-amd64"
            ;;
        aarch64|arm64)
            echo "  - alphaops-agent-linux-arm64"
            ;;
        *)
            echo "  - Unknown/Unsupported: $ARCH"
            ;;
    esac
fi

# Step 4: Check network connectivity
echo ""
echo "Step 4: Testing backend connectivity..."
BACKEND_HOST="alphaops-production.up.railway.app"

if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "https://$BACKEND_HOST/health")
    if [ "$HTTP_CODE" = "200" ]; then
        print_status "Backend is reachable (HTTP $HTTP_CODE)"
    else
        print_error "Backend returned HTTP $HTTP_CODE"
        echo "  This may indicate a network or backend issue"
    fi
else
    print_warning "curl not available, skipping connectivity test"
fi

# Step 5: Check for required environment variables
echo ""
echo "Step 5: Checking environment variables..."

if [ -n "$AlphaOps_AGENT_TOKEN" ]; then
    print_status "AlphaOps_AGENT_TOKEN is set"
    TOKEN_SET=1
else
    print_warning "AlphaOps_AGENT_TOKEN is NOT set"
    TOKEN_SET=0
fi

if [ -n "$AlphaOps_BACKEND_URL" ]; then
    print_status "AlphaOps_BACKEND_URL is set to: $AlphaOps_BACKEND_URL"
    BACKEND_SET=1
else
    print_warning "AlphaOps_BACKEND_URL is NOT set (will use default)"
    BACKEND_SET=0
fi

# Step 6: Provide instructions
echo ""
echo "=========================================="
echo "   Next Steps"
echo "=========================================="
echo ""

if [ $TOKEN_SET -eq 0 ]; then
    echo "The agent needs a token to connect. You have two options:"
    echo ""
    echo "Option 1: Set environment variables and start manually"
    echo "  export AlphaOps_AGENT_TOKEN='your-token-from-ui'"
    echo "  export AlphaOps_BACKEND_URL='https://alphaops-production.up.railway.app'"
    echo "  cd ~/.alphaops"
    echo "  screen -dmS alphaops-agent ./alphaops-agent --token \"\$AlphaOps_AGENT_TOKEN\" --backend \"\$AlphaOps_BACKEND_URL\""
    echo ""
    echo "Option 2: Re-run the install command from the AlphaOps UI"
    echo "  (This is the recommended approach)"
    echo ""
else
    echo "Environment is configured. Starting agent..."
    echo ""
    
    cd "$HOME/.alphaops" || exit 1
    
    # Start the agent
    if [ $BACKEND_SET -eq 1 ]; then
        screen -dmS alphaops-agent ./alphaops-agent --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL"
    else
        screen -dmS alphaops-agent ./alphaops-agent --token "$AlphaOps_AGENT_TOKEN" --backend "https://alphaops-production.up.railway.app"
    fi
    
    sleep 2
    
    # Check if it started
    if screen -list | grep -q "alphaops-agent"; then
        print_status "Agent started successfully!"
        echo ""
        echo "To view agent logs:"
        echo "  screen -r alphaops-agent"
        echo ""
        echo "To detach from logs (without stopping agent):"
        echo "  Press Ctrl+A then D"
        echo ""
        echo "The agent should connect to the backend within 10-15 seconds."
    else
        print_error "Failed to start agent"
        echo ""
        echo "Try running manually:"
        echo "  cd ~/.alphaops"
        echo "  ./alphaops-agent --token \"\$AlphaOps_AGENT_TOKEN\" --backend \"https://alphaops-production.up.railway.app\""
    fi
fi

echo ""
echo "=========================================="
