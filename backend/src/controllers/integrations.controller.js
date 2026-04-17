// Integrations controller stub
// TODO: Implement integration management

export async function createIntegration(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}

export async function listIntegrations(req, res) {
  return res.json({ integrations: [] });
}

// Phase 3 methods
export async function listProjectIntegrations(req, res) {
  return res.json({ integrations: [] });
}

export async function createProjectIntegration(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}

export async function deleteProjectIntegration(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}
