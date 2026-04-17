import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import http from 'http';
import { createClient } from '@supabase/supabase-js';

import { agentConnection } from './agent-connection.js';
import { sshConnection } from './ssh-connection.js';
import { createApp } from './app.js';
import { query } from './infra/db.js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

const supabase = (supabaseUrl && supabaseAnonKey)
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null;

async function requireUser(req, res, next) {
  try {
    if (!supabase) {
      return res.status(503).json({ error: 'Backend misconfigured: missing SUPABASE_URL or SUPABASE_ANON_KEY' });
    }

    const authHeader = req.get('authorization');
    if (!authHeader) {
      const fallbackToken =
        (req.body && (req.body.access_token || req.body.token)) ||
        (req.query && (req.query.access_token || req.query.token));
      if (!fallbackToken) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      req.accessToken = fallbackToken;
    }

    const rawToken = req.accessToken || authHeader?.replace('Bearer ', '');
    if (!rawToken) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(rawToken);

    if (authError || !user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    req.user = user;
    req.accessToken = rawToken;

    return next();
  } catch (error) {
    return res.status(500).json({ error: error?.message || 'Request failed' });
  }
}

function validateServerIdOwnership(req, res, serverId) {
  if (!serverId || typeof serverId !== 'string') {
    res.status(400).json({ error: 'serverId is required' });
    return false;
  }

  if (!serverId.startsWith(req.user.id)) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }

  return true;
}

function getConnection(serverId) {
  if (agentConnection.isAgentServerId(serverId)) return agentConnection;
  return sshConnection;
}

const app = express();

app.use(
  cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

app.use(express.json({ limit: '10mb' }));

// Core API
app.use(createApp());

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.post('/ai/chat', requireUser, async (req, res) => {
  try {
    const apiKey = String(process.env.OPENROUTER_API_KEY || '').trim();
    if (!apiKey) {
      return res.status(503).json({ error: 'Backend misconfigured: missing OPENROUTER_API_KEY' });
    }

    const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

    const primaryModel = String(process.env.OPENROUTER_MODEL || 'z-ai/glm-4.5-air:free').trim();
    const fallbackModelsEnv = String(process.env.OPENROUTER_FALLBACK_MODELS || '').trim();
    const fallbackModels = fallbackModelsEnv
      ? fallbackModelsEnv
          .split(',')
          .map((s) => String(s || '').trim())
          .filter(Boolean)
      : [];
    const modelsToTry = [primaryModel, ...fallbackModels];

    const body = req.body || {};
    const prompt = String(body.prompt || '').trim();
    const mode = String(body.mode || '').trim() || 'command';
    const serverContext = body.serverContext || null;
    const chatHistory = Array.isArray(body.chatHistory) ? body.chatHistory : [];
    if (!prompt) return res.status(400).json({ error: 'prompt is required' });

    const systemParts = [];
    systemParts.push('You are AlphaAI, an assistant for managing Linux servers.');
    if (mode === 'command') {
      systemParts.push('Return ONLY a single shell command as plain text. No markdown.');
    } else if (mode === 'chat') {
      systemParts.push('Be concise and helpful. If you include a command, put it in a fenced code block.');
    } else if (mode === 'script') {
      systemParts.push('Return ONLY a bash script. No markdown. Start with #!/bin/bash');
    } else if (mode === 'json-command') {
      systemParts.push('Return STRICT JSON with keys: summary, command. No markdown.');
    }
    if (serverContext) {
      systemParts.push('Server context (may be partial):');
      systemParts.push(typeof serverContext === 'string' ? serverContext : JSON.stringify(serverContext));
    }
    const systemPrompt = systemParts.join('\n');

    const messages = [];
    messages.push({ role: 'system', content: systemPrompt });

    for (const m of chatHistory) {
      if (!m) continue;
      const roleRaw = String(m.role || '').toLowerCase();
      const role = roleRaw === 'assistant' || roleRaw === 'ai' ? 'assistant' : 'user';
      const content = String(m.content || m.text || '').trim();
      if (!content) continue;
      messages.push({ role, content });
    }

    messages.push({ role: 'user', content: prompt });

    let lastErrText = '';
    let lastStatus = 0;

    for (const model of modelsToTry) {
      const maxAttempts = 2;
      for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        const resp = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            model,
            messages,
            temperature: 0.3,
            stream: false,
          }),
        });

        if (resp.ok) {
          const data = await resp.json();
          const text = data?.choices?.[0]?.message?.content || '';
          return res.json({ success: true, script: String(text || '').trim() });
        }

        lastStatus = resp.status || 0;
        lastErrText = await resp.text();

        let providerMessage = '';
        try {
          const parsed = JSON.parse(lastErrText);
          providerMessage =
            parsed?.error?.metadata?.raw ||
            parsed?.error?.message ||
            parsed?.message ||
            '';
        } catch (e) {
          providerMessage = lastErrText;
        }
        providerMessage = String(providerMessage || '').trim();
        if (providerMessage.length > 300) providerMessage = providerMessage.slice(0, 300) + '…';

        const isRateLimited = lastStatus === 429 || /\b429\b/.test(lastErrText);
        if (isRateLimited) {
          if (attempt < maxAttempts) {
            await sleep(800 * attempt);
            continue;
          }
          break;
        }

        const errMsg = providerMessage ? `OpenRouter error: ${providerMessage}` : 'OpenRouter error';
        return res.status(502).json({ error: errMsg });
      }
    }

    let shortRateLimitMsg = 'AI provider is temporarily rate-limited. Please retry shortly.';
    try {
      const parsed = JSON.parse(lastErrText);
      const raw =
        parsed?.error?.metadata?.raw ||
        parsed?.error?.message ||
        parsed?.message ||
        '';
      if (raw) {
        shortRateLimitMsg = String(raw).trim();
        if (shortRateLimitMsg.length > 300) shortRateLimitMsg = shortRateLimitMsg.slice(0, 300) + '…';
      }
    } catch (e) {
    }
    return res.status(429).json({ error: shortRateLimitMsg });
  } catch (error) {
    return res.status(500).json({ error: error?.message || 'AI request failed' });
  }
});

app.post('/ssh/connect', requireUser, async (req, res) => {
  try {
    const config = req.body;
    const serverId = `${req.user.id}_${config.host}_${Date.now()}`;
    const result = await sshConnection.connect(serverId, config);
    return res.json({ ...result, serverId });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

app.post('/ssh/disconnect', requireUser, async (req, res) => {
  try {
    const { serverId } = req.body;
    if (!validateServerIdOwnership(req, res, serverId)) return;
    const connection = getConnection(serverId);
    const result = connection.disconnect(serverId);
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

app.post('/ssh/command', requireUser, async (req, res) => {
  try {
    const { serverId, command } = req.body;
    if (!validateServerIdOwnership(req, res, serverId)) return;
    const connection = getConnection(serverId);
    if (!connection.isConnected(serverId)) {
      return res.status(409).json({ error: 'Not connected' });
    }
    const result = await connection.exec(serverId, command);
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

app.post('/ssh/stats', requireUser, async (req, res) => {
  try {
    const { serverId } = req.body;
    if (!validateServerIdOwnership(req, res, serverId)) return;
    const connection = getConnection(serverId);
    if (!connection.isConnected(serverId)) {
      return res.status(409).json({ error: 'Not connected' });
    }

    const commandMap = {
      df: 'df -h | grep -vE "^Filesystem|tmpfs|cdrom|udev"',
      free: 'free -h',
      uptime: 'uptime',
      os: '(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || (lsb_release -ds 2>/dev/null) || uname -s',
      kernel: 'uname -r',
      ip: "hostname -I 2>/dev/null | awk '{print $1}'",
      cpu: `LC_ALL=C top -bn1 2>/dev/null | grep -E 'Cpu\\(s\\)' | sed 's/,/ /g' | awk '{for(i=1;i<=NF;i++) if($i=="id") idle=$(i-1)} END {if(idle!="") printf("%.1f", 100-idle); else print "0"}'`,
      ram: `free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf("%.1f", ($3/$2)*100); else print "0" }'`,
      disk: "df -P / 2>/dev/null | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'",
      topCpu: 'ps aux --sort=-%cpu | head -10',
      topMem: 'ps aux --sort=-%mem | head -10',
    };

    const entries = Object.entries(commandMap);
    const values = await Promise.all(
      entries.map(async ([key, cmd]) => {
        const result = await connection.exec(serverId, cmd);
        return [key, (result.stdout || '').trim()];
      })
    );

    const results = Object.fromEntries(values);
    return res.json({ success: true, data: results });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

const port = process.env.PORT ? Number(process.env.PORT) : 8080;
const server = http.createServer(app);

server.listen(port, () => {
  console.log(`AlphaOps backend listening on ${port}`);
});
