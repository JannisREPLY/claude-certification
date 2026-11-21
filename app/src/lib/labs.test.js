import { describe, expect, it } from 'vitest'
import { readdirSync, readFileSync, existsSync } from 'node:fs'
import { applyLab, emptyProgress, levelFor, XP } from './game.js'
import { domainMastery, readiness } from './readiness.js'
import { gradeFullExam, labKey } from './labs.js'
import { buildMockExam } from './quiz.js'

const lab = { id: 'l1', domain: 'd1', levels: { guided: { tasks: [{ id: 't1' }] }, exam: { tasks: [{ id: 't1' }, { id: 't2' }] } } }
const cert = (labs, mockLabs = []) => ({
  domains: [{ id: 'd1', name: 'One', weight: 1 }],
  questions: [{ id: 'q1', domain: 'd1' }],
  lessons: [],
  labs,
  mockLabs,
  exam: { passScore: 70, minScore: 0, maxScore: 100 },
})

describe('applyLab', () => {
  it('awards XP once per newly passed task and once for completing the lab level', () => {
    const key = labKey('l1', 'exam')
    const half = applyLab(emptyProgress(), key, [{ id: 't1', ok: true }, { id: 't2', ok: false }])
    expect(half.gained).toBe(XP.labTask)
    expect(half.progress.labs[key].completed).toBeNull()

    const full = applyLab(half.progress, key, [{ id: 't1', ok: true }, { id: 't2', ok: true }])
    expect(full.gained).toBe(XP.labTask + XP.lab)
    expect(full.progress.labs[key].completed).not.toBeNull()

    expect(applyLab(full.progress, key, [{ id: 't1', ok: true }, { id: 't2', ok: true }]).gained).toBe(0)
  })
})

describe('domainMastery', () => {
  it('counts only exam-level lab tasks in their domain', () => {
    const p = { ...emptyProgress(), labs: { 'l1:exam': { tasks: { t1: 1 }, completed: null }, 'l1:guided': { tasks: { t1: 1 }, completed: 1 } } }
    const [d] = domainMastery(cert([lab]), p)
    expect(d.labTasks).toBe(2)
    expect(d.value).toBeCloseTo(1 / 3)
  })
})

describe('readiness', () => {
  it('adds the labs check only for certifications with labs', () => {
    expect(readiness(cert([]), emptyProgress()).checks.map((c) => c.id)).not.toContain('labs')
  })

  it('passes the labs check only at exam level and ignores mock labs', () => {
    const mock = { id: 'm1', mock: true, levels: { exam: { tasks: [{ id: 't1' }] } } }
    const guidedOnly = { ...emptyProgress(), labs: { 'l1:guided': { tasks: { t1: 1 }, completed: 1 } } }
    expect(readiness(cert([lab], [mock]), guidedOnly).checks.find((c) => c.id === 'labs').ok).toBe(false)
    const examDone = { ...emptyProgress(), labs: { 'l1:exam': { tasks: { t1: 1, t2: 1 }, completed: 1 } } }
    expect(readiness(cert([lab], [mock]), examDone).checks.find((c) => c.id === 'labs').ok).toBe(true)
  })

  it('needs a passed full mock exam when the certification has mock labs', () => {
    const mock = { id: 'm1', mock: true, levels: { exam: { tasks: [{ id: 't1' }] } } }
    const p = { ...emptyProgress(), exams: [{ mode: 'full', passed: true }, { mode: 'questions', passed: false }] }
    expect(readiness(cert([], [mock]), p).checks.find((c) => c.id === 'mock').ok).toBe(true)
    expect(readiness(cert([]), p).checks.find((c) => c.id === 'mock').ok).toBe(false)
  })
})

describe('gradeFullExam', () => {
  const tasks = (n) => ({ levels: { exam: { tasks: Array.from({ length: n }, (_, i) => ({ id: `t${i + 1}` })) } } })
  const mockLabs = ['a', 'b', 'c', 'd'].map((id) => ({ id, title: id, ...tasks(4) }))
  const results = (n) => Array.from({ length: 4 }, (_, i) => ({ id: `t${i + 1}`, ok: i < n }))
  const c = { ...cert([], mockLabs) }

  it('averages the 4 labs and the question block equally', () => {
    const g = gradeFullExam(c, { correct: 12, total: 12 }, { a: results(4), b: results(4), c: results(2), d: results(0) })
    expect(g.parts).toHaveLength(5)
    expect(g.score).toBe(Math.round(((1 + 1 + 1 + 0.5 + 0) / 5) * 100))
  })

  it('passes at exactly 70% and fails just below', () => {
    const at = gradeFullExam(c, { correct: 6, total: 12 }, { a: results(4), b: results(4), c: results(2), d: results(4) })
    expect(at.score).toBe(80)
    const seventy = gradeFullExam(c, { correct: 12, total: 12 }, { a: results(4), b: results(2), c: results(2), d: results(2) })
    expect(seventy.score).toBe(70)
    expect(seventy.passed).toBe(true)
    const below = gradeFullExam(c, { correct: 11, total: 12 }, { a: results(4), b: results(2), c: results(2), d: results(2) })
    expect(below.score).toBe(68)
    expect(below.passed).toBe(false)
  })

  it('counts a lab without results as 0', () => {
    expect(gradeFullExam(c, { correct: 12, total: 12 }, {}).score).toBe(20)
  })
})

describe('mock exam questions', () => {
  const content = JSON.parse(readFileSync(new URL('../certs/terraform-authoring-ops-advanced/content.json', import.meta.url)))
  it('has 12 distinct questions with at least 4 from domain 6', () => {
    for (let seed = 1; seed <= 50; seed++) {
      let s = seed
      const rand = () => ((s = (s * 16807) % 2147483647) / 2147483647)
      const qs = buildMockExam(content, rand)
      expect(qs).toHaveLength(12)
      expect(new Set(qs.map((q) => q.id)).size).toBe(12)
      expect(qs.filter((q) => q.domain === 'd6').length).toBeGreaterThanOrEqual(4)
    }
  })
})

describe('lab definitions', () => {
  const dir = new URL('../../lab/labs/', import.meta.url)
  const labs = readdirSync(dir).filter((d) => existsSync(new URL(`${d}/lab.json`, dir))).map((d) => JSON.parse(readFileSync(new URL(`${d}/lab.json`, dir))))

  it('gives every task of every level a text, a validation and a check script', () => {
    for (const l of labs) {
      expect(l.levels.exam, l.id).toBeTruthy()
      for (const [level, def] of Object.entries(l.levels)) {
        expect(def.tasks.length, `${l.id}:${level}`).toBeGreaterThanOrEqual(3)
        for (const t of def.tasks) {
          expect(t.text && t.validation, `${l.id}:${level}:${t.id}`).toBeTruthy()
          expect(existsSync(new URL(`${l.id}/${level}/checks/${t.id}.sh`, dir)), `${l.id}:${level}:${t.id} check`).toBe(true)
        }
      }
    }
  })

  it('has three levels for practice labs and only the exam level for mock labs', () => {
    for (const l of labs) expect(Object.keys(l.levels).sort(), l.id).toEqual(l.mock ? ['exam'] : ['exam', 'expert', 'guided'])
  })
})

describe('levelFor', () => {
  it('uses the certification level titles', () => {
    expect(levelFor(0, ['A', 'B']).title).toBe('A')
    expect(levelFor(100000, ['A', 'B']).title).toBe('B')
  })
})
