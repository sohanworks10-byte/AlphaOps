# Deployment Error Fix: Cannot PUT /ssh/files

## Issue
Getting "Connection Error: Cannot PUT /ssh/files" when trying to deploy applications.

## Root Cause
The backend API route `/ssh/files` with PUT method exists in the code but may not be properly deployed or accessible on Railway.

## Solutions

### Solution 1: Redeploy Backend on Railway

1. Go to your Railway dashboard: https://railway.app
2. Select your `alphaops-production` project
3. Click on the backend service
4. Click "Deploy" or trigger a new deployment
5. Wait for deployment to complete
6. Test the endpoint

### Solution 2: Verify Environment Variables

Ensure all required environment variables are set in Railway:

```
SUPABASE_URL=https://bcuxmvaicdnkbxcvqbds.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
DATABASE_URL=https://bcuxmvaicdnkbxcvqbds.supabase.co/
AlphaOps_AGENT_SECRET=847c3010-5ba6-40d5-973b-134931614543...
AlphaOps_AGENT_BINARY_URL_LINUX_AMD64=https://github.com/sohanworks10-byte/AlphaOps/releases/download/v1.0.3/alphaops-agent-linux-amd64
AlphaOps_AGENT_BINARY_URL_LINUX_ARM64=https://github.com/sohanworks10-byte/AlphaOps/releases/download/v1.0.3/alphaops-agent-linux-arm64
OPENROUTER_API_KEY=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
```

### Solution 3: Check CORS Configuration

The backend CORS configuration has been updated to include all necessary HTTP methods:

```javascript
cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})
```

### Solution 4: Test the Endpoint Directly

Test if the endpoint is accessible:

```bash
# Test with curl (replace TOKEN with your access token)
curl -X PUT https://alphaops-production.up.railway.app/ssh/files \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{"serverId":"test","path":"/tmp/test.txt","content":{"base64":"dGVzdA=="}}'
```

Expected responses:
- 401: Unauthorized (token issue)
- 409: Not connected (SSH not connected)
- 200: Success
- 404: Route not found (deployment issue)

### Solution 5: Check Railway Logs

1. Go to Railway dashboard
2. Select your backend service
3. Click on "Deployments"
4. View logs for errors
5. Look for:
   - "AlphaOps backend listening on [port]" - confirms server started
   - Any route registration errors
   - CORS errors

### Solution 6: Force Push to Railway

If Railway isn't picking up changes:

```bash
# Commit all changes
git add .
git commit -m "Fix SSH files endpoint and CORS configuration"

# Push to trigger Railway deployment
git push origin main
```

## Code Changes Made

### 1. Updated CORS Configuration (backend/src/index.js)
Added 'PATCH' and 'DELETE' methods to CORS allowed methods.

### 2. Verified Route Registration
The PUT /ssh/files route is properly defined at line 531 in backend/src/index.js:

```javascript
app.put('/ssh/files', requireUser, async (req, res) => {
  try {
    const { serverId, path, content } = req.body;
    if (!validateServerIdOwnership(req, res, serverId)) return;
    const connection = getConnection(serverId);
    if (!connection.isConnected(serverId)) {
      return res.status(409).json({ error: 'Not connected' });
    }
    await connection.writeFile(serverId, path, content);
    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});
```

## Verification Steps

After redeployment:

1. ✅ Check Railway deployment logs show "AlphaOps backend listening on [port]"
2. ✅ Test authentication with /health endpoint
3. ✅ Connect to an SSH server
4. ✅ Try deploying an application
5. ✅ Verify no "Cannot PUT /ssh/files" errors

## Additional Notes

- The route is defined BEFORE `server.listen()`, so it should be registered
- The route uses `requireUser` middleware, so authentication is required
- The route validates server ownership before allowing file writes
- The frontend sends the request correctly with proper headers

## If Issue Persists

If the issue continues after redeployment:

1. Check if Railway has any proxy/load balancer that might be blocking PUT requests
2. Verify the Railway service is using the correct start command: `npm start --prefix backend`
3. Check if there are any Railway-specific limitations on HTTP methods
4. Consider adding a health check endpoint that tests all HTTP methods

---

**Status:** Code fixed, awaiting Railway redeployment
**Priority:** High - Blocks deployment functionality
