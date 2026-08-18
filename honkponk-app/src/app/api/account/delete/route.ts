import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'

// Exclusão de conta pelo próprio usuário (atende ao direito de exclusão da LGPD).
// Antes só dava pra pedir por e-mail e alguém excluir na mão.
export async function POST(_request: NextRequest) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    return NextResponse.json({ error: 'Não autenticado.' }, { status: 401 })
  }

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!serviceKey) {
    return NextResponse.json({ error: 'Exclusão indisponível no momento. Tente novamente mais tarde.' }, { status: 500 })
  }

  const admin = createAdminClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const userId = user.id
  const email = user.email || ''

  try {
    // Apaga os dados nas tabelas que dependem do usuário antes de apagar a conta em si.
    await admin.from('coin_purchases').delete().eq('user_id', userId)
    await admin.from('search_logs').delete().eq('user_id', userId)
    await admin.from('subscriptions').delete().eq('user_id', userId)
    await admin.from('team_members').delete().eq('owner_id', userId)
    if (email) await admin.from('team_members').delete().eq('member_email', email)
    await admin.from('users_profiles').delete().eq('id', userId)

    // Por último, a conta de autenticação em si.
    const { error } = await admin.auth.admin.deleteUser(userId)
    if (error) throw error

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('account delete error:', err)
    return NextResponse.json({ error: 'Não foi possível excluir a conta. Tente de novo ou peça em honkponkoficial@gmail.com.' }, { status: 500 })
  }
}
