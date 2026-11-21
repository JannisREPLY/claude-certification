import { review } from './srs.js'
import { domainMastery } from './readiness.js'
import { labPassed } from './labs.js'

export const DAILY_GOAL = 15
export const XP = { correct: 10, wrong: 2, comboMax: 10, lesson: 25, exam: 100, examPass: 200, dailyGoal: 50, labTask: 20, lab: 150 }

export function levelFor(xp, titles = ['']) {
  let level = 1
  while (xp >= xpForLevel(level + 1)) level++
  const base = xpForLevel(level)
  const next = xpForLevel(level + 1)
  return { level, title: titles[Math.min(Math.floor((level - 1) / 3), titles.length - 1)], into: xp - base, span: next - base }
}

export function xpForLevel(level) {
  return 50 * (level - 1) * level
}

export function dayKey(now = Date.now()) {
  const d = new Date(now)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function previousDay(key) {
  const [y, m, d] = key.split('-').map(Number)
  return dayKey(new Date(y, m - 1, d - 1).getTime())
}

export function emptyProgress() {
  return { cards: {}, lessonsRead: {}, xp: 0, streak: { count: 0, lastDay: null }, daily: { day: null, answered: 0 }, bestCombo: 0, answeredTotal: 0, correctTotal: 0, badges: {}, exams: [], labs: {} }
}

export function currentStreak(progress, now = Date.now()) {
  const today = dayKey(now)
  const { count, lastDay } = progress.streak
  return lastDay === today || lastDay === previousDay(today) ? count : 0
}

function touchDay(p, now) {
  const today = dayKey(now)
  if (p.daily.day !== today) p.daily = { day: today, answered: 0 }
  if (p.streak.lastDay !== today) {
    p.streak = { count: p.streak.lastDay === previousDay(today) ? p.streak.count + 1 : 1, lastDay: today }
  }
}

export function applyAnswer(progress, qid, correct, combo, now = Date.now(), hinted = false) {
  const p = structuredClone(progress)
  touchDay(p, now)
  p.cards[qid] = review(p.cards[qid], correct, now, hinted)
  p.answeredTotal += 1
  p.daily.answered += 1
  let gained = correct ? XP.correct + Math.min(combo, XP.comboMax) : XP.wrong
  if (hinted) gained = Math.ceil(gained / 2)
  if (correct) p.correctTotal += 1
  if (p.daily.answered === DAILY_GOAL) gained += XP.dailyGoal
  p.bestCombo = Math.max(p.bestCombo, combo)
  p.xp += gained
  return { progress: p, gained }
}

export function applyLesson(progress, lessonId, now = Date.now()) {
  if (progress.lessonsRead[lessonId]) return { progress, gained: 0 }
  const p = structuredClone(progress)
  touchDay(p, now)
  p.lessonsRead[lessonId] = now
  p.xp += XP.lesson
  return { progress: p, gained: XP.lesson }
}

export function applyExam(progress, result, now = Date.now()) {
  const p = structuredClone(progress)
  p.exams.push({ ...result, ts: now })
  const gained = XP.exam + (result.passed ? XP.examPass : 0)
  p.xp += gained
  return { progress: p, gained }
}

export function applyLab(progress, key, results, now = Date.now()) {
  const p = structuredClone(progress)
  touchDay(p, now)
  const lab = (p.labs[key] ||= { tasks: {}, completed: null })
  let gained = 0
  results.filter((r) => r.ok && !lab.tasks[r.id]).forEach((r) => {
    lab.tasks[r.id] = now
    gained += XP.labTask
  })
  if (!lab.completed && results.every((r) => r.ok)) {
    lab.completed = now
    gained += XP.lab
  }
  p.xp += gained
  return { progress: p, gained }
}

export function badgeDefs(cert) {
  const domainBadges = cert.domains.map((d) => ({
    id: `master-${d.id}`, icon: '🏅', name: `${d.short || d.name.split(' ')[0]} Master`, desc: `Master 80% of “${d.name}”`,
    test: (p) => domainMastery(cert, p).find((x) => x.id === d.id).value >= 0.8,
  }))
  return [
    { id: 'first', icon: '🐣', name: 'First Steps', desc: 'Answer your first question', test: (p) => p.answeredTotal >= 1 },
    { id: 'combo5', icon: '🔥', name: 'Hot Hand', desc: '5 correct answers in a row', test: (p) => p.bestCombo >= 5 },
    { id: 'combo15', icon: '⚡', name: 'Unstoppable', desc: '15 correct answers in a row', test: (p) => p.bestCombo >= 15 },
    { id: 'century', icon: '💯', name: 'Century', desc: 'Answer 100 questions', test: (p) => p.answeredTotal >= 100 },
    { id: 'marathon', icon: '🏃', name: 'Marathon', desc: 'Answer 500 questions', test: (p) => p.answeredTotal >= 500 },
    { id: 'bookworm', icon: '📖', name: 'Bookworm', desc: 'Study 5 lessons', test: (p) => Object.keys(p.lessonsRead).length >= 5 },
    { id: 'scholar', icon: '🎓', name: 'Scholar', desc: 'Study every lesson', test: (p) => cert.lessons.every((l) => p.lessonsRead[l.id]) },
    { id: 'streak3', icon: '📅', name: 'Habit Forming', desc: '3-day learning streak', test: (p) => p.streak.count >= 3 },
    { id: 'streak7', icon: '🗓️', name: 'Week Warrior', desc: '7-day learning streak', test: (p) => p.streak.count >= 7 },
    { id: 'exam1', icon: '📝', name: 'Exam Rookie', desc: 'Finish a mock exam', test: (p) => p.exams.length >= 1 },
    { id: 'pass', icon: '🏆', name: 'Pass Mark', desc: 'Pass a mock exam', test: (p) => p.exams.some((e) => e.passed) },
    { id: 'ace', icon: '💎', name: 'Ace', desc: 'Score 900+ in a mock exam', test: (p) => p.exams.some((e) => e.score >= 900) },
    ...(cert.labs.length ? [
      { id: 'lab1', icon: '🧪', name: 'Hands On', desc: 'Pass your first lab', test: (p) => Object.values(p.labs).some((l) => l.completed) },
      { id: 'labexam', icon: '🎯', name: 'Exam Ready Hands', desc: 'Pass a lab at exam level', test: (p) => cert.labs.some((l) => labPassed(p, l.id)) },
      { id: 'labexpert', icon: '🔥', name: 'Expert', desc: 'Pass a lab at expert level', test: (p) => cert.labs.some((l) => labPassed(p, l.id, 'expert')) },
      { id: 'laball', icon: '🛠️', name: 'Lab Master', desc: 'Pass every lab at exam level', test: (p) => cert.labs.every((l) => labPassed(p, l.id)) },
    ] : []),
    ...domainBadges,
  ]
}

export function newBadges(cert, before, after, now = Date.now()) {
  return badgeDefs(cert).filter((b) => !before.badges[b.id] && b.test(after)).map((b) => ({ ...b, ts: now }))
}
