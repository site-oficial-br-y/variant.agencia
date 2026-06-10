import { NextRequest, NextResponse } from 'next/server'
import { PLANS } from '@/lib/plans'
import type { Plan } from '@/lib/plans'

const MP_ACCESS_TOKEN = process.env.MP_ACCESS_TOKEN!
const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://honkponk.com.br'

export async function POST(request: NextRequest) {
  try {
    const { plan, userId, email } = await request.json()

    if (!plan || !userId || !PLANS[plan as Plan] || plan === 'free') {
      return NextResponse.json({ error: 'Plano inválido.' }, { status: 400 })
    }

    const planConfig = PLANS[plan as Plan]
    const unitPrice = planConfig.price / 100

    const preferenceBody = {
      items: [{ id: plan, title: `Honk Ponk — Plano ${planConfig.name}`, description: planConfig.description, quantity: 1, unit_price: unitPrice, currency_id: 'BRL' }],
      payer: { email },
      back_urls: {
        success: `${APP_URL}/checkout/success?plan=${plan}&user=${userId}`,
        failure: `${APP_URL}/checkout/failure`,
        pending: `${APP_URL}/checkout/pending`,
      },
      auto_return: 'approved',
      external_reference: `${userId}|${plan}`,
      notification_url: `${APP_URL}/api/webhook`,
      statement_descriptor: 'HONK PONK',
      metadata: { user_id: userId, plan },
    }

    const res = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
      body: JSON.stringify(preferenceBody),
    })

    const data = await res.json()
    if (!res.ok || !data.init_point) {
      return NextResponse.json({ error: data.message || 'Erro ao criar preferência.' }, { status: 500 })
    }
    return NextResponse.json({ init_point: data.init_point, id: data.id })
  } catch (err) {
    console.error('create-payment error:', err)
    return NextResponse.json({ error: 'Erro interno.' }, { status: 500 })
  }
}
