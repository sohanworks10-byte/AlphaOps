import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import { createClient } from '@supabase/supabase-js';

import { query } from './infra/db.js';
import { agentConnection } from './agent-connection.js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

const supabase = (supabaseUrl && supabaseAnonKey)
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null;

export async function requireUser(req, res, next) {
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

export function createApp() {
  const app = express.Router();

  app.use(
    cors({
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  app.use(
    express.json({
      limit: '10mb',
      verify: (req, res, buf) => {
        req.rawBody = buf;
      },
    })
  );

  app.get('/health', (req, res) => {
    res.json({ ok: true });
  });

  app.post('/agent/enroll', requireUser, async (req, res) => {
    try {
      const result = agentConnection.createEnrollToken(req.user.id);
      const backendUrl = process.env.AlphaOps_BACKEND_URL || 'https://alphaops-production.up.railway.app';
      const wsUrl = backendUrl.replace(/^http/, 'ws');

      const installCommand = `curl -fsSL https://raw.githubusercontent.com/sohanworks10-byte/AlphaOps/main/alphaops-agent/install.sh | bash -s -- --token ${result.token} --backend ${wsUrl}`;

      return res.json({
        success: true,
        agentId: result.agentId,
        token: result.token,
        installCommand,
      });
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  });

  app.get('/agent/status', requireUser, async (req, res) => {
    try {
      const agentId = req.query.agentId;
      if (!agentId) return res.status(400).json({ error: 'agentId is required' });

      const online = agentConnection.isAgentOnline(agentId);
      return res.json({ success: true, online });
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  });

  app.post('/agent/connect', requireUser, async (req, res) => {
    try {
      const { agentId, serverId } = req.body;
      const result = await agentConnection.connect(req.user.id, agentId || serverId);
      return res.json(result);
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/me', requireUser, async (req, res) => {
    const user = req.user;
    const userId = user?.id;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });

    const result = await query(
      `select r.project_id as id,
              coalesce(p.name, r.project_id::text) as name,
              r.role as role
         from project_roles r
         left join projects p on p.id = r.project_id
        where r.user_id = $1
        order by coalesce(p.name, r.project_id::text) asc`,
      [userId]
    );

    return res.json({
      user: { id: user.id, email: user.email },
      projects: result.rows,
    });
  });

  app.use((err, req, res, next) => {
    if (res.headersSent) return next(err);
    return res.status(500).json({ error: err?.message || 'Internal Server Error' });
  });

  return app;
}
