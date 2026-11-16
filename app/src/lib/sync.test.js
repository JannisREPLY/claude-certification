import { describe, expect, it } from 'vitest'
import { pull, push, resolve } from './sync.js'

describe('resolve', () => {
  it('takes remote when remote is newer', () => {
    expect(resolve({ xp: 1, updatedAt: 1 }, { xp: 2, updatedAt: 2 })).toEqual({ use: 'remote', push: false })
  })
  it('keeps local and pushes when local is newer', () => {
    expect(resolve({ xp: 2, updatedAt: 2 }, { xp: 1, updatedAt: 1 })).toEqual({ use: 'local', push: true })
  })
  it('takes remote on an empty device', () => {
    expect(resolve({ xp: 0 }, { xp: 5, updatedAt: 1 })).toEqual({ use: 'remote', push: false })
  })
  it('pushes local when remote is empty', () => {
    expect(resolve({ xp: 5, updatedAt: 3 }, null)).toEqual({ use: 'local', push: true })
  })
  it('does not push an untouched device to an empty remote', () => {
    expect(resolve({ xp: 0 }, null)).toEqual({ use: 'local', push: false })
  })
  it('pushes old progress without timestamp to an empty remote', () => {
    expect(resolve({ xp: 5 }, null)).toEqual({ use: 'local', push: true })
  })
  it('takes remote with timestamp over old progress without timestamp', () => {
    expect(resolve({ xp: 5 }, { xp: 1, updatedAt: 2 })).toEqual({ use: 'remote', push: false })
  })
  it('keeps and pushes old progress over an untouched remote', () => {
    expect(resolve({ xp: 5 }, { xp: 0 })).toEqual({ use: 'local', push: true })
  })
})

describe('without config', () => {
  it('does nothing and does not throw', async () => {
    await expect(pull(null, 'c')).resolves.toBeNull()
    await expect(push(null, 'c', { xp: 1 })).resolves.toBeUndefined()
  })
})
