import { useEffect } from 'react'
import LessonBody from './LessonBody.jsx'

export default function HintModal({ cert, hint, onClose }) {
  const lesson = cert.lessons.find((l) => l.id === hint.lesson)
  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  if (!lesson) return null
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <div>
            <small className="hint">💡 Theory for this question</small>
            <h3>{lesson.title}{hint.heading ? ` › ${hint.heading.replace(/[`*]/g, '')}` : ''}</h3>
          </div>
          <button className="btn tiny" onClick={onClose}>✕ Back to question</button>
        </div>
        <div className="modal-body">
          <LessonBody markdown={lesson.markdown} focus={hint.heading} />
        </div>
      </div>
    </div>
  )
}
