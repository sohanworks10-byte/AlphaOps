#!/bin/bash

# AlphaOps Agent Connection Diagnostic Script
# Run this on your server to diagnose connection issues

echo "=========================================="
echo "AlphaOps Agent Diagnostic"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Service Status
echo "1. Checking service status..."
if sudo systemctl is-active --quiet AlphaOps-agent 2>/dev/null; then
    echo -e "   ${GREEN}✓${NC} Agent service is running"
    SERVICE_RUNNING=1
else
    echo -e "   ${RED}✗${NC} Agent service is NOT running"
    echo "   Fix: sudo systemctl start AlphaOps-agent"
    SERVICE_RUNNING=0
fi
echo ""

# Check 2: Recent Logs
echo "2. Checking connection logs..."
if [ $SERVICE_RUNNING -eq 1 ]; then
    LOGS=$(sudo journalctl -u AlphaOps-agent -n 50 --no-pager 2>/dev/null)
    
    if echo "$LOGS" | grep -q "\[AlphaOps-agent\] connected"; then
        echo -e "   ${GREEN}✓${NC} Agent successfully connected to backend"
        AGENT_CONNECTED=1
    elif echo "$LOGS" | grep -q "ECONNREFUSED"; then
        echo -e "   ${RED}✗${NC} Connection refused - backend not reachable"
        echo "   Backend URL may be wrong or backend is down"
        AGENT_CONNECTED=0
    elif echo "$LOGS" | grep -q "invalid token"; then
        echo -e "   ${RED}✗${NC} Invalid token - authentication failed"
        echo "   Need to re-enroll with new token"
        AGENT_CONNECTED=0
    else
        echo -e "   ${YELLOW}?${NC} No clear connection status in logs"
        echo "   Last 5 log lines:"
        sudo journalctl -u AlphaOps-agent -n 5 --no-pager | tail -5
        AGENT_CONNECTED=0
    fi
else
    AGENT_CONNECTED=0
fi
echo ""

# Check 3: Backend Health
echo "3. Checking backend health..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://alphaops-production.up.railway.app/health 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "   ${GREEN}✓${NC} Backend is healthy (HTTP $HTTP_CODE)"
    BACKEND_HEALTHY=1
else
    echo -e "   ${RED}✗${NC} Backend returned HTTP $HTTP_CODE"
    echo "   Backend may not be deployed yet"
    BACKEND_HEALTHY=0
fi
echo ""

# Check 4: Configuration
echo "4. Checking configuration..."
if [ -f /opt/AlphaOps-agent/config.env ]; then
    echo -e "   ${GREEN}✓${NC} Config file exists"
    BACKEND_URL=$(sudo grep AlphaOps_BACKEND_URL /opt/AlphaOps-agent/config.env 2>/dev/null | cut -d= -f2)
    echo "   Backend URL: $BACKEND_URL"
    
    # Check if token exists
    TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env 2>/dev/null | cut -d= -f2)
    if [ -n "$TOKEN" ]; then
        echo "   Token: ${TOKEN:0:20}... (truncated)"
    else
        echo -e "   ${RED}✗${NC} No token found in config"
    fi
elif [ -f /usr/local/etc/AlphaOps-agent.conf ]; then
    echo -e "   ${GREEN}✓${NC} Config file exists (binary installation)"
else
    echo -e "   ${RED}✗${NC} Config file not found"
fi
echo ""

# Check 5: Network Connectivity
echo "5. Checking network connectivity..."
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo -e "   ${GREEN}✓${NC} Internet connectivity OK"
else
    echo -e "   ${RED}✗${NC} No internet connectivity"
fi

if nslookup alphaops-production.up.railway.app >/dev/null 2>&1; then
    echo -e "   ${GREEN}✓${NC} DNS resolution OK"
else
    echo -e "   ${YELLOW}?${NC} DNS resolution may have issues"
fi
echo ""

# Check 6: Agent ID
echo "6. Extracting agent ID..."
if [ -f /opt/AlphaOps-agent/config.env ]; then
    TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env 2>/dev/null | cut -d= -f2)
    if [ -n "$TOKEN" ]; then
        if command -v jq >/dev/null 2>&1; then
            AGENT_ID=$(echo $TOKEN | cut -d. -f1 | base64 -d 2>/dev/null | jq -r '.agentId' 2>/dev/null)
            if [ -n "$AGENT_ID" ] && [ "$AGENT_ID" != "null" ]; then
                echo "   Agent ID: $AGENT_ID"
                echo "   (Use this in frontend to check status)"
            else
                echo "   Could not decode agent ID"
            fi
        else
            echo "   Install jq to decode agent ID: sudo apt-get install -y jq"
        fi
    fi
fi
echo ""

# Summary
echo "=========================================="
echo "SUMMARY"
echo "=========================================="

if [ $SERVICE_RUNNING -eq 1 ] && [ $AGENT_CONNECTED -eq 1 ] && [ $BACKEND_HEALTHY -eq 1 ]; then
    echo -e "${GREEN}✓ Agent is running and connected!${NC}"
    echo ""
    echo "If frontend still doesn't show it:"
    echo "1. Check that you're using the correct agentId in frontend"
    echo "2. Check browser console for errors"
    echo "3. Try refreshing the frontend page"
    echo "4. Or re-enroll the agent to get a fresh connection"
elif [ $SERVICE_RUNNING -eq 0 ]; then
    echo -e "${RED}✗ Agent service is not running${NC}"
    echo ""
    echo "Fix:"
    echo "  sudo systemctl start AlphaOps-agent"
    echo "  sudo journalctl -u AlphaOps-agent -f"
elif [ $BACKEND_HEALTHY -eq 0 ]; then
    echo -e "${RED}✗ Backend is not healthy${NC}"
    echo ""
    echo "Fix:"
    echo "  1. Deploy backend: git push origin main"
    echo "  2. Wait 2-3 minutes for Railway to deploy"
    echo "  3. Test: curl https://alphaops-production.up.railway.app/health"
elif [ $AGENT_CONNECTED -eq 0 ]; then
    echo -e "${RED}✗ Agent is not connected to backend${NC}"
    echo ""
    echo "Check logs for details:"
    echo "  sudo journalctl -u AlphaOps-agent -n 50"
    echo ""
    echo "Common fixes:"
    echo "  - If 'ECONNREFUSED': Backend is down, deploy it first"
    echo "  - If 'invalid token': Re-enroll agent with new token"
    echo "  - If no errors: Restart agent (sudo systemctl restart AlphaOps-agent)"
else
    echo -e "${YELLOW}? Status unclear${NC}"
    echo ""
    echo "View full logs:"
    echo "  sudo journalctl -u AlphaOps-agent -n 100"
fi

echo "=========================================="
