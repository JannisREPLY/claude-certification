import { useState } from 'react'
import LessonBody from './LessonBody.jsx'
import QuestionCard from './QuestionCard.jsx'
import { useProgress } from '../lib/store.jsx'
import { buildCheck, CHECK_SIZE, checkPool, nextQueue } from '../lib/check.js'

function LessonCheck({ cert, lesson }) {
  const { progress, answer, readLesson } = useProgress()
  const [queue, setQueue] = useState(null)
  const [round, setRound] = useState(0)
  const [combo, setCombo] = useState(0)
  const [last, setLast] = useState(null)
  const total = Math.min(checkPool(cert, lesson).length, CHECK_SIZE)

  if (!queue) {
    return (
      <div className="card lesson-check">
        <h3>🧠 Check yourself</h3>
        <p>Answer {total} question{total > 1 ? 's' : ''} about this lesson. Wrong answers come back until you get them right; then the lesson counts as studied and the next one unlocks.</p>
        <button className="btn primary" onClick={() => setQueue(buildCheck(cert, lesson, progress.cards))}>Start check</button>
      </div>
    )
  }

  const q = queue[0]
  const onAnswered = (ok) => {
    const nextCombo = ok ? combo + 1 : 0
    answer(q.id, ok, nextCombo)
    setCombo(nextCombo)
    setLast(ok)
  }
  const onNext = () => {
    const rest = nextQueue(queue, last)
    setQueue(rest)
    setRound((r) => r + 1)
    if (!rest.length) readLesson(lesson.id)
  }
  return (
    <div className="lesson-check">
      <h3>🧠 Check yourself · {total - queue.length}/{total} correct</h3>
      <QuestionCard key={q.id + round} q={q} cert={cert} onAnswered={onAnswered} onNext={onNext} noHint />
    </div>
  )
}

const GROUPS = [
  ['overview', 'Start here'],
  ['theory', 'Theory'],
  ['domain-notes', 'Exam domain notes'],
  ['reference', 'Reference & exercises'],
]

export default function Learn({ cert, go, initial }) {
  const { progress, readLesson } = useProgress()
  const [current, setCurrent] = useState(initial?.lesson || null)
  const lesson = cert.lessons.find((l) => l.id === current)
  const domainName = (id) => cert.domains.find((d) => d.id === id)?.name

  if (lesson) {
    const idx = cert.lessons.indexOf(lesson)
    const next = cert.lessons[idx + 1]
    const done = !!progress.lessonsRead[lesson.id]
    const hasCheck = checkPool(cert, lesson).length > 0
    const open = (id) => {
      setCurrent(id)
      window.scrollTo(0, 0)
    }
    return (
      <article className="card lesson">
        <button className="btn tiny" onClick={() => setCurrent(null)}>← All lessons</button>
        <h1>{lesson.title}</h1>
        {lesson.domain && <span className={`tag ${lesson.domain}`}>{domainName(lesson.domain)}</span>}
        <LessonBody markdown={lesson.markdown} />
        {!done && hasCheck && <LessonCheck key={lesson.id} cert={cert} lesson={lesson} />}
        <div className="lesson-footer">
          {(done || !hasCheck) && (
            <button className={`btn ${done ? '' : 'primary'}`} disabled={done} onClick={() => readLesson(lesson.id)}>
              {done ? '✅ Studied' : '✅ Mark as studied (+25 XP)'}
            </button>
          )}
          {lesson.domain && <button className="btn" onClick={() => go('practice', { mode: 'domain', id: lesson.domain, size: 5 })}>🧠 Quick check: 5 questions</button>}
          {next && (
            <button className="btn" disabled={!done && hasCheck} title={!done && hasCheck ? 'Pass the check above first' : undefined} onClick={() => open(next.id)}>
              {!done && hasCheck ? '🔒 ' : ''}Next: {next.title} →
            </button>
          )}
        </div>
      </article>
    )
  }

  return (
    <div className="lessons">
      {GROUPS.map(([kind, label]) => (
        <section key={kind} className="card">
          <h3>{label}</h3>
          <div className="lesson-grid">
            {cert.lessons.filter((l) => l.kind === kind).map((l) => (
              <button key={l.id} className={`lesson-tile ${progress.lessonsRead[l.id] ? 'done' : ''}`} onClick={() => setCurrent(l.id)}>
                <span className="check">{progress.lessonsRead[l.id] ? '✅' : '📄'}</span>
                <span>{l.title}</span>
                {l.domain && <span className={`dot ${l.domain}`} title={domainName(l.domain)} />}
              </button>
            ))}
          </div>
        </section>
      ))}
    </div>
  )
}
