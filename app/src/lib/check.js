import { mastery } from './srs.js'
import { shuffle } from './quiz.js'

export const CHECK_SIZE = 5

export function checkPool(cert, lesson) {
  if (lesson.kind === 'domain-notes') return cert.questions.filter((q) => q.domain === lesson.domain)
  return cert.questions.filter((q) => q.hint?.lesson === lesson.id)
}

export function buildCheck(cert, lesson, cards, rand = Math.random) {
  const weight = (q) => (cards[q.id] ? mastery(cards[q.id]) : -1)
  return shuffle(checkPool(cert, lesson), rand)
    .sort((a, b) => weight(a) - weight(b))
    .slice(0, CHECK_SIZE)
}

export function nextQueue(queue, correct) {
  const [head, ...rest] = queue
  return correct ? rest : [...rest, head]
}
