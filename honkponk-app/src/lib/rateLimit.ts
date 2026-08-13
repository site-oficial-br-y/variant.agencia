import { NextRequest } from 'next/server'

// Rate limit simples em memória, por IP. Reseta em cold start e não é
// compartilhado entre instâncias — não é perfeito, mas barra qualquer
// script simples martelando uma rota. Serve como camada extra de defesa,
// não como proteção definitiva (isso depende de configuração na Vercel/Supabase).
const hits = new Map<string, number[]>()

export function getClientIp(req: NextRequest): string {
  return req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || req.headers.get('x-real-ip')
    || 'unknown'
}

export function isRateLimited(key: string, windowMs: number, max: number): boolean {
  const now = Date.now()
  const recent = (hits.get(key) || []).filter(t => now - t < windowMs)
  recent.push(now)
  hits.set(key, recent)
  if (hits.size > 5000) {
    const cutoff = now - windowMs
    hits.forEach((times, k) => {
      if (!times.some(t => t > cutoff)) hits.delete(k)
    })
  }
  return recent.length > max
}
