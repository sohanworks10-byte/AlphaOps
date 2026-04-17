# Deployment Error Fix: Railway Healthcheck Failure

## Issue
Railway deployment is building successfully but failing healthcheck with "service unavailable" errors.

## Root Causes Fixed

### 1. Server Not Binding to 0.0.0.0
**Problem:** Server was only binding to localhost, making it inaccessible to Railway's load balancer.

**Solution:** Updated `server.listen()` to bind to `0.0.0.0`:
```javascript
server.listen(port, '0.0.0.0', () => {
  console.log(`AlphaOps backend listening on ${port}`);
});
```

### 2. Missing Root Route Handler
**Problem:** Railway's healthcheck hits `/` but no route handler was defined for it.

**Solution:** Added root route handler:
```javascript
app.get('/', (req, res) => {
  res.json({ ok: true, service: 'AlphaOps Backend', version: '1.0.0' });
});
```

### 3. CORS Configuration
**Problem:** PUT method wasn't included in CORS allowed methods.

**Solution:** Updated CORS to include all necessary methods:
```javascript
cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})
```

## Changes Made

### backend/src/index.js
1. ✅ Added `'0.0.0.0'` to `server.listen()` call
2. ✅ Added root route handler for `/`
3. ✅ Updated CORS to include PATCH and DELETE methods
4. ✅ Added `/debug/routes` diagnostic endpoint

## Deployment Steps

1. **Commit Changes:**
   ```bash
   git add .
   git commit -m "Fix Railway deployment: bind to 0.0.0.0 and add root route"
   git push origin main
   ```

2. **Railway Auto-Deploy:**
   - Railway will automatically detect the push and start a new deployment
   - Monitor the deployment logs in Railway dashboard

3. **Verify Deployment:**
   - Check that healthcheck passes
   - Test root endpoint: `https://alphaops-production.up.railway.app/`
   - Test health endpoint: `https://alphaops-production.up.railway.app/health`
   - Test routes diagnostic: `https://alphaops-production.up.railway.app/debug/routes`

## Expected Results

### Root Endpoint (/)
```json
{
  "ok": true,
  "service": "AlphaOps Backend",
  "version": "1.0.0"
}
```

### Health Endpoint (/health)
```json
{
  "ok": true
}
```

### Debug Routes (/debug/routes)
```json
{
  "routes": [
    { "path": "/", "methods": "GET" },
    { "path": "/health", "methods": "GET" },
    { "path": "/ssh/files", "methods": "POST, GET, PUT" },
    ...
  ],
  "count": 50
}
```

## Railway Configuration

The `railway.toml` is correctly configured:
```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm install --prefix backend"

[deploy]
startCommand = "npm start --prefix backend"
healthcheckPath = "/"
healthcheckTimeout = 300
restartPolicy = "on-failure"
```

## Troubleshooting

If deployment still fails:

1. **Check Railway Logs:**
   - Look for "AlphaOps backend listening on [port]" message
   - Check for any startup errors

2. **Verify Environment Variables:**
   All required variables must be set in Railway:
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
   - DATABASE_URL
   - AlphaOps_AGENT_SECRET
   - AlphaOps_AGENT_BINARY_URL_LINUX_AMD64
   - AlphaOps_AGENT_BINARY_URL_LINUX_ARM64
   - OPENROUTER_API_KEY

3. **Check Port:**
   - Railway automatically sets PORT environment variable
   - Backend correctly reads it: `process.env.PORT || 8080`

4. **Test Locally:**
   ```bash
   cd backend
   PORT=8080 npm start
   # In another terminal:
   curl http://localhost:8080/
   ```

## Common Issues

### Issue: "service unavailable"
- **Cause:** Server not binding to 0.0.0.0
- **Fix:** ✅ Applied in this commit

### Issue: "Cannot PUT /ssh/files"
- **Cause:** CORS not allowing PUT method
- **Fix:** ✅ Applied in this commit

### Issue: Healthcheck timeout
- **Cause:** No route handler for `/`
- **Fix:** ✅ Applied in this commit

---

**Status:** ✅ All fixes applied, ready for deployment
**Priority:** Critical - Blocks all backend functionality
