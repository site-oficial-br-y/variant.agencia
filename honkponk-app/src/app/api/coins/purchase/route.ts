import { NextRequest, NextResponse } from 'next/server'

const MP_ACCESS_TOKEN = process.env.MP_ACCESS_TOKEN!
const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://honkponk.com.br'

const COIN_PACKAGES: Record<string, { coins: number; price: number; label: string }> = {
  coins_10: { coins: 10, price: 9.9, label: '10 Honk Coins' },
  coins_30: { coins: 30, price: 19.9, label: '30 Honk Coins' },
  coins_60: { coins: 60, price: 34.9, label: '60 Honk Coins' },
}

export async function POST(request: NextRequest) {
  try {
    const { packageId, userId, email } = await request.json()

    const pkg = COIN_PACKAGES[packageId]
    if (!pkg || !userId) {
      return NextResponse.json({ error: 'Pacote inválido.' }, { status: 400 })
    }

    const preferenceBody = {
      items: [
        {
          id: packageId,
          title: `Honk Ponk — ${pkg.label}`,
          description: 'Honk Coins para buscas avulsas',
          quantity: 1,
          unit_price: pkg.price,
          currency_id: 'BRL',
        },
      ],
      payer: { email },
      back_urls: {
        success: `${APP_URL}/checkout/success?coins=${pkg.coins}&user=${userId}`,
        failure: `${APP_URL}/checkout/failure`,
        pending: `${APP_URL}/checkout/pending`,
      },
      auto_return: 'approved',
      external_reference: `${userId}|coins|${pkg.coins}`,
      notification_url: `${APP_URL}/api/webhook`,
      statement_descriptor: 'HONK PONK',
      metadata: { user_id: userId, coins: pkg.coins },
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
    console.error('coins/purchase error:', err)
    return NextResponse.json({ error: 'Erro interno.' }, { status: 500 })
  }
}
