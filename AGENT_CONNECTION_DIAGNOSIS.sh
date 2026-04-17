#!/bin/bash

echo "=========================================="
echo "   AlphaOps Agent Connection Diagnosis"
echo "=========================================="
echo ""

# Check if agent is running
echo "1. Checking if agent is running..."
if screen -list | grep -q "alphaops-agent"; then
    echo "   ✓ Agent screen session found"
    echo ""
    echo "   Recent agent logs:"
    screen -S alphaops-agent -X hardcopy /tmp/agent_output.txt
    tail -20 /tmp/agent_output.txt 2>/dev/null || echo "   (Could not read agent output)"
else
    echo "   ✗ Agent screen session NOT found"
    echo "   The agent is not running. Please run the install command again."
fi

echo ""
echo "2. Checking agent process..."
if ps aux | grep -v grep | grep -q "alphaops-agent"; then
    echo "   ✓ Agent process is running"
    ps aux | grep -v grep | grep "alphaops-agent"
else
    echo "   ✗ Agent process NOT running"
fi

echo ""
echo "3. Checking network connectivity to backend..."
BACKEND_HOST="alphaops-production.up.railway.app"
if command -v nc >/dev/null 2>&1; then
    if nc -zv -w5 $BACKEND_HOST 443 2>&1 | grep -q "succeeded\|open"; then
        echo "   ✓ Can reach backend at $BACKEND_HOST:443"
    else
        echo "   ✗ Cannot reach backend at $BACKEND_HOST:443"
    fi
elif command -v telnet >/dev/null 2>&1; then
    if timeout 5 telnet $BACKEND_HOST 443 2>&1 | grep -q "Connected"; then
        echo "   ✓ Can reach backend at $BACKEND_HOST:443"
    else
        echo "   ✗ Cannot reach backend at $BACKEND_HOST:443"
    fi
else
    echo "   ? Cannot test connectivity (nc/telnet not available)"
fi

echo ""
echo "4. Checking WebSocket connection..."
if command -v curl >/dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$BACKEND_HOST/health)
    if [ "$HTTP_CODE" = "200" ]; then
        echo "   ✓ Backend health check passed (HTTP $HTTP_CODE)"
    else
        echo "   ✗ Backend health check failed (HTTP $HTTP_CODE)"
    fi
else
    echo "   ? Cannot test (curl not available)"
fi

echo ""
echo "5. Checking agent binary..."
if [ -f "$HOME/.alphaops/alphaops-agent" ]; then
    echo "   ✓ Agent binary exists at $HOME/.alphaops/alphaops-agent"
    ls -lh "$HOME/.alphaops/alphaops-agent"
else
    echo "   ✗ Agent binary NOT found at $HOME/.alphaops/alphaops-agent"
fi

echo ""
echo "6. Checking environment variables..."
if [ -n "$AlphaOps_AGENT_TOKEN" ]; then
    echo "   ✓ AlphaOps_AGENT_TOKEN is set"
else
    echo "   ✗ AlphaOps_AGENT_TOKEN is NOT set"
fi

if [ -n "$AlphaOps_BACKEND_URL" ]; then
    echo "   ✓ AlphaOps_BACKEND_URL is set to: $AlphaOps_BACKEND_URL"
else
    echo "   ✗ AlphaOps_BACKEND_URL is NOT set"
fi

echo ""
echo "=========================================="
echo "   Diagnosis Complete"
echo "=========================================="
echo ""
echo "To view live agent logs:"
echo "  screen -r alphaops-agent"
echo ""
echo "To restart the agent:"
echo "  screen -X -S alphaops-agent quit"
echo "  Then run the install command again"
echo ""
