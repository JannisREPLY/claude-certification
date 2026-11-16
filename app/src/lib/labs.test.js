import { describe, expect, it } from 'vitest'
import { applyLab, emptyProgress, levelFor, XP } from './game.js'
import { domainMastery, readiness } from './readiness.js'

const lab = { id: 'l1', domain: 'd1', tasks: [{ id: 't1' }, { id: 't2' }] }
const cert = (labs) => ({
  domains: [{ id: 'd1', name: 'One', weight: 1 }],
  questions: [{ id: 'q1', domain: 'd1' }],
  lessons: [],
  labs,
  exam: { passScore: 70, minScore: 0, maxScore: 100 },
})

describe('applyLab', () => {
  it('awards XP once per newly passed task and once for completing the lab', () => {
    const half = applyLab(emptyProgress(), 'l1', [{ id: 't1', ok: true }, { id: 't2', ok: false }])
    expect(half.gained).toBe(XP.labTask)
    expect(half.progress.labs.l1.completed).toBeNull()

    const full = applyLab(half.progress, 'l1', [{ id: 't1', ok: true }, { id: 't2', ok: true }])
    expect(full.gained).toBe(XP.labTask + XP.lab)
    expect(full.progress.labs.l1.completed).not.toBeNull()

    expect(applyLab(full.progress, 'l1', [{ id: 't1', ok: true }, { id: 't2', ok: true }]).gained).toBe(0)
  })
})

describe('domainMastery', () => {
  it('counts passed lab tasks in their domain', () => {
    const p = { ...emptyProgress(), labs: { l1: { tasks: { t1: 1 }, completed: null } } }
    const [d] = domainMastery(cert([lab]), p)
    expect(d.labTasks).toBe(2)
    expect(d.value).toBeCloseTo(1 / 3)
  })
})

describe('readiness', () => {
  it('adds the labs check only for certifications with labs', () => {
    expect(readiness(cert([]), emptyProgress()).checks.map((c) => c.id)).not.toContain('labs')
    const p = { ...emptyProgress(), labs: { l1: { tasks: { t1: 1, t2: 1 }, completed: 1 } } }
    expect(readiness(cert([lab]), p).checks.find((c) => c.id === 'labs').ok).toBe(true)
  })
})

describe('levelFor', () => {
  it('uses the certification level titles', () => {
    expect(levelFor(0, ['A', 'B']).title).toBe('A')
    expect(levelFor(100000, ['A', 'B']).title).toBe('B')
  })
})
