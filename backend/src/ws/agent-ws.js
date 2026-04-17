import { WebSocketServer } from 'ws';
import { agentConnection } from '../agent-connection.js';

export function attachAgentWs({ server, path = '/agent/connect' }) {
  const wss = new WebSocketServer({ noServer: true });

  if (server) {
    server.on('upgrade', (req, socket, head) => {
      try {
        const url = new URL(req.url, 'http://localhost');
        const pathname = url.pathname || '';
        if (pathname !== path && pathname !== `${path}/`) {
          return;
        }
        wss.handleUpgrade(req, socket, head, (ws) => {
          wss.emit('connection', ws, req);
        });
      } catch (e) {
        console.error('[agent-ws] upgrade error:', e);
      }
    });
  }

  wss.on('connection', async (ws, req) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      const token = url.searchParams.get('token');

      if (!token) {
        ws.close(1008, 'Token required');
        return;
      }

      const verified = agentConnection.validateToken(token);
      if (!verified) {
        ws.close(1008, 'Invalid token');
        return;
      }

      const { agentId, userId } = verified;
      console.log(`[agent-ws] Agent connected: ${agentId} (user: ${userId})`);

      agentConnection.registerSession(agentId, userId, ws);

      ws.on('message', (message) => {
        agentConnection.handleAgentMessage(agentId, message);
      });

      ws.on('close', () => {
        console.log(`[agent-ws] Agent disconnected: ${agentId}`);
        agentConnection.removeSession(agentId);
      });

      ws.on('error', (err) => {
        console.error(`[agent-ws] Agent error (${agentId}):`, err);
        ws.close();
      });

    } catch (err) {
      console.error('[agent-ws] connection error:', err);
      ws.close(1011, 'Internal server error');
    }
  });

  return wss;
}
