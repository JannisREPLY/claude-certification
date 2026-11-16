import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import confetti from 'canvas-confetti'
import { applyAnswer, applyExam, applyLab, applyLesson, emptyProgress, levelFor, newBadges } from './game.js'

const Ctx = createContext(null)
const key = (certId) => `cert-trainer:${certId}`

export function load(certId) {
  try {
    return { ...emptyProgress(), ...JSON.parse(localStorage.getItem(key(certId))) }
  } catch {
    return emptyProgress()
  }
}

export function ProgressProvider({ cert, children }) {
  const [progress, setProgress] = useState(() => load(cert.id))
  const [toasts, setToasts] = useState([])
  const ref = useRef(progress)

  useEffect(() => {
    ref.current = load(cert.id)
    setProgress(ref.current)
  }, [cert.id])

  const toast = useCallback((t) => {
    const id = Math.random()
    setToasts((ts) => [...ts, { ...t, id }])
    setTimeout(() => setToasts((ts) => ts.filter((x) => x.id !== id)), 3500)
  }, [])

  const commit = useCallback(({ progress: next, gained }) => {
    const before = ref.current
    const badges = newBadges(cert, before, next)
    badges.forEach((b) => (next.badges[b.id] = b.ts))
    const levelUp = levelFor(next.xp).level > levelFor(before.xp).level
    ref.current = next
    setProgress(next)
    localStorage.setItem(key(cert.id), JSON.stringify(next))
    badges.forEach((b) => toast({ icon: b.icon, text: `Badge unlocked: ${b.name}` }))
    if (levelUp) toast({ icon: '⬆️', text: `Level ${levelFor(next.xp).level}: ${levelFor(next.xp, cert.levelTitles).title}` })
    if (badges.length || levelUp) confetti({ particleCount: 140, spread: 80, origin: { y: 0.7 } })
    return gained
  }, [cert, toast])

  const api = {
    progress,
    toasts,
    toast,
    answer: (qid, correct, combo, hinted = false) => commit(applyAnswer(ref.current, qid, correct, combo, Date.now(), hinted)),
    readLesson: (id) => commit(applyLesson(ref.current, id)),
    finishExam: (result) => commit(applyExam(ref.current, result)),
    finishLab: (labId, results) => commit(applyLab(ref.current, labId, results)),
    replace: (next) => commit({ progress: { ...emptyProgress(), ...next }, gained: 0 }),
  }
  return <Ctx.Provider value={api}>{children}</Ctx.Provider>
}

export const useProgress = () => useContext(Ctx)
