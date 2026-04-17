#!/bin/bash

echo "=========================================="
echo "   AlphaOps Agent Diagnostic"
echo "=========================================="
echo ""

# Check if agent is running
echo "1. Checking if agent process is running..."
if ps aux | grep -v grep | grep -q "AlphaOps.*agent\|alphaops-agent"; then
    echo "   ✅ Agent process found:"
    ps aux | grep -v grep | grep "AlphaOps.*agent\|alphaops-agent"
else
    echo "   ❌ No agent process running"
fi
echo ""

# Check screen sessions
echo "2. Checking screen sessions..."
if command -v screen >/dev/null 2>&1; then
    if screen -list | grep -q "alphaops-agent"; then
        echo "   ✅ Screen session 'alphaops-agent' exists"
        screen -list | grep alphaops-agent
    else
        echo "   ❌ No 'alphaops-agent' screen session found"
        echo "   Available sessions:"
        screen -list || echo "   No screen sessions"
    fi
else
    echo "   ⚠️  screen not installed"
fi
echo ""

# Check systemd service
echo "3. Checking systemd service..."
if systemctl list-units --all | grep -q "AlphaOps-agent"; then
    echo "   ✅ Systemd service exists"
    sudo systemctl status AlphaOps-agent --no-pager || true
else
    echo "   ❌ No systemd service found"
fi
echo ""

# Check config file
echo "4. Checking configuration..."
if [ -f /opt/AlphaOps-agent/config.env ]; then
    echo "   ✅ Config file exists at /opt/AlphaOps-agent/config.env"
    echo "   Token: $(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env 2>/dev/null | cut -d= -f2 | cut -c1-20)..."
    echo "   Backend: $(sudo grep AlphaOps_BACKEND_URL /opt/AlphaOps-agent/config.env 2>/dev/null | cut -d= -f2)"
elif [ -f ~/.alphaops/config.env ]; then
    echo "   ✅ Config file exists at ~/.alphaops/config.env"
    echo "   Token: $(grep AlphaOps_AGENT_TOKEN ~/.alphaops/config.env 2>/dev/null | cut -d= -f2 | cut -c1-20)..."
    echo "   Backend: $(grep AlphaOps_BACKEND_URL ~/.alphaops/config.env 2>/dev/null | cut -d= -f2)"
else
    echo "   ❌ No config file found"
fi
echo ""

# Check agent binary/script
echo "5. Checking agent installation..."
if [ -f /opt/AlphaOps-agent/agent.js ]; then
    echo "   ✅ Node.js agent found at /opt/AlphaOps-agent/agent.js"
    echo "   Node version: $(node --version 2>/dev/null || echo 'Node.js not found')"
elif [ -f ~/.alphaops/alphaops-agent ]; then
    echo "   ✅ Binary agent found at ~/.alphaops/alphaops-agent"
    file ~/.alphaops/alphaops-agent
else
    echo "   ❌ No agent binary or script found"
fi
echo ""

# Check network connectivity
echo "6. Testing backend connectivity..."
BACKEND_URL="https://alphaops-production.up.railway.app"
if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/health" | grep -q "200"; then
    echo "   ✅ Backend is reachable at $BACKEND_URL"
else
    echo "   ❌ Cannot reach backend at $BACKEND_URL"
fi
echo ""

# Check logs
echo "7. Checking recent logs..."
if [ -f /var/log/AlphaOps-agent/install.log ]; then
    echo "   Last 10 lines of install log:"
    sudo tail -10 /var/log/AlphaOps-agent/install.log
elif journalctl -u AlphaOps-agent -n 10 --no-pager >/dev/null 2>&1; then
    echo "   Last 10 lines from systemd journal:"
    sudo journalctl -u AlphaOps-agent -n 10 --no-pager
else
    echo "   ⚠️  No logs found"
fi
echo ""

echo "=========================================="
echo "   Diagnostic Complete"
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo "1. If agent is not running, check the install command"
echo "2. If agent is running but not connecting, check the token and backend URL"
echo "3. To view live logs: screen -r alphaops-agent (or sudo journalctl -u AlphaOps-agent -f)"
echo ""
