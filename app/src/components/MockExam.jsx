import { useEffect, useState } from 'react'
import confetti from 'canvas-confetti'
import { useProgress } from '../lib/store.jsx'
import { buildMockExam, examScenarios, isAnswerCorrect, correctCount } from '../lib/quiz.js'
import { scaled } from '../lib/readiness.js'
import { EXAM_LEVEL, gradeFullExam } from '../lib/labs.js'
import { Options, QuestionHead, Explanation, useShuffledOptions } from './QuestionCard.jsx'
import { LabTasks, labApi } from './Lab.jsx'
import LessonBody from './LessonBody.jsx'

export function gradeExam(cert, questions, answers) {
  const results = questions.map((q) => ({ q, ok: isAnswerCorrect(q, answers[q.id] || []) }))
  const correct = results.filter((r) => r.ok).length
  const score = scaled(correct / questions.length, cert.exam)
  const perDomain = cert.domains.map((d) => {
    const rs = results.filter((r) => r.q.domain === d.id)
    return { id: d.id, name: d.name, correct: rs.filter((r) => r.ok).length, total: rs.length }
  }).filter((d) => d.total)
  return { results, correct, score, passed: score >= cert.exam.passScore, perDomain }
}

const runKey = (cert) => `mock-run:${cert.id}`
const loadRun = (cert) => {
  try {
    return JSON.parse(localStorage.getItem(runKey(cert)))
  } catch {
    return null
  }
}
const secondsLeft = (run) => Math.max(0, Math.round(run.minutes * 60 - (Date.now() - run.startedAt) / 1000))

export default function MockExam({ cert }) {
  const [run, setRunState] = useState(() => loadRun(cert))
  const [report, setReport] = useState(null)
  const [online, setOnline] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState(null)
  const available = examScenarios(cert)
  const hasLabs = cert.mockLabs.length > 0

  useEffect(() => {
    if (hasLabs) labApi('status').then(() => setOnline(true)).catch(() => setOnline(false))
  }, [cert, hasLabs])

  const setRun = (next) => {
    setRunState(next)
    next ? localStorage.setItem(runKey(cert), JSON.stringify(next)) : localStorage.removeItem(runKey(cert))
  }

  const begin = async (mode) => {
    setError(null)
    if (mode === 'full') {
      if (!confirm('Start the full mock exam? This resets the lab folder and the emulated AWS account, then sets up all exam labs.')) return
      setBusy(true)
      try {
        const r = await labApi('exam/start?force=1', 'POST')
        if (!r.ok) throw new Error(`Exam setup failed:\n${r.output}`)
      } catch (e) {
        setError(e.message)
        return
      } finally {
        setBusy(false)
      }
    }
    const qs = buildMockExam(cert)
    setRun({ mode, startedAt: Date.now(), minutes: mode === 'full' ? cert.exam.minutes : cert.exam.questionMinutes || cert.exam.minutes, qids: qs.map((q) => q.id), answers: {}, flags: {} })
  }

  if (report) return <Report cert={cert} report={report} onClose={() => setReport(null)} />
  if (run) return <Exam cert={cert} run={run} setRun={setRun} onDone={(r) => { setRun(null); setReport(r) }} />

  const enough = available.length >= cert.exam.scenariosPerExam
  return (
    <div className="card center exam-intro">
      <div className="big-emoji">📝</div>
      <h2>Mock exam</h2>
      {hasLabs ? (
        <>
          <p>{cert.mockLabs.length} labs + {cert.exam.items} questions · {cert.exam.minutes / 60} hours · pass at {cert.exam.passScore}%</p>
          <p className="hint">Like the real exam: the labs use their own scenarios (not the practice labs), you can switch between labs and questions at any time, and nothing is graded before you submit. Each lab and the question block count {Math.round(100 / (cert.mockLabs.length + 1))}% each. The weighting and the pass mark are estimates; HashiCorp doesn't publish them.</p>
          {error && <pre className="lab-error">{error}</pre>}
          <div className="actions">
            <button className="btn primary big" disabled={!online || !enough || busy} title={online ? undefined : 'Needs the local Docker stack'} onClick={() => begin('full')}>{busy ? '⏳ Setting up the labs…' : '▶ Start full exam'}</button>
            <button className="btn" disabled={!enough || busy} onClick={() => begin('questions')}>Questions only · {cert.exam.questionMinutes} min</button>
          </div>
          {!online && <p className="hint">🔒 The labs need the local Docker stack. Without it you can take the questions only.</p>}
        </>
      ) : (
        <>
          <p>{cert.exam.items} questions · {cert.exam.minutes} minutes · {cert.exam.scenariosPerExam} random scenarios · pass at {cert.exam.passScore}</p>
          <p className="hint">Scenario pool: {available.map((s) => s.name).join(', ')}.<br />The score is an estimate: correct share mapped linearly onto {cert.exam.minScore}–{cert.exam.maxScore}. The real exam uses scaled scoring.</p>
          {enough ? <button className="btn primary big" onClick={() => begin('questions')}>Start exam</button> : <p>Not enough scenarios with questions yet.</p>}
        </>
      )}
    </div>
  )
}

function Exam({ cert, run, setRun, onDone }) {
  const { answer, finishExam } = useProgress()
  const questions = run.qids.map((id) => cert.questions.find((q) => q.id === id)).filter(Boolean)
  const labs = run.mode === 'full' ? cert.mockLabs : []
  const [section, setSection] = useState('questions')
  const [idx, setIdx] = useState(0)
  const [, tick] = useState(0)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState(null)
  const left = secondsLeft(run)
  const q = questions[idx]
  const update = (patch) => setRun({ ...run, ...patch })

  const submit = async () => {
    setSubmitting(true)
    setError(null)
    let labResults = {}
    if (labs.length) {
      try {
        labResults = (await labApi('exam/check', 'POST')).labs
      } catch (e) {
        setSubmitting(false)
        return setError(`Grading the labs failed: ${e.message}`)
      }
    }
    const g = gradeExam(cert, questions, run.answers)
    g.results.filter((r) => (run.answers[r.q.id] || []).length).forEach((r) => answer(r.q.id, r.ok, 0))
    const full = labs.length ? gradeFullExam(cert, { correct: g.correct, total: questions.length }, labResults) : null
    const score = full ? full.score : g.score
    const passed = full ? full.passed : g.passed
    finishExam({ mode: run.mode, score, passed, correct: g.correct, total: questions.length, perDomain: g.perDomain, parts: full?.parts.map(({ id, name, correct, total }) => ({ id, name, correct, total })), durationSec: Math.round((Date.now() - run.startedAt) / 1000) })
    if (passed) confetti({ particleCount: 250, spread: 120, origin: { y: 0.6 } })
    onDone({ ...g, score, passed, parts: full?.parts, answers: run.answers })
  }

  useEffect(() => {
    if (left <= 0 && !submitting) {
      submit()
      return
    }
    const t = setInterval(() => tick((n) => n + 1), 1000)
    return () => clearInterval(t)
  }, [left <= 0])

  const answeredCount = questions.filter((x) => (run.answers[x.id] || []).length === correctCount(x)).length
  const hh = Math.floor(left / 3600)
  const mm = String(Math.floor((left % 3600) / 60)).padStart(2, '0')
  const ss = String(left % 60).padStart(2, '0')
  const lab = labs.find((l) => l.id === section)

  return (
    <div className="exam">
      <div className="session-bar">
        <button className="btn tiny" onClick={() => confirm('Abort exam? Your answers and lab work are not graded.') && setRun(null)}>✕ Abort</button>
        <span className={`clock ${left < 600 ? 'low' : ''}`}>⏱ {hh ? `${hh}:` : ''}{mm}:{ss}</span>
        <span>{answeredCount}/{questions.length} answered</span>
        <button className="btn tiny primary" disabled={submitting} onClick={() => confirm(`Submit the exam${labs.length ? ' and grade the labs' : ''}? ${questions.length - answeredCount} questions are unanswered.`) && submit()}>{submitting ? '⏳ Grading…' : 'Submit'}</button>
      </div>
      {error && <pre className="lab-error">{error}</pre>}
      {labs.length > 0 && (
        <div className="exam-sections">
          <button className={`btn tiny ${section === 'questions' ? 'primary' : ''}`} onClick={() => setSection('questions')}>📝 Questions</button>
          {labs.map((l, i) => (
            <button key={l.id} className={`btn tiny ${section === l.id ? 'primary' : ''}`} onClick={() => setSection(l.id)}>🧪 Lab {i + 1}</button>
          ))}
        </div>
      )}
      {lab ? (
        <div className="lab">
          <aside className="card lab-panel">
            <h3>{lab.title}</h3>
            <p className="hint">Folder <code>/home/coder/exam/{lab.id}</code> · about {lab.levels[EXAM_LEVEL].minutes} min · Terminal: ☰ → Terminal → New Terminal</p>
            <LessonBody markdown={lab.scenario} />
            <LabTasks tasks={lab.levels[EXAM_LEVEL].tasks} />
          </aside>
          <iframe key={lab.id} className="lab-editor" src={`code/?folder=/home/coder/exam/${lab.id}`} title="Exam lab editor" />
        </div>
      ) : (
        <>
          <div className="exam-nav">
            {questions.map((x, i) => (
              <button key={x.id} className={`nav-cell ${i === idx ? 'cur' : ''} ${(run.answers[x.id] || []).length ? 'done' : ''} ${run.flags[x.id] ? 'flag' : ''}`} onClick={() => setIdx(i)}>{i + 1}</button>
            ))}
          </div>
          <ExamQuestion key={q.id} cert={cert} q={q} n={idx + 1} selected={run.answers[q.id] || []} setSelected={(s) => update({ answers: { ...run.answers, [q.id]: s } })} />
          <div className="exam-controls">
            <button className="btn" disabled={idx === 0} onClick={() => setIdx(idx - 1)}>← Previous</button>
            <button className={`btn ${run.flags[q.id] ? 'warn' : ''}`} onClick={() => update({ flags: { ...run.flags, [q.id]: !run.flags[q.id] } })}>🚩 {run.flags[q.id] ? 'Flagged' : 'Flag for review'}</button>
            <button className="btn primary" disabled={idx === questions.length - 1} onClick={() => setIdx(idx + 1)}>Next →</button>
          </div>
        </>
      )}
    </div>
  )
}

function ExamQuestion({ cert, q, n, selected, setSelected }) {
  const order = useShuffledOptions(q)
  return (
    <div className="card question">
      <p className="hint">Question {n}</p>
      <QuestionHead q={q} cert={cert} />
      <Options q={q} order={order} selected={selected} setSelected={setSelected} revealed={false} />
    </div>
  )
}

function Report({ cert, report, onClose }) {
  const [showAll, setShowAll] = useState(false)
  const list = report.results.filter((r) => showAll || !r.ok)
  const unit = report.parts ? '%' : ` / ${cert.exam.maxScore}`
  return (
    <div className="grid">
      <section className={`card span2 center summary ${report.passed ? 'pass' : 'fail'}`}>
        <div className="big-emoji">{report.passed ? '🏆' : '📚'}</div>
        <h2>{report.score}{unit} — {report.passed ? 'PASS' : 'Not yet'}</h2>
        <p>{report.correct}/{report.results.length} questions correct · pass mark {cert.exam.passScore}{report.parts ? '%' : ''}</p>
        <div className="per-domain">
          {(report.parts || report.perDomain).map((d) => (
            <div key={d.id} className="domain-row">
              <div className="domain-label"><span>{d.name}</span></div>
              <div className="track small"><div className={`fill ${d.correct / d.total >= 0.7 ? 'good' : ''}`} style={{ width: `${(d.correct / d.total) * 100}%` }} /></div>
              <span className="domain-pct">{d.correct}/{d.total}</span>
            </div>
          ))}
        </div>
        <button className="btn" onClick={onClose}>Back</button>
      </section>
      {report.parts?.filter((p) => p.results).map((p) => {
        const lab = cert.mockLabs.find((l) => l.id === p.id)
        return (
          <section key={p.id} className="card span2">
            <h3>🧪 {p.name} · {p.correct}/{p.total} tasks</h3>
            <LabTasks tasks={lab.levels[EXAM_LEVEL].tasks} results={p.results} />
          </section>
        )
      })}
      <section className="card span2">
        <h3>Review <label className="hint"><input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} /> show correct answers too</label></h3>
        {list.map(({ q, ok }) => (
          <div key={q.id} className="review-item">
            <div className={`verdict ${ok ? 'yes' : 'no'}`}>{ok ? '✅' : '❌'}</div>
            <QuestionHead q={q} cert={cert} />
            <ReviewOptions q={q} selected={report.answers[q.id] || []} />
            <Explanation q={q} />
          </div>
        ))}
      </section>
    </div>
  )
}

function ReviewOptions({ q, selected }) {
  const order = q.options.map((o, i) => ({ ...o, i }))
  return <Options q={q} order={order} selected={selected} setSelected={() => {}} revealed />
}
