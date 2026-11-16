import { certs } from '../certs/index.js'
import { load } from '../lib/store.jsx'
import { readiness } from '../lib/readiness.js'
import { levelFor, currentStreak } from '../lib/game.js'
import { isDue } from '../lib/srs.js'

export default function CertPicker({ onPick }) {
  return (
    <div className="app">
      <header className="topbar">
        <div className="brand"><span className="logo">🎓</span> Cert Trainer</div>
      </header>
      <h2>Which certification do you want to work on?</h2>
      <div className="cert-grid">
        {certs.map((c) => {
          const p = load(c.id)
          const r = readiness(c, p)
          const due = c.questions.filter((q) => p.cards[q.id] && isDue(p.cards[q.id])).length
          const labsDone = c.labs.filter((l) => p.labs[l.id]?.completed).length
          return (
            <button key={c.id} className={`cert-card ${r.ready ? 'ready' : ''}`} onClick={() => onPick(c.id)}>
              <small>{c.shortTitle}</small>
              <h3>{c.title}</h3>
              <div className="track small"><div className="fill" style={{ width: `${r.percent}%` }} /><div className="marker" style={{ left: `${r.passPercent}%` }} /></div>
              <p><b>{r.percent}%</b> ready · pass at {r.passPercent}%{r.ready ? ' · ✅' : ''}</p>
              <p className="hint">
                ⭐ Lv {levelFor(p.xp).level} · 🔥 {currentStreak(p)} · 🎯 {due} due · 📚 {Object.keys(p.lessonsRead).length}/{c.lessons.length} lessons
                {c.labs.length > 0 && ` · 🧪 ${labsDone}/${c.labs.length} labs`}
              </p>
            </button>
          )
        })}
      </div>
    </div>
  )
}
