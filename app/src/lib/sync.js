const stamp = (p) => p?.updatedAt || 0

export function resolve(local, remote) {
  if (!remote) return { use: 'local', push: true }
  if (stamp(remote) > stamp(local)) return { use: 'remote', push: false }
  return { use: 'local', push: stamp(local) > stamp(remote) }
}

export async function pull(client, certId) {
  if (!client) return null
  const { data, error } = await client.from('cert_progress').select('data').eq('cert_id', certId).maybeSingle()
  if (error) throw error
  return data?.data ?? null
}

export async function push(client, certId, progress) {
  if (!client) return
  const { error } = await client.from('cert_progress').upsert({ cert_id: certId, data: progress, updated_at: new Date().toISOString() })
  if (error) throw error
}
