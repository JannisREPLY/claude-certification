import { mastery } from './srs.js'

export const WEAK_DOMAIN = 0.6

export function domainMastery(cert, progress) {
  return cert.domains.map((d) => {
    const qs = cert.questions.filter((q) => q.domain === d.id)
    const tasks = cert.labs.filter((l) => l.domain === d.id).flatMap((l) => l.tasks.map((t) => !!progress.labs[l.id]?.tasks[t.id]))
    const items = qs.length + tasks.length
    const sum = qs.reduce((s, q) => s + mastery(progress.cards[q.id]), 0) + tasks.filter(Boolean).length
    return { ...d, value: items ? sum / items : 0, total: qs.length, labTasks: tasks.length }
  })
}

export function scaled(fraction, exam) {
  return Math.round(exam.minScore + (exam.maxScore - exam.minScore) * fraction)
}

export function readiness(cert, progress) {
  const domains = domainMastery(cert, progress)
  const weightSum = domains.reduce((s, d) => s + d.weight, 0)
  const fraction = domains.reduce((s, d) => s + d.weight * d.value, 0) / weightSum
  const passFraction = (cert.exam.passScore - cert.exam.minScore) / (cert.exam.maxScore - cert.exam.minScore)
  const percent = Math.round(fraction * 100)
  const passPercent = Math.round(passFraction * 100)
  const lessonsRead = cert.lessons.filter((l) => progress.lessonsRead[l.id]).length
  const lastExam = progress.exams[progress.exams.length - 1]
  const checks = [
    { id: 'score', label: `Readiness ≥ ${passPercent}%`, ok: fraction >= passFraction },
    { id: 'domains', label: `Every domain ≥ ${WEAK_DOMAIN * 100}% mastered`, ok: domains.every((d) => d.value >= WEAK_DOMAIN) },
    { id: 'lessons', label: `All lessons studied (${lessonsRead}/${cert.lessons.length})`, ok: lessonsRead === cert.lessons.length },
    { id: 'mock', label: 'Latest mock exam passed', ok: !!lastExam && lastExam.passed },
  ]
  if (cert.labs.length) {
    const labsDone = cert.labs.filter((l) => progress.labs[l.id]?.completed).length
    checks.push({ id: 'labs', label: `All labs passed (${labsDone}/${cert.labs.length})`, ok: labsDone === cert.labs.length })
  }
  return { percent, passPercent, domains, checks, ready: checks.every((c) => c.ok) }
}
