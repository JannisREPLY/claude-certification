import { useProgress } from '../lib/store.jsx'
import { DAILY_GOAL, dayKey, levelFor, currentStreak } from '../lib/game.js'
import { isDue } from '../lib/srs.js'
import { WEAK_DOMAIN } from '../lib/readiness.js'
import ReadinessBar from './ReadinessBar.jsx'
import SyncCard from './SyncCard.jsx'

export default function Dashboard({ cert, r, go }) {
  const { progress, replace, toast } = useProgress()
  const lvl = levelFor(progress.xp, cert.levelTitles)
  const today = progress.daily.day === dayKey() ? progress.daily.answered : 0
  const due = cert.questions.filter((q) => isDue(progress.cards[q.id])).length
  const unseen = cert.questions.filter((q) => !progress.cards[q.id]).length
  const weakest = [...r.domains].sort((a, b) => a.value - b.value)[0]
  const nextLesson = cert.lessons.find((l) => !progress.lessonsRead[l.id])
  const nextLab = cert.labs.find((l) => !progress.labs[l.id]?.completed)
  const accuracy = progress.answeredTotal ? Math.round((progress.correctTotal / progress.answeredTotal) * 100) : 0

  const exportData = () => {
    const blob = new Blob([JSON.stringify(progress, null, 1)], { type: 'application/json' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `${cert.id}-progress-${dayKey()}.json`
    a.click()
  }
  const importData = (e) => {
    const file = e.target.files[0]
    if (!file) return
    file.text().then((t) => {
      replace(JSON.parse(t))
      toast({ icon: '📥', text: 'Progress imported' })
    })
  }
  const reset = () => {
    if (confirm('Reset all progress for this certification?')) replace({})
  }

  return (
    <div className="grid">
      <section className="card span2">
        <ReadinessBar r={r} exam={cert.exam} />
      </section>

      <section className="card">
        <h3>Next up</h3>
        <div className="actions">
          {nextLesson && <button className="btn" onClick={() => go('learn', { lesson: nextLesson.id })}>📚 Study “{nextLesson.title}”</button>}
          {nextLab && <button className="btn" onClick={() => go('lab')}>🧪 Lab: “{nextLab.title}”</button>}
          <button className="btn primary" onClick={() => go('practice', { mode: 'smart' })}>🎯 Smart session · {due} due · {unseen} new</button>
          {weakest && weakest.value < WEAK_DOMAIN && <button className="btn" onClick={() => go('practice', { mode: 'domain', id: weakest.id })}>💪 Drill weakest: {weakest.name}</button>}
          <button className="btn" onClick={() => go('exam')}>📝 Mock exam ({cert.exam.items} Q · {cert.exam.minutes} min)</button>
        </div>
      </section>

      <section className="card">
        <h3>Today</h3>
        <div className="today">
          <Ring value={Math.min(today / DAILY_GOAL, 1)} label={`${today}/${DAILY_GOAL}`} />
          <div>
            <p>🔥 <b>{currentStreak(progress)}</b> day streak</p>
            <p>⭐ Level <b>{lvl.level}</b> — {lvl.title}</p>
            <p>🎯 Accuracy <b>{accuracy}%</b> over {progress.answeredTotal} answers</p>
            <p>⚡ Best combo <b>{progress.bestCombo}</b></p>
          </div>
        </div>
      </section>

      <section className="card span2">
        <h3>Domain mastery <small>(weighted like the exam; readiness = weighted average)</small></h3>
        {r.domains.map((d) => (
          <div key={d.id} className="domain-row">
            <div className="domain-label">
              <span>{d.name}</span>
              <small>{Math.round(d.weight * 100)}% of exam · {d.total} questions{d.labTasks ? ` · ${d.labTasks} lab tasks` : ''}</small>
            </div>
            <div className="track small"><div className={`fill ${d.value >= WEAK_DOMAIN ? 'good' : ''}`} style={{ width: `${d.value * 100}%` }} /></div>
            <span className="domain-pct">{Math.round(d.value * 100)}%</span>
            <button className="btn tiny" onClick={() => go('practice', { mode: 'domain', id: d.id })}>Drill</button>
          </div>
        ))}
        <p className="hint">A question counts as mastered after {4} correct answers on separate, spaced reviews (1, 3, 7 days). Wrong answers reset it.</p>
      </section>

      {progress.exams.length > 0 && (
        <section className="card span2">
          <h3>Mock exam history</h3>
          <div className="exam-history">
            {progress.exams.slice(-10).reverse().map((e) => (
              <div key={e.ts} className={`exam-chip ${e.passed ? 'pass' : 'fail'}`}>
                <b>{e.score}</b>
                <small>{new Date(e.ts).toLocaleDateString()}</small>
              </div>
            ))}
          </div>
        </section>
      )}

      <SyncCard />

      <section className="card span2 data">
        <h3>Your data</h3>
        <p className="hint">Progress is stored in this browser. Export it as a backup or to move to another device.</p>
        <button className="btn tiny" onClick={exportData}>⬇️ Export</button>
        <label className="btn tiny">⬆️ Import<input type="file" accept="application/json" hidden onChange={importData} /></label>
        <button className="btn tiny danger" onClick={reset}>Reset</button>
      </section>
    </div>
  )
}

function Ring({ value, label }) {
  const c = 2 * Math.PI * 42
  return (
    <svg className="ring" viewBox="0 0 100 100">
      <circle cx="50" cy="50" r="42" className="ring-bg" />
      <circle cx="50" cy="50" r="42" className="ring-fg" strokeDasharray={c} strokeDashoffset={c * (1 - value)} />
      <text x="50" y="47" textAnchor="middle">{label}</text>
      <text x="50" y="64" textAnchor="middle" className="ring-sub">daily goal</text>
    </svg>
  )
}
