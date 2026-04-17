# Agent Connection Fix - Complete Guide

## The Issue

Your agent is stuck at "Waiting for agent to come online...Initializing secure verification protocol..." because:

**The install script tries to download a binary that doesn't exist. The agent is actually a Node.js script.**

## Quick Fix (5 Minutes)

### Option 1: Automated Fix (Easiest)

On your server, run:

```bash
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/AUTO_FIX_AGENT.sh | bash
```

Or download and run:

```bash
wget https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/AUTO_FIX_AGENT.sh
chmod +x AUTO_FIX_AGENT.sh
./AUTO_FIX_AGENT.sh
```

The script will:
- Install Node.js (if needed)
- Download agent files
- Install dependencies
- Start the agent
- Verify it's working

### Option 2: Manual Fix

```bash
# 1. Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Setup agent
mkdir -p ~/.alphaops && cd ~/.alphaops
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/agent.js -o agent.js
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/package.json -o package.json
npm install

# 3. Get token from AlphaOps UI and start agent
export AlphaOps_AGENT_TOKEN="your-token-here"
sudo apt-get install -y screen
screen -dmS alphaops-agent node agent.js --token "$AlphaOps_AGENT_TOKEN" --backend "https://alphaops-production.up.railway.app"

# 4. Verify
screen -r alphaops-agent  # Press Ctrl+A then D to detach
```

## Files in This Fix

| File | Purpose |
|------|---------|
| `IMMEDIATE_FIX_STEPS.md` | Quick reference guide (start here) |
| `AUTO_FIX_AGENT.sh` | Automated fix script (run on server) |
| `AGENT_CONNECTION_SOLUTION.md` | Detailed explanation and all options |
| `AGENT_STUCK_FIX.md` | Comprehensive troubleshooting guide |
| `AGENT_CONNECTION_DIAGNOSIS.sh` | Diagnostic script |
| `FIX_AGENT_CONNECTION.sh` | Semi-automated fix script |
| `alphaops-agent/install-nodejs.sh` | New Node.js-based install script |

## What to Do

### For Users (Right Now):

1. Read `IMMEDIATE_FIX_STEPS.md`
2. Run `AUTO_FIX_AGENT.sh` on your server
3. Check agent logs: `screen -r alphaops-agent`
4. Verify connection in AlphaOps UI

### For Developers (Long-Term Fix):

1. Read `AGENT_CONNECTION_SOLUTION.md`
2. Choose between:
   - **Option 1**: Use Node.js-based install (recommended)
   - **Option 2**: Build actual binaries with `pkg`
3. Update backend `/agent/install.sh` endpoint
4. Test the full flow
5. Update documentation

## Verification

After applying the fix, you should see:

### In agent logs (`screen -r alphaops-agent`):
```
AlphaOps Agent starting...
Connected to AlphaOps backend
```

### In backend logs:
```
[agent-ws] Agent connected: <agentId> (user: <userId>)
```

### In AlphaOps UI:
- Connection dialog shows "Connected"
- Agent appears in agent list
- Can execute commands

## Troubleshooting

If it still doesn't work:

1. **Run diagnostics:**
   ```bash
   bash AGENT_CONNECTION_DIAGNOSIS.sh
   ```

2. **Check agent logs:**
   ```bash
   screen -r alphaops-agent
   ```

3. **Common issues:**
   - Node.js not installed → Install Node.js 18+
   - `ws` module not found → Run `npm install` in `~/.alphaops`
   - Connection refused → Check firewall/network
   - Token invalid → Get fresh token from UI

4. **Still stuck?** Read `AGENT_STUCK_FIX.md` for detailed troubleshooting

## Technical Details

### Why This Happened

The codebase has two conflicting approaches:

1. **Binary distribution** (install.sh downloads binaries)
2. **Node.js script** (agent.js is a Node.js application)

These were never reconciled, causing the install to fail silently.

### The Fix

Either:
- **Use Node.js** (recommended): Install Node.js and run agent.js directly
- **Build binaries**: Use `pkg` to bundle Node.js + agent.js into standalone binaries

### Connection Flow

1. Frontend → `/agent/enroll` → gets token
2. User runs install command on server
3. Agent connects via WebSocket with token
4. Backend validates token, registers session
5. Frontend → `/agent/connect` → binds serverId to agentId
6. Frontend polls `/agent/status` → shows "Connected"

## Support

Need help? Provide:

1. Output of `AGENT_CONNECTION_DIAGNOSIS.sh`
2. Agent logs from `screen -r alphaops-agent`
3. Server OS: `uname -a`
4. Node.js version: `node --version`
5. Network test: `curl https://alphaops-production.up.railway.app/health`

## Quick Commands Reference

```bash
# View agent logs
screen -r alphaops-agent

# Detach from logs (without stopping)
# Press: Ctrl+A then D

# Stop agent
screen -X -S alphaops-agent quit

# Restart agent
screen -X -S alphaops-agent quit
cd ~/.alphaops
screen -dmS alphaops-agent node agent.js --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL"

# Check if agent is running
screen -list | grep alphaops-agent
ps aux | grep "node.*agent.js"

# Test backend connectivity
curl https://alphaops-production.up.railway.app/health

# Check Node.js version
node --version

# Reinstall dependencies
cd ~/.alphaops && npm install
```

## Next Steps

1. ✅ Apply the quick fix (run `AUTO_FIX_AGENT.sh`)
2. ✅ Verify agent connects
3. ✅ Test command execution
4. 📝 Implement long-term fix (update backend)
5. 📝 Update documentation
6. 📝 Test on fresh servers

## Success Criteria

- [ ] Agent installs successfully on fresh server
- [ ] Agent connects within 15 seconds
- [ ] Agent shows as "online" in UI
- [ ] Can execute commands through agent
- [ ] Agent reconnects after disconnect
- [ ] Agent survives server reboot (optional: add systemd service)

---

**Start with `IMMEDIATE_FIX_STEPS.md` for the fastest solution!**
