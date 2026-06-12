import { NextRequest, NextResponse } from 'next/server'
import { resolveMx } from 'dns/promises'

const DISPOSABLE_DOMAINS = new Set([
  'mailinator.com', 'tempmail.com', 'temp-mail.org', 'guerrillamail.com',
  '10minutemail.com', 'throwaway.email', 'yopmail.com', 'trashmail.com',
  'fakeinbox.com', 'getnada.com',
])

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json()
    if (!email || typeof email !== 'string') {
      return NextResponse.json({ valid: false, reason: 'E-mail inválido.' }, { status: 400 })
    }

    const match = email.trim().toLowerCase().match(/^[^\s@]+@([^\s@]+\.[^\s@]+)$/)
    if (!match) {
      return NextResponse.json({ valid: false, reason: 'Formato de e-mail inválido.' })
    }

    const domain = match[1]
    if (DISPOSABLE_DOMAINS.has(domain)) {
      return NextResponse.json({ valid: false, reason: 'E-mails temporários não são permitidos.' })
    }

    try {
      const records = await resolveMx(domain)
      if (!records || records.length === 0) {
        return NextResponse.json({ valid: false, reason: 'Esse domínio de e-mail não existe.' })
      }
    } catch {
      return NextResponse.json({ valid: false, reason: 'Esse domínio de e-mail não existe.' })
    }

    return NextResponse.json({ valid: true })
  } catch (err) {
    console.error('validate-email error:', err)
    return NextResponse.json({ valid: true })
  }
}
