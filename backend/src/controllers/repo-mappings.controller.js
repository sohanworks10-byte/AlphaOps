// Repository mappings controller stub
// TODO: Implement repository mapping management

export async function listRepoMappings(req, res) {
  return res.json({ mappings: [] });
}

export async function createRepoMapping(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}

export async function updateRepoMapping(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}

export async function deleteRepoMapping(req, res) {
  return res.status(501).json({ error: 'Not implemented' });
}
