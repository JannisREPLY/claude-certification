import { useEffect, useState } from 'react'
import confetti from 'canvas-confetti'
import { useProgress } from '../lib/store.jsx'
import { buildMockExam, examScenarios, isAnswerCorrect, correctCount } from '../lib/quiz.js'
import { scaled } from '../lib/readiness.js'
import { Options, QuestionHead, Explanation, useShuffledOptions } from './QuestionCard.jsx'

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

export default function MockExam({ cert }) {
  const [exam, setExam] = useState(null)
  const [report, setReport] = useState(null)
  const available = examScenarios(cert)

  if (report) return <Report cert={cert} report={report} onClose={() => setReport(null)} />
  if (exam) return <Exam cert={cert} questions={exam} onDone={(r) => { setExam(null); setReport(r) }} onAbort={() => setExam(null)} />

  return (
    <div className="card center exam-intro">
      <div className="big-emoji">📝</div>
      <h2>Mock exam</h2>
      <p>{cert.exam.items} questions · {cert.exam.minutes} minutes · {cert.exam.scenariosPerExam} random scenarios · pass at {cert.exam.passScore}</p>
      <p className="hint">Scenario pool: {available.map((s) => s.name).join(', ')}.<br />The score is an estimate: correct share mapped linearly onto {cert.exam.minScore}–{cert.exam.maxScore}. The real exam uses scaled scoring.</p>
      {available.length >= cert.exam.scenariosPerExam ? (
        <button className="btn primary big" onClick={() => setExam(buildMockExam(cert))}>Start exam</button>
      ) : (
        <p>Not enough scenarios with questions yet.</p>
      )}
    </div>
  )
}

function Exam({ cert, questions, onDone, onAbort }) {
  const { answer, finishExam } = useProgress()
  const [idx, setIdx] = useState(0)
  const [answers, setAnswers] = useState({})
  const [flags, setFlags] = useState({})
  const [left, setLeft] = useState(cert.exam.minutes * 60)
  const [started] = useState(Date.now())
  const q = questions[idx]

  const submit = () => {
    const g = gradeExam(cert, questions, answers)
    g.results.filter((r) => (answers[r.q.id] || []).length).forEach((r) => answer(r.q.id, r.ok, 0))
    finishExam({ score: g.score, passed: g.passed, correct: g.correct, total: questions.length, perDomain: g.perDomain, durationSec: Math.round((Date.now() - started) / 1000) })
    if (g.passed) confetti({ particleCount: 250, spread: 120, origin: { y: 0.6 } })
    onDone({ ...g, answers })
  }

  useEffect(() => {
    if (left <= 0) return submit()
    const t = setTimeout(() => setLeft((s) => s - 1), 1000)
    return () => clearTimeout(t)
  }, [left])

  const answeredCount = questions.filter((x) => (answers[x.id] || []).length === correctCount(x)).length
  const mm = String(Math.floor(left / 60)).padStart(2, '0')
  const ss = String(left % 60).padStart(2, '0')

  return (
    <div className="exam">
      <div className="session-bar">
        <button className="btn tiny" onClick={() => confirm('Abort exam? Progress in this exam is lost.') && onAbort()}>✕ Abort</button>
        <span className={`clock ${left < 600 ? 'low' : ''}`}>⏱ {mm}:{ss}</span>
        <span>{answeredCount}/{questions.length} answered</span>
        <button className="btn tiny primary" onClick={() => confirm(`Submit with ${questions.length - answeredCount} unanswered?`) && submit()}>Submit</button>
      </div>
      <div className="exam-nav">
        {questions.map((x, i) => (
          <button key={x.id} className={`nav-cell ${i === idx ? 'cur' : ''} ${(answers[x.id] || []).length ? 'done' : ''} ${flags[x.id] ? 'flag' : ''}`} onClick={() => setIdx(i)}>{i + 1}</button>
        ))}
      </div>
      <ExamQuestion key={q.id} cert={cert} q={q} n={idx + 1} selected={answers[q.id] || []} setSelected={(s) => setAnswers({ ...answers, [q.id]: s })} />
      <div className="exam-controls">
        <button className="btn" disabled={idx === 0} onClick={() => setIdx(idx - 1)}>← Previous</button>
        <button className={`btn ${flags[q.id] ? 'warn' : ''}`} onClick={() => setFlags({ ...flags, [q.id]: !flags[q.id] })}>🚩 {flags[q.id] ? 'Flagged' : 'Flag for review'}</button>
        <button className="btn primary" disabled={idx === questions.length - 1} onClick={() => setIdx(idx + 1)}>Next →</button>
      </div>
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
  return (
    <div className="grid">
      <section className={`card span2 center summary ${report.passed ? 'pass' : 'fail'}`}>
        <div className="big-emoji">{report.passed ? '🏆' : '📚'}</div>
        <h2>{report.score} / {cert.exam.maxScore} — {report.passed ? 'PASS' : 'Not yet'}</h2>
        <p>{report.correct}/{report.results.length} correct · pass mark {cert.exam.passScore}</p>
        <div className="per-domain">
          {report.perDomain.map((d) => (
            <div key={d.id} className="domain-row">
              <div className="domain-label"><span>{d.name}</span></div>
              <div className="track small"><div className={`fill ${d.correct / d.total >= 0.72 ? 'good' : ''}`} style={{ width: `${(d.correct / d.total) * 100}%` }} /></div>
              <span className="domain-pct">{d.correct}/{d.total}</span>
            </div>
          ))}
        </div>
        <button className="btn" onClick={onClose}>Back</button>
      </section>
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
