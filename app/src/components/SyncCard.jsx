import { useState } from 'react'
import { supabase } from '../lib/supabase.js'
import { useProgress } from '../lib/store.jsx'

export default function SyncCard() {
  const { session, syncError } = useProgress()
  const [error, setError] = useState(null)
  if (!supabase) return null

  const signIn = async () => {
    const { error } = await supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: location.origin + location.pathname } })
    if (error) setError(error.message)
  }

  return (
    <section className="card span2">
      <h3>☁️ Sync</h3>
      {session ? (
        <>
          <p className="hint">{syncError ? `⚠️ Sync failed: ${syncError}` : `Synced as ${session.user.email}.`}</p>
          <button className="btn tiny" onClick={() => supabase.auth.signOut()}>Sign out</button>
        </>
      ) : (
        <>
          <p className="hint">Sign in to sync your progress across devices. The newest progress wins.</p>
          <button className="btn primary" onClick={signIn}>Sign in with Google</button>
          {error && <p className="hint">{error}</p>}
        </>
      )}
    </section>
  )
}
