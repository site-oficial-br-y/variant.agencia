import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(request: NextRequest) {
  try {
    const { rating, message } = await request.json()
    if ((!rating || rating < 1) && !message?.trim()) {
      return NextResponse.json({ error: 'Feedback vazio.' }, { status: 400 })
    }

    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      return NextResponse.json({ error: 'Não autorizado.' }, { status: 401 })
    }

    const { error } = await supabase.from('feedbacks').insert({
      user_id: user.id,
      email: user.email,
      rating: rating || null,
      message: (message || '').slice(0, 2000),
    })
    if (error) throw error

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('feedback error:', err)
    return NextResponse.json({ error: 'Erro interno.' }, { status: 500 })
  }
}
