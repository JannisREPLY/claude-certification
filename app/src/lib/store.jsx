import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react'
import confetti from 'canvas-confetti'
import { applyAnswer, applyExam, applyLab, applyLesson, emptyProgress, levelFor, newBadges } from './game.js'
import { pull, push, resolve } from './sync.js'
import { supabase, useSession } from './supabase.js'

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
  const [syncError, setSyncError] = useState(null)
  const ref = useRef(progress)
  const session = useSession()
  const pending = useRef(null)
  const signedIn = useRef(false)
  signedIn.current = !!session

  useEffect(() => {
    ref.current = load(cert.id)
    setProgress(ref.current)
  }, [cert.id])

  const flush = useCallback(() => {
    clearTimeout(pending.current)
    pending.current = null
    if (!signedIn.current) return
    push(supabase, cert.id, ref.current).then(() => setSyncError(null), (e) => setSyncError(e.message))
  }, [cert.id])

  useEffect(() => {
    if (!session) return
    let alive = true
    const sync = async () => {
      try {
        const remote = await pull(supabase, cert.id)
        if (!alive) return
        const r = resolve(ref.current, remote)
        if (r.use === 'remote') {
          ref.current = { ...emptyProgress(), ...remote }
          setProgress(ref.current)
          localStorage.setItem(key(cert.id), JSON.stringify(ref.current))
        }
        if (r.push) await push(supabase, cert.id, ref.current)
        setSyncError(null)
      } catch (e) {
        setSyncError(e.message)
      }
    }
    const onVisibility = () => {
      if (document.visibilityState === 'visible') sync()
      else if (pending.current) flush()
    }
    sync()
    document.addEventListener('visibilitychange', onVisibility)
    return () => {
      alive = false
      document.removeEventListener('visibilitychange', onVisibility)
    }
  }, [session?.user.id, cert.id, flush])

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
    next.updatedAt = Date.now()
    ref.current = next
    setProgress(next)
    localStorage.setItem(key(cert.id), JSON.stringify(next))
    if (signedIn.current) {
      clearTimeout(pending.current)
      pending.current = setTimeout(flush, 1000)
    }
    badges.forEach((b) => toast({ icon: b.icon, text: `Badge unlocked: ${b.name}` }))
    if (levelUp) toast({ icon: '⬆️', text: `Level ${levelFor(next.xp).level}: ${levelFor(next.xp, cert.levelTitles).title}` })
    if (badges.length || levelUp) confetti({ particleCount: 140, spread: 80, origin: { y: 0.7 } })
    return gained
  }, [cert, toast, flush])

  const api = {
    progress,
    toasts,
    session,
    syncError,
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
