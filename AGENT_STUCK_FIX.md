# Agent Stuck at "Waiting for agent to come online" - Fix Guide

## Problem
The agent is stuck at "Waiting for agent to come online...Initializing secure verification protocol..." even after running the install command on the server.

## Root Causes

There are several possible reasons:

1. **Agent not actually running** - The install script may have failed silently
2. **WebSocket connection failure** - Network/firewall blocking the connection
3. **Token mismatch** - Agent using wrong token or token expired
4. **Backend not receiving agent connection** - Agent connects but backend doesn't register it
5. **Agent binary not executable** - Permission or architecture issues

## Diagnostic Steps

### Step 1: Run the diagnostic script on your server

```bash
# On your server, run:
bash AGENT_CONNECTION_DIAGNOSIS.sh
```

### Step 2: Check agent logs

```bash
# Attach to the agent screen session to see live logs
screen -r alphaops-agent

# To detach without stopping: Press Ctrl+A then D
```

### Step 3: Check if agent is actually connecting

Look for these messages in the agent logs:
- `[AlphaOps-agent] starting` - Agent is starting
- `[AlphaOps-agent] connected` - WebSocket connection established
- Any error messages about connection refused, timeout, or authentication

## Solutions

### Solution 1: Restart the agent (Most Common Fix)

```bash
# On your server:

# 1. Stop the existing agent
screen -X -S alphaops-agent quit

# 2. Wait a few seconds
sleep 3

# 3. Re-run the install command from the frontend
# (Copy the command from the AlphaOps UI)
```

### Solution 2: Manual agent start (if install script fails)

```bash
# On your server:

cd ~/.alphaops

# Make sure binary is executable
chmod +x alphaops-agent

# Get your token from the frontend (shown in the connection dialog)
export AlphaOps_AGENT_TOKEN="your-token-here"
export AlphaOps_BACKEND_URL="https://alphaops-production.up.railway.app"

# Start agent in screen
screen -dmS alphaops-agent ./alphaops-agent --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL"

# Check if it's running
screen -r alphaops-agent
```

### Solution 3: Check backend connectivity

```bash
# On your server, test if you can reach the backend:

# Test HTTPS
curl -v https://alphaops-production.up.railway.app/health

# Test WebSocket upgrade
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: test" \
  https://alphaops-production.up.railway.app/agent/connect
```

If these fail, you may have firewall/network issues.

### Solution 4: Verify token is correct

The token shown in the frontend must match what the agent is using.

```bash
# On your server, check what token the agent is using:
ps aux | grep alphaops-agent | grep -o '\--token [^ ]*'

# Compare this with the token shown in the frontend UI
```

### Solution 5: Check for architecture mismatch

```bash
# On your server:
uname -m

# Should be:
# - x86_64 (for AMD64)
# - aarch64 or arm64 (for ARM64)

# If the binary doesn't match your architecture, download the correct one:
cd ~/.alphaops
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    curl -L -o alphaops-agent https://github.com/sohanworks10-byte/AlphaOps/releases/latest/download/alphaops-agent-linux-amd64
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    curl -L -o alphaops-agent https://github.com/sohanworks10-byte/AlphaOps/releases/latest/download/alphaops-agent-linux-arm64
fi
chmod +x alphaops-agent
```

## Backend-Side Checks

### Check if agent is connecting to backend

Look at backend logs for:

```
[agent-ws] Agent connected: <agentId> (user: <userId>)
```

If you see this, the agent IS connecting, but the binding might be failing.

### Check agent session registration

In the backend code (`backend/src/agent-connection.js`), the flow is:

1. Agent connects via WebSocket with token
2. Token is validated
3. Session is registered
4. Frontend calls `/agent/connect` to bind serverId to agentId
5. Frontend polls `/agent/status` to check if online

### Common backend issues:

1. **Token validation failing** - Check `AlphaOps_AGENT_SECRET` env var
2. **Session not persisting** - Agent connects but session is immediately removed
3. **Binding failing** - `/agent/connect` endpoint not working

## Quick Fix Commands

### On the server (run these in order):

```bash
# 1. Kill any existing agent
screen -X -S alphaops-agent quit
pkill -f alphaops-agent

# 2. Clean up
rm -rf ~/.alphaops

# 3. Re-run the install command from the frontend
# (The command will look like: curl -fsSL "https://..." | sudo bash)
```

### In the frontend:

1. Click "Cancel" on the stuck connection dialog
2. Click "Add Agent" again to get a fresh token
3. Copy the new install command
4. Run it on your server
5. Wait 10-15 seconds for the agent to connect

## Still Not Working?

### Enable debug logging on the agent

Modify the agent to add more logging:

```bash
# On your server:
cd ~/.alphaops

# Edit the agent startup to add debug output
screen -dmS alphaops-agent bash -c './alphaops-agent --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL" 2>&1 | tee -a agent-debug.log'

# Then check the log
tail -f ~/.alphaops/agent-debug.log
```

### Check backend logs

If you have access to the backend (Railway):

```bash
# Check for agent connection attempts
railway logs | grep -i agent

# Look for:
# - WebSocket upgrade requests
# - Token validation errors
# - Session registration
```

### Network debugging

```bash
# On your server, capture WebSocket traffic:
sudo tcpdump -i any -A 'host alphaops-production.up.railway.app and port 443' -w /tmp/agent-traffic.pcap

# Then analyze with:
tcpdump -r /tmp/agent-traffic.pcap -A | grep -i websocket
```

## Prevention

To avoid this issue in the future:

1. **Always check agent logs** before assuming it's stuck
2. **Wait at least 15 seconds** after running install command
3. **Don't run multiple install commands** simultaneously
4. **Ensure stable network connection** on the server
5. **Keep the agent binary updated** to the latest version

## Technical Details

### Connection Flow

1. Frontend calls `/agent/enroll` → gets `{ agentId, token, code, installCommand }`
2. User runs `installCommand` on server
3. Install script downloads agent binary
4. Agent starts and connects to `wss://backend/agent/connect?token=<token>`
5. Backend validates token, registers session
6. Frontend calls `/agent/connect` with `agentId` to bind `serverId`
7. Frontend polls `/agent/status` until `online: true`

### Where it can fail

- **Step 3**: Download fails (network, GitHub rate limit)
- **Step 4**: Agent can't start (permissions, architecture mismatch)
- **Step 4**: WebSocket connection fails (firewall, network)
- **Step 5**: Token validation fails (wrong secret, expired token)
- **Step 6**: Binding fails (userId mismatch, agent offline)
- **Step 7**: Status check fails (agent disconnected between steps)

## Contact Support

If none of these solutions work, provide:

1. Output of `AGENT_CONNECTION_DIAGNOSIS.sh`
2. Agent logs from `screen -r alphaops-agent`
3. Backend logs (if accessible)
4. Server OS and architecture (`uname -a`)
5. Network setup (any proxies, firewalls, etc.)
