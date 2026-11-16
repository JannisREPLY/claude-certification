import { useState } from 'react'
import { supabase } from '../lib/supabase.js'
import { useProgress } from '../lib/store.jsx'

export default function SyncCard() {
  const { session, syncError } = useProgress()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [msg, setMsg] = useState(null)
  const [busy, setBusy] = useState(false)
  if (!supabase) return null

  const run = async (fn) => {
    setBusy(true)
    setMsg(null)
    const { data, error } = await fn()
    setBusy(false)
    if (error) return setMsg(error.message)
    if (data?.user && !data.session) setMsg('Check your email to confirm the account, then sign in.')
  }
  const signIn = (e) => {
    e.preventDefault()
    run(() => supabase.auth.signInWithPassword({ email, password }))
  }
  const signUp = () => run(() => supabase.auth.signUp({ email, password, options: { emailRedirectTo: location.origin + location.pathname } }))

  if (session) {
    return (
      <section className="card span2">
        <h3>☁️ Sync</h3>
        <p className="hint">{syncError ? `⚠️ Sync failed: ${syncError}` : `Synced as ${session.user.email}. Progress syncs across every device you sign in on.`}</p>
        <button className="btn tiny" onClick={() => supabase.auth.signOut()}>Sign out</button>
      </section>
    )
  }
  return (
    <section className="card span2">
      <h3>☁️ Sync</h3>
      <p className="hint">Sign in to sync your progress across devices. The newest progress wins.</p>
      <form className="sync-form" onSubmit={signIn}>
        <input type="email" placeholder="Email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <input type="password" placeholder="Password" autoComplete="current-password" required minLength={6} value={password} onChange={(e) => setPassword(e.target.value)} />
        <button className="btn primary" disabled={busy}>Sign in</button>
        <button type="button" className="btn" disabled={busy || !email || password.length < 6} onClick={signUp}>Create account</button>
      </form>
      {msg && <p className="hint">{msg}</p>}
    </section>
  )
}
