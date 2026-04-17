# Agent Connection Debug Steps

## The Problem

The agent is installed and running on the server, but the frontend doesn't show it as connected.

## Why This Happens

The frontend needs to know the `agentId` to check if an agent is online. When you enroll an agent:

1. Frontend calls `/agent/enroll` → gets back `agentId` and install command
2. You run the install command on the server
3. Agent connects to backend via WebSocket
4. Frontend polls `/agent/status?agentId=xxx` to check if it's online

**The issue:** If you close the frontend or refresh the page, it loses the `agentId` and can't check status anymore.

## Solution 1: Use the New List Endpoint (After Deployment)

I've added a new endpoint `/agent/list` that returns all connected agents for your user.

**After deploying the backend**, you can test it:

```bash
# Get your access token from browser console
# Then test the endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://alphaops-production.up.railway.app/agent/list
```

This will return all your connected agents with their IDs.

## Solution 2: Check Agent Status Manually

### On the Server:

```bash
# Check if agent is running
sudo systemctl status AlphaOps-agent

# View logs
sudo journalctl -u AlphaOps-agent -n 50

# Look for this line:
# [AlphaOps-agent] connected
```

### Get the Agent ID:

```bash
# Extract token from config
TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env | cut -d= -f2)

# Decode the token to get agentId (it's in the JWT payload)
echo $TOKEN | cut -d. -f1 | base64 -d 2>/dev/null | jq -r '.agentId'
```

### Check Backend Logs:

In Railway dashboard, look for:
```
[agent-ws] connected
```

This confirms the agent is connected to the backend.

## Solution 3: Re-enroll the Agent

The easiest fix is to re-enroll:

1. **In Frontend:** Click "Enroll Agent" to get a new code
2. **On Server:** Stop and remove existing agent:
   ```bash
   sudo systemctl stop AlphaOps-agent
   sudo systemctl disable AlphaOps-agent
   sudo rm /etc/systemd/system/AlphaOps-agent.service
   sudo rm -rf /opt/AlphaOps-agent
   sudo rm -f /usr/local/bin/AlphaOps-agent
   sudo systemctl daemon-reload
   ```
3. **Run new install command** with the new code
4. **Frontend will now track this agent** and show it as connected

## Solution 4: Check Backend Deployment

Make sure the backend is deployed with all the latest fixes:

```bash
# Deploy the backend
git add .
git commit -m "Add agent list endpoint and fix connections"
git push origin main
```

Wait 2-3 minutes for Railway to deploy, then:

```bash
# Test backend health
curl https://alphaops-production.up.railway.app/health

# Should return: {"ok":true}
```

## Quick Diagnostic Commands

Run these on your server to verify everything:

```bash
#!/bin/bash
echo "=== Agent Service Status ==="
sudo systemctl is-active AlphaOps-agent

echo -e "\n=== Agent Process ==="
ps aux | grep AlphaOps-agent | grep -v grep

echo -e "\n=== Recent Logs (last 10 lines) ==="
sudo journalctl -u AlphaOps-agent -n 10 --no-pager

echo -e "\n=== Configuration ==="
if [ -f /opt/AlphaOps-agent/config.env ]; then
  echo "Config file exists"
  echo "Backend URL: $(sudo grep AlphaOps_BACKEND_URL /opt/AlphaOps-agent/config.env | cut -d= -f2)"
else
  echo "Config file not found"
fi

echo -e "\n=== Backend Connectivity ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://alphaops-production.up.railway.app/health

echo -e "\n=== WebSocket Test ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://alphaops-production.up.railway.app/agent/connect
```

## Expected Results

### Agent Running:
```
=== Agent Service Status ===
active

=== Agent Process ===
root ... node /opt/AlphaOps-agent/agent.js

=== Recent Logs ===
[AlphaOps-agent] connected

=== Backend Connectivity ===
HTTP Status: 200
```

### Agent Not Connected:
```
=== Recent Logs ===
ECONNREFUSED
```
→ Backend is down or not reachable

```
=== Recent Logs ===
invalid token
```
→ Token validation failed, need to re-enroll

## Frontend Detection

The frontend checks agent status by:

1. Storing `agentId` when you click "Enroll Agent"
2. Polling `/agent/status?agentId=xxx` every 5 seconds
3. Showing "Connected" if `online: true`

If you refreshed the page or closed the frontend, it lost the `agentId`. The new `/agent/list` endpoint solves this by letting the frontend discover all connected agents.

## Next Steps

1. **Deploy backend** with the new `/agent/list` endpoint
2. **Update frontend** to call `/agent/list` on page load
3. **Or re-enroll** the agent to get a fresh connection tracked by frontend

---

**Quick Fix:** Re-enroll the agent (Solution 3 above)
