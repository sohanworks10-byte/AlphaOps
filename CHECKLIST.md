# Agent Connection Fix - Action Checklist

## Immediate Actions (Do This Now)

### On Your Server:

- [ ] **Step 1**: Download the auto-fix script
  ```bash
  curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/AUTO_FIX_AGENT.sh -o fix-agent.sh
  chmod +x fix-agent.sh
  ```

- [ ] **Step 2**: Get your token from the AlphaOps UI
  - Open AlphaOps desktop app
  - Click "Add Agent" or try to connect
  - Copy the token shown in the dialog

- [ ] **Step 3**: Run the fix script
  ```bash
  export AlphaOps_AGENT_TOKEN="your-token-here"
  ./fix-agent.sh
  ```

- [ ] **Step 4**: Verify agent is running
  ```bash
  screen -r alphaops-agent
  # Should see: "Connected to AlphaOps backend"
  # Press Ctrl+A then D to detach
  ```

- [ ] **Step 5**: Check in AlphaOps UI
  - Connection should complete within 15 seconds
  - Agent should show as "online"

## If It Doesn't Work

- [ ] **Check Node.js**
  ```bash
  node --version  # Should be v18.x or higher
  ```

- [ ] **Check agent files**
  ```bash
  ls -la ~/.alphaops/
  # Should see: agent.js, package.json, node_modules/
  ```

- [ ] **Check agent logs**
  ```bash
  screen -r alphaops-agent
  # Look for error messages
  ```

- [ ] **Check network**
  ```bash
  curl https://alphaops-production.up.railway.app/health
  # Should return: {"ok":true}
  ```

- [ ] **Run diagnostics**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/AGENT_CONNECTION_DIAGNOSIS.sh | bash
  ```

## For Developers (Long-Term Fix)

### Backend Changes:

- [ ] **Read the solution document**
  - Open `AGENT_CONNECTION_SOLUTION.md`
  - Choose Option 1 (Node.js) or Option 2 (Binaries)

- [ ] **Option 1: Node.js-based install (Recommended)**
  - [ ] Update `/agent/install.sh` endpoint in `backend/src/index.js`
  - [ ] Serve the new `alphaops-agent/install-nodejs.sh` script
  - [ ] Test on a fresh server
  - [ ] Update documentation

- [ ] **Option 2: Build binaries**
  - [ ] Install `pkg`: `npm install -g pkg`
  - [ ] Build binaries:
    ```bash
    cd alphaops-agent
    pkg agent.js --targets node18-linux-x64,node18-linux-arm64 --output dist/alphaops-agent
    ```
  - [ ] Upload to GitHub releases
  - [ ] Update environment variables with correct URLs
  - [ ] Test on a fresh server

### Testing:

- [ ] **Test on fresh Ubuntu server**
  - [ ] Run install command from UI
  - [ ] Verify agent connects within 15 seconds
  - [ ] Test command execution
  - [ ] Test file operations

- [ ] **Test on fresh Debian server**
  - [ ] Same as above

- [ ] **Test on fresh CentOS/RHEL server** (if supported)
  - [ ] Same as above

- [ ] **Test reconnection**
  - [ ] Stop agent: `screen -X -S alphaops-agent quit`
  - [ ] Start agent: `screen -dmS alphaops-agent node agent.js --token "$TOKEN" --backend "$BACKEND"`
  - [ ] Verify reconnects automatically

- [ ] **Test with firewall**
  - [ ] Enable firewall
  - [ ] Verify agent can still connect
  - [ ] Test command execution

### Documentation:

- [ ] **Update README**
  - [ ] Add installation instructions
  - [ ] Add troubleshooting section
  - [ ] Add requirements (Node.js 18+)

- [ ] **Update .env.example**
  - [ ] Correct binary URLs (if using Option 2)
  - [ ] Add comments explaining each variable

- [ ] **Update agent README**
  - [ ] Clarify it's a Node.js application
  - [ ] Add build instructions (if using Option 2)
  - [ ] Add troubleshooting section

### Deployment:

- [ ] **Update environment variables**
  - [ ] `AlphaOps_AGENT_SECRET` (if using signed tokens)
  - [ ] `AlphaOps_AGENT_BINARY_URL_LINUX_AMD64` (if using binaries)
  - [ ] `AlphaOps_AGENT_BINARY_URL_LINUX_ARM64` (if using binaries)

- [ ] **Deploy backend changes**
  - [ ] Push to repository
  - [ ] Deploy to Railway
  - [ ] Verify deployment successful

- [ ] **Test production**
  - [ ] Run install command from production UI
  - [ ] Verify agent connects
  - [ ] Test all functionality

## Verification Checklist

After implementing the fix:

### Functional Tests:

- [ ] Agent installs successfully
- [ ] Agent connects within 15 seconds
- [ ] Agent shows as "online" in UI
- [ ] Can execute commands
- [ ] Can read files
- [ ] Can write files
- [ ] Can upload files
- [ ] Can view system stats
- [ ] Can manage services
- [ ] Can deploy applications

### Reliability Tests:

- [ ] Agent reconnects after network interruption
- [ ] Agent reconnects after backend restart
- [ ] Agent survives server reboot (if using systemd)
- [ ] Multiple agents can connect simultaneously
- [ ] Agent handles long-running commands
- [ ] Agent handles large output

### Security Tests:

- [ ] Token validation works
- [ ] Expired tokens are rejected
- [ ] Invalid tokens are rejected
- [ ] Agent can only execute commands for its user
- [ ] Agent can't access other users' agents
- [ ] WebSocket connection is encrypted (WSS)

## Success Metrics

- [ ] **Installation success rate**: > 95%
- [ ] **Connection time**: < 15 seconds
- [ ] **Uptime**: > 99%
- [ ] **Reconnection time**: < 30 seconds
- [ ] **Command execution success rate**: > 99%

## Rollback Plan

If the fix causes issues:

- [ ] **Revert backend changes**
  ```bash
  git revert <commit-hash>
  git push
  ```

- [ ] **Notify users**
  - Send message about temporary issues
  - Provide manual installation instructions

- [ ] **Investigate issues**
  - Check backend logs
  - Check agent logs
  - Identify root cause

- [ ] **Fix and redeploy**
  - Fix the issue
  - Test thoroughly
  - Deploy again

## Communication

- [ ] **Notify users about the fix**
  - Email/announcement about improved installation
  - Link to updated documentation
  - Offer support for migration

- [ ] **Update support documentation**
  - Add to FAQ
  - Add to troubleshooting guide
  - Add to known issues (if any)

## Timeline

### Immediate (Today):
- [x] Identify root cause
- [x] Create fix scripts
- [x] Create documentation
- [ ] Test on one server
- [ ] Share with users

### Short-term (This Week):
- [ ] Implement backend changes
- [ ] Test thoroughly
- [ ] Deploy to production
- [ ] Update documentation
- [ ] Monitor for issues

### Long-term (This Month):
- [ ] Gather user feedback
- [ ] Optimize installation process
- [ ] Add monitoring/alerting
- [ ] Consider systemd service
- [ ] Consider auto-updates

## Notes

- Keep all fix scripts in the repository for future reference
- Document any issues encountered during implementation
- Update this checklist as you complete items
- Share learnings with the team

---

**Priority**: 🔴 HIGH - This blocks users from connecting agents

**Estimated Time**: 
- Quick fix: 5 minutes
- Long-term fix: 2-4 hours
- Testing: 1-2 hours
- Documentation: 1 hour

**Total**: ~4-7 hours for complete fix and testing
