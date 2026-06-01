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
    const { type, data, action } = body
    const isPayment = type === 'payment' || topic === 'payment' || action?.startsWith('payment')
    if (!isPayment) return NextResponse.json({ received: true })
    const paymentId = data?.id || qId
    if (!paymentId) return NextResponse.json({ received: true })
    const res = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    })
    const payment = await res.json()
    if (payment.status !== 'approved') return NextResponse.json({ received: true })
    const ref = payment.external_reference || ''
    const [userId, plan] = ref.split('|')
    if (!userId || !plan) return NextResponse.json({ received: true })
    await supabase.from('users_profiles').update({ plan }).eq('id', userId)
    await supabase.from('subscriptions').upsert({ user_id: userId, plan, mp_subscription_id: String(paymentId), status: 'active' }, { onConflict: 'user_id' })
    return NextResponse.json({ received: true })
  } catch (err) {
    console.error('Webhook error:', err)
    return NextResponse.json({ error: 'Webhook error' }, { status: 500 })
  }
}

export async function GET() {
  return NextResponse.json({ ok: true })
}
