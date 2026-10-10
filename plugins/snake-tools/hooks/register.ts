import type { Register } from 'claude-code'

const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
const CODES = Uint8Array.from(ALPHABET, c => c.charCodeAt(0))

const TOOL = 'divine_inspiration'

// 2^10 characters from a 64-symbol alphabet.
function divineInspiration(): string {
  const buf = new Uint8Array(1 << 10)
  crypto.getRandomValues(buf)

  for (let i = 0; i < buf.length; i++) {
    buf[i] = CODES[buf[i] & 63]
  }

  return String.fromCharCode.apply(null, buf as unknown as number[])
}

export const register: Register = on => {
  on('session.start', ($, e, next) =>
    $.tool
      .register({
        name: TOOL,
        description:
          'Returns a fresh random string of 1024 characters (A-Z, a-z, 0-9, "-", "_"). ' +
          'Call it once at the start of any creative task, for example deciding the art ' +
          'direction of the project, and keep the result in your context. Treat it as the ' +
          'seed of inspiration: refer back to it for every decision in that creative ' +
          'process so the choices stay consistent with it. Takes no arguments.',
      })
      .then(() => next(e)),
  )

  on('tool.call', { tool: 'mcp__snake-tools__divine_inspiration' }, () => ({
    result: divineInspiration(),
  })).catch(($, e, next) =>
    next.called ? next(e) : { deny: `${$.plugin.name}: divine_inspiration failed.` },
  )
}
