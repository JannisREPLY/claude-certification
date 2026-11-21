import { scaled } from './readiness.js'

export const LEVELS = [
  { id: 'guided', icon: '🧭', name: 'Guided', desc: 'Smaller tasks with hints' },
  { id: 'exam', icon: '🎯', name: 'Exam', desc: 'Like the exam' },
  { id: 'expert', icon: '🔥', name: 'Expert', desc: 'Harder than the exam' },
]
export const EXAM_LEVEL = 'exam'

export const labKey = (labId, level) => `${labId}:${level}`

export const labLevels = (lab) => LEVELS.filter((l) => lab.levels[l.id])

export const labRecord = (progress, labId, level = EXAM_LEVEL) => progress.labs[labKey(labId, level)]

export const labPassed = (progress, labId, level = EXAM_LEVEL) => !!labRecord(progress, labId, level)?.completed

export function gradeFullExam(cert, mcq, labResults) {
  const parts = [
    { id: 'mcq', name: 'Multiple choice', correct: mcq.correct, total: mcq.total },
    ...cert.mockLabs.map((l) => {
      const results = labResults[l.id] || []
      return { id: l.id, name: l.title, correct: results.filter((r) => r.ok).length, total: l.levels[EXAM_LEVEL].tasks.length, results }
    }),
  ]
  const fraction = parts.reduce((s, p) => s + (p.total ? p.correct / p.total : 0), 0) / parts.length
  const score = scaled(fraction, cert.exam)
  return { parts, score, passed: score >= cert.exam.passScore }
}
