import type { Register } from 'claude-code'

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
const CODES = Uint8Array.from(ALPHABET, c => c.charCodeAt(0))

const TOOL = 'divine_inspiration'
const STORE = 'inspirations.json'

// 2^6 characters from a 64-symbol alphabet, 384 bits.
function divineInspiration(): string {
  const buf = new Uint8Array(1 << 6)
  crypto.getRandomValues(buf)

  for (let i = 0; i < buf.length; i++) {
    buf[i] = CODES[buf[i] & 63]
  }

  return String.fromCharCode.apply(null, buf as unknown as number[])
}

type Seeds = Record<string, string>

export const register: Register = on => {
  on('session.start', ($, e, next) =>
    $.tool
      .register({
        name: TOOL,
        description:
          'Returns the stored inspiration seed for a topic: a string of 64 characters ' +
          '(A-Z, a-z, 0-9, "-", "_"). Call it once at the start of any creative task, ' +
          'for example deciding the art direction of the project, with a short ' +
          'kebab-case topic like "snake-game", and keep the result in your context. ' +
          'A topic that has no seed yet gets a fresh random one, saved to ' +
          `${STORE} so every later call for that topic returns the same string. ` +
          'Treat it as the seed of inspiration: refer back to it for every decision ' +
          'in that creative process so the choices stay consistent with it.',
        inputSchema: {
          type: 'object',
          properties: {
            topic: {
              type: 'string',
              description: 'What the seed is for, e.g. "snake-game". Same topic, same seed.',
            },
          },
          required: ['topic'],
        },
      })
      .then(() => next(e)),
  )

  on('tool.call', { tool: 'mcp__snake-tools__divine_inspiration' }, async ($, e) => {
    const topic = typeof e.topic === 'string' ? e.topic.trim() : ''

    if (topic === '') {
      return { deny: `${$.plugin.name}: divine_inspiration needs a non-empty topic.` }
    }

    let seeds: Seeds = Object.create(null)

    if (await $.fs.exists(STORE)) {
      try {
        Object.assign(seeds, JSON.parse(await $.fs.read(STORE)))
      } catch {
        return { deny: `${$.plugin.name}: ${STORE} is not valid JSON, fix or remove it.` }
      }
    }

    if (Object.hasOwn(seeds, topic)) {
      return { result: seeds[topic] }
    }

    seeds[topic] = divineInspiration()
    await $.fs.write(STORE, JSON.stringify(seeds, null, 2) + '\n')

    return { result: seeds[topic] }
  }).catch(($, e, next) =>
    next.called ? next(e) : { deny: `${$.plugin.name}: divine_inspiration failed.` },
  )
}
