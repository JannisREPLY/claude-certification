export const DAY = 24 * 60 * 60 * 1000
export const MASTERED_BOX = 4
const INTERVAL_DAYS = [0, 1, 3, 7, 14, 30]

export function newCard() {
  return { box: 0, due: 0, seen: 0, correct: 0, wrong: 0, last: 0 }
}

export function review(card = newCard(), isCorrect, now = Date.now(), hinted = false) {
  const next = { ...card, seen: card.seen + 1, last: now }
  if (isCorrect) {
    next.correct = card.correct + 1
    if (hinted) return next
    if (now >= card.due) next.box = Math.min(card.box + 1, INTERVAL_DAYS.length - 1)
    next.due = now + INTERVAL_DAYS[next.box] * DAY
  } else {
    next.wrong = card.wrong + 1
    next.box = 0
    next.due = now
  }
  return next
}

export function mastery(card) {
  return card ? Math.min(card.box / MASTERED_BOX, 1) : 0
}

export function isDue(card, now = Date.now()) {
  return !!card && card.seen > 0 && now >= card.due
}
