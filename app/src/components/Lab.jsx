import { useEffect, useState } from 'react'
import { useProgress } from '../lib/store.jsx'
import { EXAM_LEVEL, LEVELS, labKey, labLevels, labRecord } from '../lib/labs.js'
import LessonBody from './LessonBody.jsx'

export const labApi = (path, method = 'GET') =>
  fetch(`api/lab/${path}`, { method }).then(async (r) => {
    const body = await r.json().catch(() => ({}))
    if (!r.ok) throw new Error(body.error || `Lab service answered ${r.status}`)
    return body
  })

export function LabTasks({ tasks, results }) {
  const byId = Object.fromEntries((results || []).map((r) => [r.id, r]))
  return (
    <ol className="lab-tasks">
      {tasks.map((t, i) => {
        const r = byId[t.id]
        return (
          <li key={t.id} className={r ? (r.ok ? 'ok' : 'fail') : ''}>
            <span className="lab-mark">{r ? (r.ok ? '✅' : '❌') : '⬜'}</span>
            <div>
              <p className="hint">Task {i + 1}</p>
              <LessonBody markdown={t.text} />
              {t.validation && <div className="lab-validation"><b>Validation:</b> <LessonBody markdown={t.validation} /></div>}
              {r && !r.ok && <pre className="lab-output">{r.output}</pre>}
            </div>
          </li>
        )
      })}
    </ol>
  )
}

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
    labApi('status')
      .then((s) => {
        setOnline(true)
        setActive(s.active)
        const [id, level] = (s.active || '').split(':')
        if (level && cert.labs.some((l) => l.id === id)) setSelected({ id, level })
      })
      .catch(() => setOnline(false))
  }, [cert])

  const start = async (lab, level) => {
    const msg = active === 'exam'
      ? 'A mock exam is running. Starting this lab ends the exam and resets its folders and the emulated AWS account.'
      : `Start “${lab.title}” (${level})? This resets the lab folder and the emulated AWS account.`
    if (active && !confirm(msg)) return
    setBusy('start')
    setError(null)
    try {
      const r = await labApi(`labs/${lab.id}/${level}/start${active === 'exam' ? '?force=1' : ''}`, 'POST')
      if (!r.ok) throw new Error(`Setup failed:\n${r.output}`)
      setActive(r.active)
      setSelected({ id: lab.id, level })
      setResults((rs) => ({ ...rs, [labKey(lab.id, level)]: null }))
      setEditorKey((k) => k + 1)
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(null)
    }
  }

  const check = async (lab, level) => {
    setBusy('check')
    setError(null)
    try {
      const r = await labApi(`labs/${lab.id}/${level}/check`, 'POST')
      setResults((rs) => ({ ...rs, [labKey(lab.id, level)]: r.results }))
      const gained = finishLab(labKey(lab.id, level), r.results)
      if (gained) toast({ icon: '🧪', text: `+${gained} XP` })
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(null)
    }
  }

  const lab = selected && cert.labs.find((l) => l.id === selected.id)
  if (!lab) {
    return (
      <div className="grid">
        {error && <pre className="card span2 lab-error">{error}</pre>}
        {!online && <p className="card span2 hint">🔒 Labs run only in the local Docker stack (<code>docker compose up -d --build</code>, then open localhost:8080). Your lab progress is shown here.</p>}
        <p className="card span2 hint">Every lab has three levels. 🎯 <b>Exam</b> is the level you can expect in the real exam; it counts towards readiness. 🧭 Guided adds hints, 🔥 Expert goes beyond the exam.</p>
        {cert.labs.map((l) => (
          <section key={l.id} className="card">
            <h3>{labRecord(progress, l.id)?.completed ? '✅' : '🧪'} {l.title}</h3>
            <p className="hint">Objective {l.objectives.join(', ')}</p>
            <div className="lab-levels">
              {labLevels(l).map((lv) => {
                const rec = labRecord(progress, l.id, lv.id)
                const tasks = l.levels[lv.id].tasks
                const running = active === labKey(l.id, lv.id)
                return (
                  <div key={lv.id} className={`lab-level ${lv.id === EXAM_LEVEL ? 'exam-like' : ''}`}>
                    <div>
                      <b>{rec?.completed ? '✅' : lv.icon} {lv.name}</b>
                      {lv.id === EXAM_LEVEL && <span className="badge-exam">like the exam</span>}
                      <small className="hint">{tasks.length} tasks · about {l.levels[lv.id].minutes} min{rec ? ` · ${Object.keys(rec.tasks).length}/${tasks.length} passed` : ''}</small>
                    </div>
                    <div className="q-actions">
                      {running && <button className="btn tiny primary" onClick={() => setSelected({ id: l.id, level: lv.id })}>Continue</button>}
                      <button className={`btn tiny ${running ? '' : 'primary'}`} disabled={!!busy || !online} title={online ? undefined : 'Needs the local Docker stack'} onClick={() => start(l, lv.id)}>
                        {busy === 'start' ? '⏳' : running ? '↺ Restart' : '▶ Start'}
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          </section>
        ))}
      </div>
    )
  }

  const level = lab.levels[selected.level]
  const meta = LEVELS.find((l) => l.id === selected.level)
  const res = results[labKey(lab.id, selected.level)]
  return (
    <div className="lab">
      <aside className="card lab-panel">
        <button className="btn tiny" onClick={() => setSelected(null)}>← All labs</button>
        <h3>{lab.title}</h3>
        <p className="hint">{meta.icon} {meta.name} level{selected.level === EXAM_LEVEL ? ' · like the exam' : ''} · about {level.minutes} min · Terminal: ☰ → Terminal → New Terminal</p>
        <LessonBody markdown={lab.scenario} />
        {level.intro && <LessonBody markdown={level.intro} />}
        <LabTasks tasks={level.tasks} results={res} />
        {error && <pre className="lab-error">{error}</pre>}
        {res && res.every((r) => r.ok) && <p className="verdict yes">🎉 Lab passed!</p>}
        <div className="q-actions">
          <button className="btn primary" disabled={!!busy} onClick={() => check(lab, selected.level)}>{busy === 'check' ? '⏳ Checking…' : '✔ Check my work'}</button>
          <button className="btn" disabled={!!busy} onClick={() => start(lab, selected.level)}>{busy === 'start' ? '⏳ Resetting…' : '↺ Restart lab'}</button>
          <a className="btn" href="code/?folder=/home/coder/lab" target="_blank" rel="noreferrer">⤢ Editor in new tab</a>
        </div>
      </aside>
      <iframe key={editorKey} className="lab-editor" src="code/?folder=/home/coder/lab" title="Lab editor" />
    </div>
  )
}
