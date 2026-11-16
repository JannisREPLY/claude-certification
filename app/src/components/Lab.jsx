import { useEffect, useState } from 'react'
import { useProgress } from '../lib/store.jsx'
import LessonBody from './LessonBody.jsx'

const api = (path, method = 'GET') =>
  fetch(`api/lab/${path}`, { method }).then(async (r) => {
    const body = await r.json().catch(() => ({}))
    if (!r.ok) throw new Error(body.error || `Lab service answered ${r.status}`)
    return body
  })

export default function Lab({ cert }) {
  const { progress, finishLab, toast } = useProgress()
  const [active, setActive] = useState(null)
  const [online, setOnline] = useState(false)
  const [selected, setSelected] = useState(null)
  const [busy, setBusy] = useState(null)
  const [results, setResults] = useState({})
  const [error, setError] = useState(null)
  const [editorKey, setEditorKey] = useState(0)

  useEffect(() => {
    api('status')
      .then((s) => {
        setOnline(true)
        setActive(s.active)
        if (cert.labs.some((l) => l.id === s.active)) setSelected(s.active)
      })
      .catch(() => setError('The lab service is not reachable. Start the full stack with `docker compose up -d --build`.'))
  }, [cert])

  const start = async (lab) => {
    if (active && !confirm(`Start “${lab.title}”? This resets the lab folder and the emulated AWS account.`)) return
    setBusy('start')
    setError(null)
    try {
      const r = await api(`labs/${lab.id}/start`, 'POST')
      if (!r.ok) throw new Error(`Setup failed:\n${r.output}`)
      setActive(r.active)
      setSelected(lab.id)
      setResults((rs) => ({ ...rs, [lab.id]: null }))
      setEditorKey((k) => k + 1)
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(null)
    }
  }

  const check = async (lab) => {
    setBusy('check')
    setError(null)
    try {
      const r = await api(`labs/${lab.id}/check`, 'POST')
      setResults((rs) => ({ ...rs, [lab.id]: r.results }))
      const gained = finishLab(lab.id, r.results)
      if (gained) toast({ icon: '🧪', text: `+${gained} XP` })
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(null)
    }
  }

  const lab = cert.labs.find((l) => l.id === selected)
  if (!lab) {
    return (
      <div className="grid">
        {error && <pre className="card span2 lab-error">{error}</pre>}
        {cert.labs.map((l) => {
          const done = progress.labs[l.id]
          return (
            <section key={l.id} className="card">
              <h3>{done?.completed ? '✅' : '🧪'} {l.title}</h3>
              <p className="hint">Objective {l.objectives.join(', ')} · {l.tasks.length} tasks · about {l.minutes} min{done ? ` · ${Object.keys(done.tasks).length}/${l.tasks.length} tasks passed so far` : ''}</p>
              <div className="q-actions">
                {active === l.id && <button className="btn primary" onClick={() => setSelected(l.id)}>Continue</button>}
                <button className={`btn ${active === l.id ? '' : 'primary'}`} disabled={!!busy || !online} onClick={() => start(l)}>
                  {busy === 'start' ? '⏳ Setting up…' : active === l.id ? '↺ Restart' : '▶ Start'}
                </button>
              </div>
            </section>
          )
        })}
      </div>
    )
  }

  const res = results[lab.id]
  const byId = Object.fromEntries((res || []).map((r) => [r.id, r]))
  return (
    <div className="lab">
      <aside className="card lab-panel">
        <button className="btn tiny" onClick={() => setSelected(null)}>← All labs</button>
        <h3>{lab.title}</h3>
        <LessonBody markdown={lab.intro} />
        <ol className="lab-tasks">
          {lab.tasks.map((t) => {
            const r = byId[t.id]
            return (
              <li key={t.id} className={r ? (r.ok ? 'ok' : 'fail') : ''}>
                <span className="lab-mark">{r ? (r.ok ? '✅' : '❌') : '⬜'}</span>
                <div>
                  <LessonBody markdown={t.text} />
                  {r && !r.ok && <pre className="lab-output">{r.output}</pre>}
                </div>
              </li>
            )
          })}
        </ol>
        {error && <pre className="lab-error">{error}</pre>}
        {res && res.every((r) => r.ok) && <p className="verdict yes">🎉 Lab passed!</p>}
        <div className="q-actions">
          <button className="btn primary" disabled={!!busy} onClick={() => check(lab)}>{busy === 'check' ? '⏳ Checking…' : '✔ Check my work'}</button>
          <button className="btn" disabled={!!busy} onClick={() => start(lab)}>{busy === 'start' ? '⏳ Resetting…' : '↺ Restart lab'}</button>
          <a className="btn" href="code/?folder=/home/coder/lab" target="_blank" rel="noreferrer">⤢ Editor in new tab</a>
        </div>
      </aside>
      <iframe key={editorKey} className="lab-editor" src="code/?folder=/home/coder/lab" title="Lab editor" />
    </div>
  )
}
