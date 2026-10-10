import type { On } from 'claude-code'
import { test, expect } from 'claude-code/testing'

const TOOL = 'mcp__snake-tools__divine_inspiration'
const ALLOWED = /^[A-Za-z0-9_-]{64}$/

// The test's hooks stand for the engine, so an in-memory file keeps the repo's
// inspirations.json out of it.
// The engine hands fs hooks the path resolved against the working directory.
const name = (path: string) => path.split('/').pop()!

function memoryFs(on: On, files: Map<string, string>) {
  on('fs.exists', (_$, e) => ({ value: files.has(name(e.path)) }))
  on('fs.read', (_$, e) => {
    const text = files.get(name(e.path))

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })
  on('fs.write', (_$, e) => {
    files.set(name(e.path), e.text)

    return { value: undefined }
  })
}

test('a new topic gets 64 characters from the alphabet and is saved', async ($, on) => {
  const files = new Map<string, string>()
  memoryFs(on, files)

  const { result } = await $.tool.call({ tool: TOOL, topic: 'snake-game' })

  expect(String(result)).toMatch(ALLOWED)
  expect(JSON.parse(files.get('inspirations.json')!)).toEqual({ 'snake-game': result })
})

test('the same topic returns the same seed', async ($, on) => {
  memoryFs(on, new Map())

  const a = await $.tool.call({ tool: TOOL, topic: 'snake-game' })
  const b = await $.tool.call({ tool: TOOL, topic: 'snake-game' })

  expect(a.result).toEqual(b.result)
})

test('different topics get different seeds', async ($, on) => {
  memoryFs(on, new Map())

  const a = await $.tool.call({ tool: TOOL, topic: 'snake-game' })
  const b = await $.tool.call({ tool: TOOL, topic: 'snake-sounds' })

  expect(a.result).not.toEqual(b.result)
})

test('a stored seed is returned as is', async ($, on) => {
  const stored = 'A'.repeat(64)
  memoryFs(on, new Map([['inspirations.json', JSON.stringify({ 'snake-game': stored })]]))

  const { result } = await $.tool.call({ tool: TOOL, topic: 'snake-game' })

  expect(result).toEqual(stored)
})

test('an empty topic is refused', async ($, on) => {
  memoryFs(on, new Map())

  const { deny } = await $.tool.call({ tool: TOOL, topic: '  ' })

  expect(deny).toBeDefined()
})
