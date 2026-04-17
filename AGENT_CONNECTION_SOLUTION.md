# Agent Connection Solution - Root Cause Found

## The Problem

The agent is stuck at "Waiting for agent to come online" because of a **fundamental mismatch** between the install script and the actual agent implementation:

### What's Happening:

1. **Install script** (`alphaops-agent/install.sh`) tries to download a **binary** from GitHub releases:
   - `alphaops-agent-linux-amd64`
   - `alphaops-agent-linux-arm64`

2. **Actual agent** (`alphaops-agent/agent.js`) is a **Node.js script** that requires:
   - Node.js runtime (>= 18)
   - `ws` npm package
   - Cannot run as a standalone binary

3. **Result**: The install script either:
   - Downloads a non-existent binary (404 error)
   - Downloads an improperly built binary
   - Binary exists but doesn't have Node.js bundled

## The Solution

You have **three options** to fix this:

---

## Option 1: Fix the Install Script (Recommended for Production)

Modify the install script to install Node.js and run the agent as a Node.js script instead of a binary.

### Create a new install script:

```bash
#!/bin/bash
set -e

echo "=========================================="
echo "   AlphaOps Agent Installation"
echo "=========================================="

# Parse arguments
TOKEN=""
BACKEND="https://alphaops-production.up.railway.app"

while [[ $# -gt 0 ]]; do
  case $1 in
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$TOKEN" ]; then
  echo "Error: --token is required"
  exit 1
fi

echo "✓ Token received"

# Install Node.js if not present
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

NODE_VERSION=$(node --version)
echo "✓ Node.js installed: $NODE_VERSION"

# Create install directory
INSTALL_DIR="$HOME/.alphaops"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download agent files
echo "✓ Downloading agent..."
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/agent.js -o agent.js
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/package.json -o package.json

# Install dependencies
echo "✓ Installing dependencies..."
npm install --production

# Install screen if not present
if ! command -v screen >/dev/null 2>&1; then
    echo "Installing screen..."
    sudo apt-get update && sudo apt-get install -y screen
fi

# Stop existing agent
if screen -list | grep -q "alphaops-agent"; then
    echo "✓ Stopping existing agent..."
    screen -X -S alphaops-agent quit || true
    sleep 2
fi

# Start agent in screen session
echo "✓ Starting agent..."
screen -dmS alphaops-agent node agent.js --token "$TOKEN" --backend "$BACKEND"

sleep 2

# Verify it's running
if screen -list | grep -q "alphaops-agent"; then
    echo ""
    echo "=========================================="
    echo "   Installation Complete!"
    echo "=========================================="
    echo "Agent is running in screen session 'alphaops-agent'"
    echo ""
    echo "To view logs: screen -r alphaops-agent"
    echo "To detach: Press Ctrl+A then D"
    echo "=========================================="
else
    echo ""
    echo "Error: Agent failed to start"
    echo "Try running manually:"
    echo "  cd ~/.alphaops"
    echo "  node agent.js --token \"$TOKEN\" --backend \"$BACKEND\""
    exit 1
fi
```

### Update the backend to serve this new script:

In `backend/src/index.js`, update the `/agent/install.sh` endpoint to serve the Node.js-based install script instead of the binary-based one.

---

## Option 2: Build Actual Binaries (For Binary Distribution)

If you want to distribute actual binaries, you need to:

### 1. Use a tool like `pkg` to bundle Node.js + agent.js:

```bash
cd alphaops-agent

# Install pkg
npm install -g pkg

# Build binaries
pkg agent.js --targets node18-linux-x64,node18-linux-arm64 --output dist/alphaops-agent

# This creates:
# - dist/alphaops-agent-linux-x64
# - dist/alphaops-agent-linux-arm64
```

### 2. Upload to GitHub Releases:

```bash
# Create a release and upload the binaries
gh release create v1.0.0 \
  dist/alphaops-agent-linux-x64#alphaops-agent-linux-amd64 \
  dist/alphaops-agent-linux-arm64#alphaops-agent-linux-arm64
```

### 3. Update `.env.example` with correct URLs:

```env
AlphaOps_AGENT_BINARY_URL_LINUX_AMD64=https://github.com/sohanworks10-byte/AlphaOps/releases/download/v1.0.0/alphaops-agent-linux-amd64
AlphaOps_AGENT_BINARY_URL_LINUX_ARM64=https://github.com/sohanworks10-byte/AlphaOps/releases/download/v1.0.0/alphaops-agent-linux-arm64
```

---

## Option 3: Quick Manual Fix (For Testing Now)

If you need to get the agent working **right now** on your server:

### On your server, run these commands:

```bash
# 1. Install Node.js (if not installed)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Create agent directory
mkdir -p ~/.alphaops
cd ~/.alphaops

# 3. Download agent files
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/agent.js -o agent.js
curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/package.json -o package.json

# 4. Install dependencies
npm install

# 5. Get your token from the AlphaOps UI
export AlphaOps_AGENT_TOKEN="your-token-here"
export AlphaOps_BACKEND_URL="https://alphaops-production.up.railway.app"

# 6. Install screen
sudo apt-get update && sudo apt-get install -y screen

# 7. Start agent
screen -dmS alphaops-agent node agent.js --token "$AlphaOps_AGENT_TOKEN" --backend "$AlphaOps_BACKEND_URL"

# 8. Verify it's running
screen -r alphaops-agent
# (Press Ctrl+A then D to detach)
```

---

## Verification

After implementing any of the above solutions, verify the agent is working:

### 1. Check agent logs:

```bash
screen -r alphaops-agent
```

You should see:
```
AlphaOps Agent starting...
Connected to AlphaOps backend
```

### 2. Check backend logs:

Look for:
```
[agent-ws] Agent connected: <agentId> (user: <userId>)
```

### 3. In the frontend:

The "Waiting for agent to come online" should change to "Connected" within 10-15 seconds.

---

## Why This Happened

The codebase has **two different approaches** mixed together:

1. **Binary distribution** (install.sh tries to download binaries)
2. **Node.js script** (agent.js is a Node.js script)

These were never reconciled, causing the install script to fail silently or download non-existent binaries.

---

## Recommended Long-Term Fix

**Option 1** (Node.js-based install) is recommended because:

1. ✅ No need to build/maintain binaries
2. ✅ Easier to update (just push to GitHub)
3. ✅ Works on all architectures Node.js supports
4. ✅ Smaller download size
5. ✅ Easier to debug (source code visible)

**Option 2** (Binary distribution) is better if:

1. You want users without Node.js to run the agent
2. You want faster startup times
3. You want to hide source code
4. You're willing to maintain build pipeline

---

## Implementation Checklist

- [ ] Choose Option 1, 2, or 3
- [ ] Update install script (Option 1 or 2)
- [ ] Update backend `/agent/install.sh` endpoint
- [ ] Test on a fresh server
- [ ] Update documentation
- [ ] Update `.env.example` with correct URLs
- [ ] Create GitHub release with binaries (if Option 2)
- [ ] Test the full flow: enroll → install → connect

---

## Need Help?

If you're still stuck after trying these solutions:

1. Check if Node.js is installed: `node --version`
2. Check if agent files exist: `ls -la ~/.alphaops/`
3. Check agent logs: `screen -r alphaops-agent`
4. Check network: `curl https://alphaops-production.up.railway.app/health`
5. Check backend logs for agent connection attempts

Provide the output of these commands for further debugging.
