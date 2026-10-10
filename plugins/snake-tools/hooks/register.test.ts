import { test, expect } from 'claude-code/testing'

const TOOL = 'mcp__snake-tools__divine_inspiration'
const ALLOWED = /^[A-Za-z0-9_-]{1024}$/

test('divine_inspiration returns 1024 characters from the alphabet', async $ => {
  const { result } = await $.tool.call({ tool: TOOL, input: {} })

  expect(String(result)).toMatch(ALLOWED)
})

test('two calls differ', async $ => {
  const a = await $.tool.call({ tool: TOOL, input: {} })
  const b = await $.tool.call({ tool: TOOL, input: {} })

  expect(a.result).not.toEqual(b.result)
})
