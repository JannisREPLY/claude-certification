import { describe, expect, it } from 'vitest'
import { readdirSync, readFileSync } from 'node:fs'
import { buildCheck, CHECK_SIZE, checkPool, nextQueue } from './check.js'

const q = (id, extra) => ({ id, domain: 'd1', hint: { lesson: 'ch1', heading: null }, ...extra })
const cert = {
  questions: [
    ...Array.from({ length: 8 }, (_, i) => q(`a${i}`)),
    q('b1', { hint: { lesson: 'ch2', heading: null } }),
    q('b2', { hint: { lesson: 'ch2', heading: null } }),
    q('c1', { domain: 'd2', hint: { lesson: 'ch3', heading: null } }),
  ],
}
const ch1 = { id: 'ch1', kind: 'theory', domain: 'd1' }

describe('buildCheck', () => {
  it('picks at most 5 questions of the lesson, unseen and weak cards first', () => {
    const cards = { a0: { box: 4 }, a1: { box: 4 }, a2: { box: 4 }, a3: { box: 1 }, a4: { box: 0 }, a5: { box: 3 } }
    const ids = buildCheck(cert, ch1, cards).map((x) => x.id)
    expect(ids).toHaveLength(CHECK_SIZE)
    expect(ids.slice(0, 2).sort()).toEqual(['a6', 'a7'])
    expect(ids.slice(2)).toEqual(['a4', 'a3', 'a5'])
  })

  it('uses every question of the domain for domain notes', () => {
    const notes = { id: 'notes-d2', kind: 'domain-notes', domain: 'd2' }
    expect(checkPool(cert, notes).map((x) => x.id)).toEqual(['c1'])
  })

  it('has no questions for a lesson without linked questions', () => {
    expect(buildCheck(cert, { id: 'overview', kind: 'overview', domain: null }, {})).toEqual([])
  })

  it('uses all questions when the lesson has fewer than 5', () => {
    expect(buildCheck(cert, { id: 'ch2', kind: 'theory', domain: 'd1' }, {}).map((x) => x.id).sort()).toEqual(['b1', 'b2'])
  })
})

describe('nextQueue', () => {
  it('requeues wrong answers and is empty only when all were answered correctly', () => {
    let queue = ['x', 'y']
    queue = nextQueue(queue, false)
    expect(queue).toEqual(['y', 'x'])
    queue = nextQueue(queue, true)
    expect(queue).toEqual(['x'])
    queue = nextQueue(queue, false)
    expect(queue).toEqual(['x'])
    expect(nextQueue(queue, true)).toEqual([])
  })
})

const UNGATED = ['exam-overview', 'out-of-scope-topics', 'preparation-recommendations']
const certDir = new URL('../certs/', import.meta.url)
const contents = readdirSync(certDir, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => JSON.parse(readFileSync(new URL(`${d.name}/content.json`, certDir), 'utf8')))

describe.each(contents.map((c) => [c.id, c]))('content %s', (_, c) => {
  it('gives every lesson except the ungated ones at least 2 check questions', () => {
    for (const lesson of c.lessons) {
      const n = checkPool(c, lesson).length
      if (UNGATED.includes(lesson.id)) expect(n, lesson.id).toBe(0)
      else expect(n, lesson.id).toBeGreaterThanOrEqual(2)
    }
  })

  it('links every question to an existing lesson and heading', () => {
    for (const x of c.questions) {
      const lesson = c.lessons.find((l) => l.id === x.hint.lesson)
      expect(lesson, x.id).toBeDefined()
      const headings = lesson.markdown.split('\n').filter((l) => /^#{2,3} /.test(l)).map((l) => l.replace(/^#+ /, ''))
      if (x.hint.heading) expect(headings, x.id).toContain(x.hint.heading)
    }
  })

  it('gives every lesson-check question exactly one correct option', () => {
    for (const x of c.questions.filter((y) => /^(pe|ap|tf-ov)\d+$/.test(y.id))) {
      expect(x.options.filter((o) => o.correct).length, x.id).toBe(1)
    }
  })
})
