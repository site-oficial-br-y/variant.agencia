import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { createClient as createServerClient } from '@/lib/supabase/server'
import { PLANS } from '@/lib/plans'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function POST(request: NextRequest) {
  try {
    const { ownerId, email } = await request.json()
    if (!ownerId || !email) {
      return NextResponse.json({ error: 'Dados inválidos.' }, { status: 400 })
    }

    const authClient = createServerClient()
    const { data: { user } } = await authClient.auth.getUser()
    if (!user || user.id !== ownerId) {
      return NextResponse.json({ error: 'Não autorizado.' }, { status: 401 })
    }

    const { data: owner } = await supabase.from('users_profiles').select('plan').eq('id', ownerId).single()
    if (!owner || owner.plan !== 'enterprise') {
      return NextResponse.json({ error: 'Apenas o plano Empresa pode adicionar membros.' }, { status: 403 })
    }

    const { data: existing } = await supabase.from('team_members').select('id').eq('owner_id', ownerId)
    const maxMembers = PLANS.enterprise.maxUsers - 1
    if ((existing?.length || 0) >= maxMembers) {
      return NextResponse.json({ error: `Limite de ${maxMembers} membros atingido.` }, { status: 400 })
    }

    const normalizedEmail = String(email).trim().toLowerCase()
    const { data: duplicate } = await supabase.from('team_members').select('id').eq('owner_id', ownerId).eq('member_email', normalizedEmail).maybeSingle()
    if (duplicate) {
      return NextResponse.json({ error: 'Esse e-mail já foi convidado.' }, { status: 400 })
    }

    const { error } = await supabase.from('team_members').insert({ owner_id: ownerId, member_email: normalizedEmail, status: 'pending' })
    if (error) throw error

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('team/invite error:', err)
    return NextResponse.json({ error: 'Erro interno.' }, { status: 500 })
  }
}
