# Quick Fix for Agent Connection

## Run These Commands on Your Server

### 1. Check if agent is running:
```bash
sudo systemctl status AlphaOps-agent
```

### 2. View agent logs:
```bash
sudo journalctl -u AlphaOps-agent -n 50
```

### 3. If you see errors, restart the agent:
```bash
sudo systemctl restart AlphaOps-agent
```

### 4. Watch logs in real-time:
```bash
sudo journalctl -u AlphaOps-agent -f
```

Look for:
- ✅ `[AlphaOps-agent] connected` = SUCCESS
- ❌ `ECONNREFUSED` = Backend not reachable
- ❌ `invalid token` = Token problem

## Most Likely Issue

The backend on Railway probably hasn't been deployed yet with the latest fixes. 

**You need to deploy the backend first:**

```bash
# On your local machine:
git add .
git commit -m "Fix Railway: add missing controllers and agent connection"
git push origin main
```

Then wait for Railway to deploy (2-3 minutes), then try the agent install again.

## If Agent Still Won't Connect

### Option 1: Force Reinstall
```bash
# Stop existing agent
sudo systemctl stop AlphaOps-agent
sudo systemctl disable AlphaOps-agent
sudo rm /etc/systemd/system/AlphaOps-agent.service
sudo systemctl daemon-reload

# Remove old installation
sudo rm -rf /opt/AlphaOps-agent
sudo rm -f /usr/local/bin/AlphaOps-agent

# Get NEW enrollment code from frontend
# Then run install script with new code
u="https://alphaops-production.up.railway.app/agent/install.sh?code=NEW_CODE"
curl -fsSL "$u" | sudo bash
```

### Option 2: Check Backend Health
```bash
curl https://alphaops-production.up.railway.app/health
```

Should return: `{"ok":true}`

If it returns an error, the backend isn't deployed yet.

## Why Running Install Twice Doesn't Work

The install script detects an existing installation and exits early. This is normal. To reinstall, you must first remove the existing installation (see Option 1 above).
