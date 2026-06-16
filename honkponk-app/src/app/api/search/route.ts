import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { canSearch } from '@/lib/plans'
import type { Plan } from '@/lib/plans'

export async function POST(req: NextRequest) {
  const body = await req.json()
  const { checkOnly, countOnly } = body

  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  let profile: { id: string; plan: Plan; searches_today: number; searches_reset_at: string; honk_coins?: number; plan_expires_at?: string | null; team_owner_id?: string | null } | null = null
  if (user) {
    const { data } = await supabase.from('users_profiles').select('id,plan,searches_today,searches_reset_at,honk_coins,plan_expires_at,team_owner_id').eq('id', user.id).single()
    profile = data
  }

  // Expirou o plano pago → vira free
  if (profile && profile.plan !== 'free' && !profile.team_owner_id && profile.plan_expires_at) {
    if (new Date(profile.plan_expires_at) < new Date()) {
      if (user) await supabase.from('users_profiles').update({ plan: 'free', plan_expires_at: null }).eq('id', user.id)
      profile = { ...profile, plan: 'free', plan_expires_at: null }
    }
  }

  const plan: Plan = profile?.plan ?? 'free'
  const resetAt = profile ? new Date(profile.searches_reset_at) : new Date(0)
  const todaySearches = new Date() > resetAt ? 0 : (profile?.searches_today ?? 0)

  if (!canSearch(plan, todaySearches)) {
    const coins = profile?.honk_coins || 0
    if (coins <= 0) {
      return NextResponse.json({ error: 'Limite atingido' }, { status: 403 })
    }
    // Has coins — allow the search; coin will be deducted in countOnly step
  }

  if (checkOnly) {
    return NextResponse.json({ ok: true })
  }

  if (countOnly && user && profile) {
    const overLimit = !canSearch(plan, todaySearches)
    if (overLimit) {
      const coins = profile?.honk_coins || 0
      await supabase.from('users_profiles').update({ honk_coins: Math.max(0, coins - 1) }).eq('id', user.id)
    } else {
      const newCount = todaySearches + 1
      const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1); tomorrow.setHours(0, 0, 0, 0)
      await supabase.from('users_profiles').update({
        searches_today: newCount,
        searches_reset_at: new Date() > resetAt ? tomorrow.toISOString() : profile.searches_reset_at
      }).eq('id', user.id)
    }
    const { segment, city, allBrazil } = body
    await supabase.from('search_logs').insert({ user_id: user.id, email: user.email, segment, location: allBrazil ? 'Todo Brasil' : (city || '') })
    return NextResponse.json({ ok: true })
  }

  return NextResponse.json({ ok: true })
}
