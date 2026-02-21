export namespace Token {
  const CHARS_PER_TOKEN = 4

  export function estimate(input: string) {
    return Math.max(0, Math.round((input || "").length / CHARS_PER_TOKEN))
  }

  export function cachePercent(tokens: { input: number; cache: { read: number; write: number } }) {
    const total = tokens.input + tokens.cache.read + tokens.cache.write
    if (tokens.cache.read > 0 && total > 0) return Math.round((tokens.cache.read / total) * 100)
    return null
  }
}
