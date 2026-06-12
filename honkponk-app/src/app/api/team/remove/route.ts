import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { createClient as createServerClient } from '@/lib/supabase/server'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function POST(request: NextRequest) {
  try {
    const { ownerId, memberId } = await request.json()
    if (!ownerId || !memberId) {
      return NextResponse.json({ error: 'Dados inválidos.' }, { status: 400 })
    }

    const authClient = createServerClient()
    const { data: { user } } = await authClient.auth.getUser()
    if (!user || user.id !== ownerId) {
      return NextResponse.json({ error: 'Não autorizado.' }, { status: 401 })
    }

    const { data: member } = await supabase.from('team_members').select('id, member_email, status').eq('id', memberId).eq('owner_id', ownerId).single()
    if (!member) {
      return NextResponse.json({ error: 'Membro não encontrado.' }, { status: 404 })
    }

    if (member.status === 'active') {
      await supabase.from('users_profiles').update({ plan: 'free', team_owner_id: null }).eq('email', member.member_email).eq('team_owner_id', ownerId)
    }

    await supabase.from('team_members').delete().eq('id', memberId).eq('owner_id', ownerId)

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('team/remove error:', err)
    return NextResponse.json({ error: 'Erro interno.' }, { status: 500 })
  }
}
