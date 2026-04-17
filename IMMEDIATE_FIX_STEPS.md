# Immediate Fix Steps - Agent Connection Issue

## TL;DR - The Problem

The install script tries to download a **binary** that doesn't exist. The agent is actually a **Node.js script** that needs Node.js to run.

## Quick Fix (Do This Now)

### On Your Server:

Run these commands to manually install and start the agent:

```bash
# 1. Install Node.js (if not already installed)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Verify Node.js is installed
node --version  # Should show v20.x.x or higher

# 3. Create agent directory
mkdir -p ~/.alphaops
cd ~/.alphaops

# 4. Download agent files
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/agent.js -o agent.js
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/package.json -o package.json

# 5. Install dependencies
npm install

# 6. Get your token from the AlphaOps UI (shown in the connection dialog)
# Replace YOUR_TOKEN_HERE with the actual token
export AlphaOps_AGENT_TOKEN="YOUR_TOKEN_HERE"
export AlphaOps_BACKEND_URL="https://alphaops-production.up.railway.app"

# 7. Install screen (if not installed)
sudo apt-get update && sudo apt-get install -y screen

# 8. Stop any existing agent
screen -X -S alphaops-agent quit 2>/dev/null || true

# 9. Start the agent
screen -dmS alphaops-agent node agent.js --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL"

# 10. Verify it's running
screen -r alphaops-agent
# You should see: "AlphaOps Agent starting..." and "Connected to AlphaOps backend"
# Press Ctrl+A then D to detach
```

### Expected Output:

When you attach to the screen session (`screen -r alphaops-agent`), you should see:

```
AlphaOps Agent starting...
Connected to AlphaOps backend
```

If you see this, the agent is working! Go back to the AlphaOps UI and the connection should complete within 10-15 seconds.

## If It Still Doesn't Work

### Check for errors:

```bash
# View agent logs
screen -r alphaops-agent

# Common errors and solutions:

# Error: "Missing AlphaOps_AGENT_TOKEN"
# → Make sure you exported the token correctly

# Error: "WebSocket error: connect ECONNREFUSED"
# → Check network connectivity: curl https://alphaops-production.up.railway.app/health

# Error: "Cannot find module 'ws'"
# → Run: cd ~/.alphaops && npm install

# Error: "node: command not found"
# → Install Node.js (step 1 above)
```

### Verify each component:

```bash
# 1. Node.js installed?
node --version

# 2. Agent files exist?
ls -la ~/.alphaops/

# 3. Dependencies installed?
ls ~/.alphaops/node_modules/ws

# 4. Agent running?
screen -list | grep alphaops-agent

# 5. Backend reachable?
curl https://alphaops-production.up.railway.app/health
```

## Long-Term Fix (For Developers)

To fix this permanently in the codebase, you need to update the backend to serve the Node.js-based install script instead of trying to download binaries.

### Option A: Use the new Node.js install script

1. The new script is at: `alphaops-agent/install-nodejs.sh`
2. Update `backend/src/index.js` endpoint `/agent/install.sh` to serve this script
3. Test the full flow

### Option B: Build actual binaries

1. Use `pkg` to bundle Node.js + agent.js into binaries
2. Upload to GitHub releases
3. Update environment variables with correct URLs

See `AGENT_CONNECTION_SOLUTION.md` for detailed instructions.

## Testing Checklist

After implementing the fix:

- [ ] Fresh server can install agent successfully
- [ ] Agent connects to backend within 15 seconds
- [ ] Agent appears as "online" in frontend
- [ ] Can execute commands through the agent
- [ ] Agent reconnects after disconnect
- [ ] Agent survives server reboot (if using systemd)

## Common Questions

**Q: Why does the install script download a binary?**  
A: The install script was written for binary distribution, but the binaries were never built/uploaded to GitHub releases.

**Q: Can I just fix the binary URLs?**  
A: No, because the binaries don't exist. You need to either build them (using `pkg`) or switch to the Node.js-based install.

**Q: Will this work on ARM servers?**  
A: Yes, as long as Node.js supports the architecture. Node.js has better architecture support than maintaining separate binaries.

**Q: Do I need to keep Node.js installed?**  
A: Yes, if using the Node.js-based approach. If you want to avoid this, build actual binaries using `pkg`.

**Q: What about security?**  
A: The Node.js approach is actually more secure because:
- Source code is visible (can audit)
- Dependencies are explicit (package.json)
- Easier to update/patch vulnerabilities

## Support

If you're still stuck:

1. Run the diagnostic script: `bash AGENT_CONNECTION_DIAGNOSIS.sh`
2. Check agent logs: `screen -r alphaops-agent`
3. Check backend logs (if you have access)
4. Provide the output of all the verification commands above

## Files Created

- `AGENT_CONNECTION_SOLUTION.md` - Detailed explanation and all options
- `AGENT_STUCK_FIX.md` - Troubleshooting guide
- `AGENT_CONNECTION_DIAGNOSIS.sh` - Diagnostic script
- `FIX_AGENT_CONNECTION.sh` - Automated fix script
- `alphaops-agent/install-nodejs.sh` - New Node.js-based install script
- `IMMEDIATE_FIX_STEPS.md` - This file (quick reference)

Start with this file for the quickest fix, then read the others for more details.
