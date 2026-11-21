import { isDue, mastery } from './srs.js'

export function shuffle(list, rand = Math.random) {
  const a = [...list]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

export function correctCount(q) {
  return q.options.filter((o) => o.correct).length
}

export function isAnswerCorrect(q, selected) {
  const want = q.options.map((o, i) => (o.correct ? i : -1)).filter((i) => i >= 0)
  return selected.length === want.length && want.every((i) => selected.includes(i))
}

export function smartSession(cert, cards, size = 10, now = Date.now()) {
  const due = shuffle(cert.questions.filter((q) => isDue(cards[q.id], now)))
  const fresh = cert.questions.filter((q) => !cards[q.id])
  const weakFirst = shuffle(fresh).sort((a, b) => domainAvg(cert, cards, a.domain) - domainAvg(cert, cards, b.domain))
  return [...due, ...weakFirst].slice(0, size)
}

function domainAvg(cert, cards, domain) {
  const qs = cert.questions.filter((q) => q.domain === domain)
  return qs.reduce((s, q) => s + mastery(cards[q.id]), 0) / (qs.length || 1)
}

export function examScenarios(cert) {
  const per = cert.exam.items / cert.exam.scenariosPerExam
  return cert.scenarios.filter((s) => s.officialBank && cert.questions.filter((q) => q.scenario === s.id).length >= per)
}

export function buildMockExam(cert, rand = Math.random) {
  const per = Math.floor(cert.exam.items / cert.exam.scenariosPerExam)
  const picked = shuffle(examScenarios(cert), rand).slice(0, cert.exam.scenariosPerExam)
  return picked.flatMap((s) => {
    const pool = shuffle(cert.questions.filter((q) => q.scenario === s.id), rand)
    const required = Object.entries(cert.exam.minPerDomain || {}).flatMap(([d, n]) => pool.filter((q) => q.domain === d).slice(0, n))
    return shuffle([...required, ...pool.filter((q) => !required.includes(q)).slice(0, per - required.length)], rand)
  })
}
