# Test Agent Connection

## Quick Test: Is the Agent Actually Connected?

Run these commands on your server to verify:

### 1. Check if agent is running:
```bash
sudo systemctl status AlphaOps-agent | grep "Active:"
```

Expected: `Active: active (running)`

### 2. Check recent logs:
```bash
sudo journalctl -u AlphaOps-agent -n 20 --no-pager | grep -E "connected|error|ECONNREFUSED"
```

Look for:
- ✅ `[AlphaOps-agent] connected` = Agent successfully connected
- ❌ `ECONNREFUSED` = Cannot reach backend
- ❌ `Error` = Something went wrong

### 3. Check if backend is reachable:
```bash
curl -s https://alphaops-production.up.railway.app/health
```

Expected: `{"ok":true}`

### 4. Get your agent ID:
```bash
# Get token from config
TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env 2>/dev/null | cut -d= -f2)

# Show first 50 characters of token
echo "Token (first 50 chars): ${TOKEN:0:50}..."

# Try to decode agentId (requires base64 and jq)
if command -v jq >/dev/null 2>&1; then
  AGENT_ID=$(echo $TOKEN | cut -d. -f1 | base64 -d 2>/dev/null | jq -r '.agentId' 2>/dev/null)
  echo "Agent ID: $AGENT_ID"
else
  echo "Install jq to decode agentId: sudo apt-get install -y jq"
fi
```

## If Agent Shows "connected" in Logs

The agent IS connected to the backend. The issue is that the frontend doesn't know the `agentId`.

### Solution: Re-enroll to let frontend track it

1. **Stop existing agent:**
   ```bash
   sudo systemctl stop AlphaOps-agent
   sudo systemctl disable AlphaOps-agent
   sudo rm /etc/systemd/system/AlphaOps-agent.service
   sudo rm -rf /opt/AlphaOps-agent
   sudo systemctl daemon-reload
   ```

2. **In frontend:** Click "Enroll Agent" button to get new install command

3. **Run the new install command** on your server

4. **Frontend will now show it as connected**

## If Agent Shows Connection Errors

### Error: ECONNREFUSED

Backend is not reachable. Check:

```bash
# Test backend
curl -v https://alphaops-production.up.railway.app/health

# Check if firewall is blocking
sudo ufw status

# Check DNS resolution
nslookup alphaops-production.up.railway.app
```

**Fix:** Deploy the backend first!

```bash
# On your local machine:
git add .
git commit -m "Deploy backend with all fixes"
git push origin main
```

### Error: invalid token

Token validation failed. This means:
- Agent secret mismatch between frontend and backend
- Token expired (unlikely, 1 year TTL)

**Fix:** Re-enroll the agent with a new token

## If Agent Not Running

```bash
# Start it
sudo systemctl start AlphaOps-agent

# Check status
sudo systemctl status AlphaOps-agent

# View logs
sudo journalctl -u AlphaOps-agent -f
```

## Complete Diagnostic Script

Save this as `test-agent.sh`:

```bash
#!/bin/bash

echo "=========================================="
echo "AlphaOps Agent Connection Test"
echo "=========================================="

echo -e "\n1. Service Status:"
if sudo systemctl is-active --quiet AlphaOps-agent; then
  echo "   ✅ Agent service is running"
else
  echo "   ❌ Agent service is NOT running"
  echo "   Run: sudo systemctl start AlphaOps-agent"
  exit 1
fi

echo -e "\n2. Connection Status:"
if sudo journalctl -u AlphaOps-agent -n 50 --no-pager | grep -q "connected"; then
  echo "   ✅ Agent successfully connected to backend"
else
  echo "   ❌ Agent not connected"
  echo "   Recent errors:"
  sudo journalctl -u AlphaOps-agent -n 10 --no-pager | grep -i error
fi

echo -e "\n3. Backend Health:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://alphaops-production.up.railway.app/health)
if [ "$HTTP_CODE" = "200" ]; then
  echo "   ✅ Backend is healthy (HTTP $HTTP_CODE)"
else
  echo "   ❌ Backend returned HTTP $HTTP_CODE"
  echo "   Backend may not be deployed yet"
fi

echo -e "\n4. Configuration:"
if [ -f /opt/AlphaOps-agent/config.env ]; then
  echo "   ✅ Config file exists"
  BACKEND_URL=$(sudo grep AlphaOps_BACKEND_URL /opt/AlphaOps-agent/config.env | cut -d= -f2)
  echo "   Backend URL: $BACKEND_URL"
else
  echo "   ❌ Config file not found"
fi

echo -e "\n5. Agent ID:"
if [ -f /opt/AlphaOps-agent/config.env ]; then
  TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env | cut -d= -f2)
  if command -v jq >/dev/null 2>&1; then
    AGENT_ID=$(echo $TOKEN | cut -d. -f1 | base64 -d 2>/dev/null | jq -r '.agentId' 2>/dev/null)
    if [ -n "$AGENT_ID" ] && [ "$AGENT_ID" != "null" ]; then
      echo "   Agent ID: $AGENT_ID"
      echo "   (Use this ID to check status in frontend)"
    else
      echo "   Could not decode agent ID from token"
    fi
  else
    echo "   Install jq to decode agent ID: sudo apt-get install -y jq"
  fi
fi

echo -e "\n=========================================="
echo "Summary:"
echo "=========================================="

if sudo systemctl is-active --quiet AlphaOps-agent && \
   sudo journalctl -u AlphaOps-agent -n 50 --no-pager | grep -q "connected" && \
   [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Agent is running and connected!"
  echo ""
  echo "If frontend doesn't show it:"
  echo "1. Deploy backend: git push origin main"
  echo "2. Or re-enroll agent in frontend"
else
  echo "❌ Agent has issues. Check the details above."
fi

echo "=========================================="
```

Run it:
```bash
chmod +x test-agent.sh
./test-agent.sh
```

## Most Common Issue

**Agent is connected, but frontend doesn't show it.**

This happens because the frontend lost track of the `agentId` (page refresh, browser closed, etc.).

**Quick Fix:**
1. Re-enroll the agent (get new install command from frontend)
2. Or wait for backend deployment with `/agent/list` endpoint

---

**TL;DR:** Run the diagnostic script above to see what's wrong!
