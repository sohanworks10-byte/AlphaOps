# Agent Connection Troubleshooting Guide

## Issue
Agent is installed on the server but not showing as connected in the frontend.

## Diagnostic Steps

### 1. Check Agent Service Status

On the server, run:
```bash
sudo systemctl status AlphaOps-agent
```

Expected output:
- Status should be "active (running)"
- Should show recent log entries

### 2. Check Agent Logs

View real-time logs:
```bash
sudo journalctl -u AlphaOps-agent -f
```

Or view recent logs:
```bash
sudo journalctl -u AlphaOps-agent -n 50
```

Look for:
- ✅ `[AlphaOps-agent] connected` - Agent successfully connected
- ❌ `ECONNREFUSED` - Cannot reach backend
- ❌ `invalid token` - Token validation failed
- ❌ `401` or `403` - Authentication error

### 3. Check Agent Configuration

View the agent config:
```bash
sudo cat /opt/AlphaOps-agent/config.env
```

Or for binary installation:
```bash
sudo cat /usr/local/etc/AlphaOps-agent.conf
```

Should contain:
```
AlphaOps_AGENT_TOKEN=<long-token-string>
AlphaOps_BACKEND_URL=https://alphaops-production.up.railway.app
```

### 4. Test Backend Connectivity

From the server, test if backend is reachable:
```bash
curl -I https://alphaops-production.up.railway.app/health
```

Expected: `HTTP/2 200` with JSON response

### 5. Check WebSocket Connection

Test WebSocket endpoint (replace TOKEN with actual token):
```bash
# Get token from config
TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env | cut -d= -f2)

# Test WebSocket (will fail but shows if endpoint is reachable)
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: test" \
  "https://alphaops-production.up.railway.app/agent/connect?token=$TOKEN"
```

Expected: `101 Switching Protocols` or connection upgrade response

## Common Issues & Solutions

### Issue 1: Agent Not Running
**Symptoms:** `systemctl status` shows "inactive (dead)"

**Solution:**
```bash
# Restart the service
sudo systemctl restart AlphaOps-agent

# Check logs for errors
sudo journalctl -u AlphaOps-agent -n 50
```

### Issue 2: Connection Refused
**Symptoms:** Logs show `ECONNREFUSED` or `connect ETIMEDOUT`

**Possible Causes:**
1. Backend is down or not deployed
2. Firewall blocking outbound connections
3. Wrong backend URL

**Solution:**
```bash
# Test backend connectivity
curl https://alphaops-production.up.railway.app/health

# If fails, check firewall
sudo ufw status

# Allow outbound HTTPS if needed
sudo ufw allow out 443/tcp
```

### Issue 3: Invalid Token
**Symptoms:** Logs show "invalid token" or "reject: invalid token"

**Possible Causes:**
1. Token expired (unlikely, 1 year TTL)
2. Agent secret mismatch between frontend and backend
3. Token not properly generated

**Solution:**
```bash
# Generate new enrollment code in frontend
# Then reinstall agent with new code

# Stop existing agent
sudo systemctl stop AlphaOps-agent

# Run install script with new code
u="https://alphaops-production.up.railway.app/agent/install.sh?code=NEW_CODE"
curl -fsSL "$u" | sudo bash
```

### Issue 4: Agent Secret Mismatch
**Symptoms:** Token validation fails on backend

**Check Backend Environment:**
Ensure Railway has `AlphaOps_AGENT_SECRET` set to:
```
847c3010-5ba6-40d5-973b-134931614543853e63b9-e97e-466b-9d7f-0f46bc7247b2
```

### Issue 5: WebSocket Upgrade Fails
**Symptoms:** Connection closes immediately after connecting

**Check Backend Logs:**
In Railway dashboard, check for:
- `[agent-ws] upgrade received` - WebSocket upgrade attempted
- `[agent-ws] reject: invalid token` - Token validation failed
- `[agent-ws] connected` - Successful connection

### Issue 6: Running Install Script Multiple Times
**Symptoms:** Second run hangs or does nothing

**Explanation:** 
- First run installs and starts the service
- Second run detects existing installation and exits early
- This is normal behavior

**To Force Reinstall:**
```bash
# Stop and remove existing service
sudo systemctl stop AlphaOps-agent
sudo systemctl disable AlphaOps-agent
sudo rm /etc/systemd/system/AlphaOps-agent.service
sudo systemctl daemon-reload

# Remove installation
sudo rm -rf /opt/AlphaOps-agent
sudo rm -f /usr/local/bin/AlphaOps-agent

# Run install script again
u="https://alphaops-production.up.railway.app/agent/install.sh?code=YOUR_CODE"
curl -fsSL "$u" | sudo bash
```

## Frontend Connection Status

### Check in Frontend

1. Go to the Agents/Servers page
2. Look for your server in the list
3. Status should show "Connected" with green indicator

### If Not Showing

1. **Refresh the page** - Frontend polls every 5 seconds
2. **Check browser console** - Look for API errors
3. **Check agent ID** - Ensure frontend is looking for the correct agent

## Backend Verification

### Check Agent Registration

In Railway logs, look for:
```
[agent-ws] connected
```

This confirms the agent successfully connected to the backend.

### Check Active Sessions

The backend maintains active agent sessions in memory. If the backend restarts, agents will automatically reconnect.

## Network Requirements

### Outbound Connections Required

The agent needs to make outbound connections to:
- `alphaops-production.up.railway.app:443` (HTTPS)
- WebSocket upgrade on same domain

### Firewall Rules

If using UFW:
```bash
# Allow outbound HTTPS
sudo ufw allow out 443/tcp

# Check status
sudo ufw status
```

If using iptables:
```bash
# Allow outbound HTTPS
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
```

## Quick Diagnostic Script

Run this on the server to get all diagnostic info:
```bash
#!/bin/bash
echo "=== Agent Service Status ==="
sudo systemctl status AlphaOps-agent --no-pager

echo -e "\n=== Recent Logs ==="
sudo journalctl -u AlphaOps-agent -n 20 --no-pager

echo -e "\n=== Configuration ==="
if [ -f /opt/AlphaOps-agent/config.env ]; then
  echo "Token: $(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env | cut -d= -f2 | cut -c1-20)..."
  echo "Backend: $(sudo grep AlphaOps_BACKEND_URL /opt/AlphaOps-agent/config.env | cut -d= -f2)"
fi

echo -e "\n=== Backend Connectivity ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://alphaops-production.up.railway.app/health

echo -e "\n=== Network ==="
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
```

Save as `agent-diag.sh`, make executable, and run:
```bash
chmod +x agent-diag.sh
./agent-diag.sh
```

## Still Not Working?

If the agent still won't connect after trying all the above:

1. **Check Railway deployment** - Ensure backend is running and healthy
2. **Verify environment variables** - All required vars set in Railway
3. **Check backend logs** - Look for WebSocket connection attempts
4. **Try a different server** - Rule out server-specific issues
5. **Contact support** - Provide output from diagnostic script

---

**Most Common Fix:** Restart the agent service
```bash
sudo systemctl restart AlphaOps-agent
sudo journalctl -u AlphaOps-agent -f
```
