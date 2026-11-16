import { useEffect, useState } from 'react'
import confetti from 'canvas-confetti'
import { useProgress } from '../lib/store.jsx'
import { shuffle, smartSession } from '../lib/quiz.js'
import QuestionCard from './QuestionCard.jsx'

const LIGHTNING_SECONDS = 45

function buildQuestions(cert, cards, launch) {
  const size = launch.size || 10
  const pool = (f) => shuffle(cert.questions.filter(f)).slice(0, size)
  switch (launch.mode) {
    case 'domain': return pool((q) => q.domain === launch.id)
    case 'scenario': return pool((q) => q.scenario === launch.id)
    case 'mistakes': return pool((q) => cards[q.id] && cards[q.id].box === 0 && cards[q.id].wrong > 0)
    case 'lightning': return pool(() => true)
    case 'all': return pool(() => true)
    default: return smartSession(cert, cards, size)
  }
}

export default function Practice({ cert, launch }) {
  const { progress } = useProgress()
  const [session, setSession] = useState(() => (launch?.mode ? { ...launch, questions: buildQuestions(cert, progress.cards, launch) } : null))
  if (session) return <Session cert={cert} session={session} onExit={() => setSession(null)} />

  const mistakes = cert.questions.filter((q) => progress.cards[q.id]?.box === 0 && progress.cards[q.id].wrong > 0).length
  const start = (l) => setSession({ ...l, questions: buildQuestions(cert, progress.cards, l) })
  const count = (f) => cert.questions.filter(f).length

  return (
    <div className="grid">
      <section className="card span2 modes">
        <ModeTile icon="🧠" title="Smart session" desc="Due reviews first, then new questions from your weakest domain." onClick={() => start({ mode: 'smart' })} primary />
        <ModeTile icon="⚡" title="Lightning round" desc={`10 random questions, ${LIGHTNING_SECONDS}s each. Keep the combo alive!`} onClick={() => start({ mode: 'lightning' })} />
        <ModeTile icon="🩹" title={`Fix mistakes (${mistakes})`} desc="Questions you last answered wrong." disabled={!mistakes} onClick={() => start({ mode: 'mistakes' })} />
        <ModeTile icon="🎲" title="Random 20" desc="Any question from the whole bank." onClick={() => start({ mode: 'all', size: 20 })} />
      </section>
      <section className="card">
        <h3>Drill a domain</h3>
        {cert.domains.map((d) => (
          <button key={d.id} className="list-btn" onClick={() => start({ mode: 'domain', id: d.id })}>
            <span className={`dot ${d.id}`} /> {d.name} <small>{count((q) => q.domain === d.id)}</small>
          </button>
        ))}
      </section>
      <section className="card">
        <h3>Drill a scenario</h3>
        {cert.scenarios.filter((s) => count((q) => q.scenario === s.id)).map((s) => (
          <button key={s.id} className="list-btn" onClick={() => start({ mode: 'scenario', id: s.id })}>
            🎬 {s.name} <small>{count((q) => q.scenario === s.id)}</small>
          </button>
        ))}
      </section>
    </div>
  )
}

function ModeTile({ icon, title, desc, onClick, primary, disabled }) {
  return (
    <button className={`mode ${primary ? 'primary' : ''}`} onClick={onClick} disabled={disabled}>
      <span className="mode-icon">{icon}</span>
      <b>{title}</b>
      <small>{desc}</small>
    </button>
  )
}

function Session({ cert, session, onExit }) {
  const { answer } = useProgress()
  const [idx, setIdx] = useState(0)
  const [combo, setCombo] = useState(0)
  const [stats, setStats] = useState({ correct: 0, xp: 0 })
  const [float, setFloat] = useState(null)
  const [left, setLeft] = useState(LIGHTNING_SECONDS)
  const [answered, setAnswered] = useState(false)
  const lightning = session.mode === 'lightning'
  const q = session.questions[idx]

  useEffect(() => {
    if (!lightning || answered || !q) return
    if (left <= 0) return
    const t = setTimeout(() => setLeft((s) => s - 1), 1000)
    return () => clearTimeout(t)
  }, [lightning, answered, left, q])

  if (!session.questions.length) {
    return (
      <div className="card center">
        <h2>Nothing to practise here yet 🎉</h2>
        <button className="btn" onClick={onExit}>Back</button>
      </div>
    )
  }

  if (!q) {
    const pct = Math.round((stats.correct / session.questions.length) * 100)
    return (
      <div className="card center summary">
        <div className="big-emoji">{pct >= 80 ? '🏆' : pct >= 60 ? '💪' : '📚'}</div>
        <h2>{stats.correct}/{session.questions.length} correct ({pct}%)</h2>
        <p>+{stats.xp} XP earned</p>
        <button className="btn primary" onClick={onExit}>Done</button>
      </div>
    )
  }

  const onAnswered = (ok, hinted) => {
    setAnswered(true)
    const nextCombo = ok && !hinted ? combo + 1 : 0
    const gained = answer(q.id, ok, nextCombo, hinted)
    setCombo(nextCombo)
    setStats((s) => ({ correct: s.correct + (ok ? 1 : 0), xp: s.xp + gained }))
    setFloat({ gained, key: Math.random() })
    if (ok && nextCombo > 0 && nextCombo % 5 === 0) confetti({ particleCount: 80, spread: 60, origin: { y: 0.8 } })
  }
  const onNext = () => {
    setIdx((i) => i + 1)
    setAnswered(false)
    setLeft(LIGHTNING_SECONDS)
  }

  return (
    <div className="session">
      <div className="session-bar">
        <button className="btn tiny" onClick={onExit}>✕ Quit</button>
        <div className="track small"><div className="fill" style={{ width: `${(idx / session.questions.length) * 100}%` }} /></div>
        <span>{idx + 1}/{session.questions.length}</span>
        <span className={`combo ${combo >= 3 ? 'hot' : ''}`}>🔥 x{combo}</span>
        {float && <span key={float.key} className="xp-float">+{float.gained} XP</span>}
      </div>
      <QuestionCard
        key={q.id + idx}
        q={q}
        cert={cert}
        onAnswered={onAnswered}
        onNext={onNext}
        timer={lightning ? { fraction: left / LIGHTNING_SECONDS, expired: left <= 0 } : null}
      />
    </div>
  )
}
