import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { getClientIp, isRateLimited } from '@/lib/rateLimit'

export async function POST(request: NextRequest) {
  const ip = getClientIp(request)
  if (isRateLimited(`reset:${ip}`, 60 * 1000, 3)) {
    return NextResponse.json({ error: 'Muitas tentativas. Aguarde um pouco e tente de novo.' }, { status: 429 })
  }

  const { email, origin } = await request.json()
  if (!email || typeof email !== 'string') {
    return NextResponse.json({ error: 'E-mail inválido.' }, { status: 400 })
  }

  const supabase = createClient()
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${origin}/auth/callback`,
  })

  // Sempre responde "ok" pro cliente, mesmo se o e-mail não existir — evita que
  // alguém use esse formulário pra descobrir quais e-mails têm conta no Honk Ponk.
  if (error) console.error('reset-password error:', error)
  return NextResponse.json({ ok: true })
}
