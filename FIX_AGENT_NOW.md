# Fix Agent Connection NOW

## The Issue

Frontend shows "Waiting for agent to come online..." but the agent never connects.

## Most Likely Cause

**The backend hasn't been deployed yet with all the fixes!**

## Step-by-Step Fix

### Step 1: Deploy the Backend (REQUIRED)

On your local machine where you have the code:

```bash
# Make sure all changes are committed
git add .
git commit -m "Fix agent connection and add missing controllers"
git push origin main
```

**Wait 2-3 minutes** for Railway to deploy.

### Step 2: Verify Backend is Deployed

```bash
curl https://alphaops-production.up.railway.app/health
```

Expected response: `{"ok":true,"service":"AlphaOps Backend","version":"1.0.0"}`

If you get an error or different response, the backend isn't deployed yet. Wait longer.

### Step 3: Run Diagnostic on Server

On your Ubuntu server, run:

```bash
# Download and run diagnostic script
curl -fsSL https://raw.githubusercontent.com/yourusername/yourrepo/main/DIAGNOSE_NOW.sh | bash
```

Or manually:

```bash
# Check if agent is running
sudo systemctl status AlphaOps-agent

# Check logs
sudo journalctl -u AlphaOps-agent -n 50

# Look for:
# ✓ "[AlphaOps-agent] connected" = SUCCESS
# ✗ "ECONNREFUSED" = Backend not reachable
# ✗ "invalid token" = Need to re-enroll
```

### Step 4: If Agent Shows "connected" in Logs

The agent IS connected! The issue is the frontend doesn't know the agentId.

**Solution: Re-enroll the agent**

1. **Stop existing agent:**
   ```bash
   sudo systemctl stop AlphaOps-agent
   sudo systemctl disable AlphaOps-agent
   sudo rm /etc/systemd/system/AlphaOps-agent.service
   sudo rm -rf /opt/AlphaOps-agent
   sudo rm -f /usr/local/bin/AlphaOps-agent
   sudo systemctl daemon-reload
   ```

2. **In frontend:** Click "Enroll Agent" to get NEW install command

3. **Run new install command** on server

4. **Frontend will now detect it!**

### Step 5: If Agent Shows "ECONNREFUSED"

Backend is not reachable. This means:
- Backend not deployed yet (go back to Step 1)
- Firewall blocking connection
- Wrong backend URL

**Check:**
```bash
# Test from server
curl https://alphaops-production.up.railway.app/health

# If this fails, backend is not reachable
```

### Step 6: If Agent Shows "invalid token"

Token validation failed. This means:
- Agent secret mismatch
- Token format issue

**Fix: Re-enroll with new token** (see Step 4)

## Quick Diagnostic Commands

Run these on your server:

```bash
# 1. Is agent running?
sudo systemctl is-active AlphaOps-agent

# 2. What do logs say?
sudo journalctl -u AlphaOps-agent -n 20 | grep -E "connected|error|ECONNREFUSED|invalid"

# 3. Can server reach backend?
curl -I https://alphaops-production.up.railway.app/health

# 4. Restart agent
sudo systemctl restart AlphaOps-agent && sudo journalctl -u AlphaOps-agent -f
```

## Common Mistakes

### Mistake 1: Not Deploying Backend First

The backend MUST be deployed with all the fixes before the agent can connect.

**Fix:** Deploy backend (Step 1)

### Mistake 2: Using Old Install Command

If you generated the install command before deploying the backend, it might have issues.

**Fix:** Generate NEW install command after backend is deployed

### Mistake 3: Running Install Command Multiple Times

The install script detects existing installation and exits. This is normal.

**Fix:** Remove existing installation first (see Step 4)

### Mistake 4: Firewall Blocking Outbound HTTPS

The agent needs to connect to Railway on port 443.

**Fix:**
```bash
# Check firewall
sudo ufw status

# Allow outbound HTTPS if needed
sudo ufw allow out 443/tcp
```

## Expected Timeline

1. **Deploy backend:** 2-3 minutes
2. **Install agent:** 30 seconds
3. **Agent connects:** Immediate
4. **Frontend detects:** 3-5 seconds (polling interval)

## Still Not Working?

If you've done all the above and it still doesn't work:

1. **Check Railway logs:**
   - Go to Railway dashboard
   - View deployment logs
   - Look for "AlphaOps backend listening on [port]"
   - Look for "[agent-ws] connected"

2. **Check browser console:**
   - Open DevTools (F12)
   - Look for errors in Console tab
   - Check Network tab for failed requests

3. **Get agent ID manually:**
   ```bash
   # On server
   TOKEN=$(sudo grep AlphaOps_AGENT_TOKEN /opt/AlphaOps-agent/config.env | cut -d= -f2)
   
   # Install jq if needed
   sudo apt-get install -y jq
   
   # Decode agent ID
   echo $TOKEN | cut -d. -f1 | base64 -d | jq -r '.agentId'
   ```
   
   Then use this agentId to manually check status in frontend.

## The Nuclear Option: Complete Reinstall

If nothing else works:

```bash
# On server: Remove everything
sudo systemctl stop AlphaOps-agent
sudo systemctl disable AlphaOps-agent
sudo rm /etc/systemd/system/AlphaOps-agent.service
sudo rm -rf /opt/AlphaOps-agent
sudo rm -f /usr/local/bin/AlphaOps-agent
sudo rm -rf /var/log/AlphaOps-agent
sudo systemctl daemon-reload

# On local machine: Deploy backend
git push origin main

# Wait 3 minutes

# In frontend: Generate new install command

# On server: Run new install command

# Watch logs
sudo journalctl -u AlphaOps-agent -f
```

---

**TL;DR:**
1. Deploy backend: `git push origin main`
2. Wait 3 minutes
3. Re-enroll agent in frontend
4. Run new install command on server
5. Should work!
