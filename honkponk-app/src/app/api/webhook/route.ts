import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const MP_ACCESS_TOKEN = process.env.MP_ACCESS_TOKEN!
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const url = new URL(request.url)
    const topic = url.searchParams.get('topic')
    const qId = url.searchParams.get('id')
    const { type: bodyType, data, action } = body
    const isPayment = bodyType === 'payment' || topic === 'payment' || action?.startsWith('payment')
    if (!isPayment) return NextResponse.json({ received: true })
    const paymentId = data?.id || qId
    if (!paymentId) return NextResponse.json({ received: true })
    const res = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    })
    const payment = await res.json()
    if (payment.status !== 'approved') return NextResponse.json({ received: true })
    const ref = payment.external_reference || ''
    const parts = ref.split('|')
    const userId = parts[0]
    const type = parts[1]
    if (!userId || !type) return NextResponse.json({ received: true })

    if (type === 'coins') {
      const coins = parseInt(parts[2] || '0', 10)
      if (coins > 0) {
        const { data: profile } = await supabase.from('users_profiles').select('honk_coins, email').eq('id', userId).single()
        const p = profile as { honk_coins?: number; email?: string } | null
        const amountCents = typeof payment.transaction_amount === 'number' ? Math.round(payment.transaction_amount * 100) : null

        // O Mercado Pago reenvia a mesma notificação. Antes o saldo era somado
        // primeiro, então cada reenvio dava coin de novo: quem comprou 10 recebeu 20.
        // Agora a compra é registrada antes, e o índice único em mp_payment_id
        // recusa a repetida — é ela que decide se o crédito acontece.
        const { error: registro } = await supabase.from('coin_purchases').insert({
          user_id: userId,
          email: p?.email || payment.payer?.email || null,
          coins,
          amount_cents: amountCents,
          mp_payment_id: String(paymentId),
        })
        // 23505 = violação de unicidade: esse pagamento já foi creditado.
        if (registro?.code === '23505') return NextResponse.json({ received: true, duplicate: true })
        // Qualquer outra falha credita assim mesmo: é melhor perder o histórico
        // do que alguém pagar e ficar sem coin.
        if (registro) console.error('coin_purchases insert falhou, creditando mesmo assim:', registro)

        const current = p?.honk_coins || 0
        await supabase.from('users_profiles').update({ honk_coins: current + coins }).eq('id', userId)
      }
    } else {
      const plan = type
      const months = parseInt(parts[2] || '1', 10) || 1

      // Como agora o prazo é somado, a notificação repetida do Mercado Pago daria
      // um mês de graça. A assinatura guarda o id do último pagamento: se for o
      // mesmo, já processamos.
      const { data: assinatura } = await supabase
        .from('subscriptions').select('mp_subscription_id').eq('user_id', userId).maybeSingle()
      const ultimoPagamento = (assinatura as { mp_subscription_id?: string | null } | null)?.mp_subscription_id
      if (ultimoPagamento && ultimoPagamento === String(paymentId)) {
        return NextResponse.json({ received: true, duplicate: true })
      }

      // Renova somando ao vencimento que ainda está de pé. Antes contava sempre a
      // partir de hoje, então quem renovava adiantado perdia os dias que sobravam.
      const { data: perfil } = await supabase
        .from('users_profiles').select('plan_expires_at').eq('id', userId).single()
      const vencimento = (perfil as { plan_expires_at?: string | null } | null)?.plan_expires_at
      const expiresAt =
        vencimento && new Date(vencimento).getTime() > Date.now() ? new Date(vencimento) : new Date()
      expiresAt.setMonth(expiresAt.getMonth() + months)

      await supabase.from('users_profiles').update({ plan, plan_expires_at: expiresAt.toISOString() }).eq('id', userId)
      await supabase.from('subscriptions').upsert({ user_id: userId, plan, mp_subscription_id: String(paymentId), status: 'active' }, { onConflict: 'user_id' })
    }
    return NextResponse.json({ received: true })
  } catch (err) {
    console.error('Webhook error:', err)
    return NextResponse.json({ error: 'Webhook error' }, { status: 500 })
  }
}

export async function GET() {
  return NextResponse.json({ ok: true })
}
