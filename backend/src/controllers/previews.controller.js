// Previews controller stub
// TODO: Implement preview environment management

export async function createPreview(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}

export async function listPreviews(req, res) {
  return res.json({ previews: [] });
}

export async function getPreview(req, res) {
  return res.status(404).json({ error: 'Preview not found' });
}

export async function destroyPreview(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}

export async function approveSwitch(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}
