import { useEffect, useMemo, useState } from 'react'
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { correctCount, isAnswerCorrect, shuffle } from '../lib/quiz.js'
import HintModal from './HintModal.jsx'

const LETTERS = 'ABCDEFGH'

export function useShuffledOptions(q) {
  return useMemo(() => shuffle(q.options.map((o, i) => ({ ...o, i }))), [q])
}

export function Options({ q, order, selected, setSelected, revealed }) {
  const multi = correctCount(q) > 1
  const toggle = (i) => {
    if (revealed) return
    if (!multi) return setSelected([i])
    setSelected(selected.includes(i) ? selected.filter((x) => x !== i) : [...selected, i])
  }
  return (
    <div className="options">
      {order.map((o) => {
        const picked = selected.includes(o.i)
        const cls = revealed ? (o.correct ? 'correct' : picked ? 'wrong' : 'muted') : picked ? 'picked' : ''
        return (
          <button key={o.i} className={`option ${cls}`} onClick={() => toggle(o.i)}>
            <span className="opt-mark">{revealed ? LETTERS[o.i] : multi ? (picked ? '☑' : '☐') : picked ? '●' : '○'}</span>
            <span className="md-inline"><Markdown>{o.text}</Markdown></span>
          </button>
        )
      })}
    </div>
  )
}

export function QuestionHead({ q, cert }) {
  const scen = cert.scenarios.find((s) => s.id === q.scenario)
  const dom = cert.domains.find((d) => d.id === q.domain)
  const n = correctCount(q)
  return (
    <>
      <div className="q-meta">
        {scen && <span className="tag">🎬 {scen.name}</span>}
        {dom && <span className={`tag ${dom.id}`}>{dom.name}</span>}
        {q.source === 'ai-draft' && <span className="tag draft" title="Drafted by AI from the study guide, not from the official exam materials">🤖 AI-drafted</span>}
      </div>
      <div className="situation md"><Markdown remarkPlugins={[remarkGfm]}>{q.situation}</Markdown></div>
      <div className="q-text md md-inline"><Markdown>{q.question + (n > 1 && !/select/i.test(q.question) ? ` (Select ${n}.)` : '')}</Markdown></div>
    </>
  )
}

export function Explanation({ q }) {
  return (
    <div className="explanation md">
      <p className="hint">Letters refer to the original option order shown on each answer.</p>
      <Markdown remarkPlugins={[remarkGfm]}>{q.explanation}</Markdown>
    </div>
  )
}

export default function QuestionCard({ q: question, cert, onAnswered, onNext, timer, noHint }) {
  const q = noHint ? { ...question, hint: null } : question
  const order = useShuffledOptions(question)
  const [selected, setSelected] = useState([])
  const [result, setResult] = useState(null)
  const [hinted, setHinted] = useState(false)
  const [showHint, setShowHint] = useState(false)
  const openHint = () => {
    if (result === null) setHinted(true)
    setShowHint(true)
  }
  const submit = () => {
    const ok = isAnswerCorrect(q, selected)
    setResult(ok)
    onAnswered(ok, hinted)
  }
  useEffect(() => {
    if (timer?.expired && result === null) {
      setResult(false)
      onAnswered(false, hinted)
    }
  }, [timer?.expired])
  return (
    <div className="card question">
      {timer && result === null && <div className="q-timer"><div style={{ width: `${timer.fraction * 100}%` }} /></div>}
      <QuestionHead q={q} cert={cert} />
      <Options q={q} order={order} selected={selected} setSelected={setSelected} revealed={result !== null} />
      {result === null ? (
        <div className="q-actions">
          <button className="btn primary" disabled={selected.length !== correctCount(q)} onClick={submit}>Check answer</button>
          {q.hint && <button className="btn" onClick={openHint} title="Opens the theory section. A correct answer after a hint gives half XP and doesn't count towards mastery.">💡 {hinted ? 'Hint used' : 'Hint: read the theory'}</button>}
        </div>
      ) : (
        <>
          <div className={`verdict ${result ? 'yes' : 'no'}`}>{result ? (hinted ? '🎉 Correct (with hint)' : '🎉 Correct!') : timer?.expired ? '⏰ Time is up!' : '❌ Not quite.'}</div>
          <Explanation q={q} />
          <div className="q-actions">
            <button className="btn primary" autoFocus onClick={onNext}>Continue →</button>
            {q.hint && <button className="btn" onClick={openHint}>📖 Read the theory</button>}
          </div>
        </>
      )}
      {showHint && <HintModal cert={cert} hint={q.hint} onClose={() => setShowHint(false)} />}
    </div>
  )
}
