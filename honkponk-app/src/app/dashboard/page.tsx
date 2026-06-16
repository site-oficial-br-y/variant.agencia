import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { DashboardClient } from './DashboardClient'

export default async function DashboardPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  let { data: profile } = await supabase.from('users_profiles').select('*').eq('id', user.id).single()
  if (!profile) {
    const { data: newProfile } = await supabase.from('users_profiles').insert({ id: user.id, email: user.email, plan: 'free', searches_today: 0, searches_reset_at: new Date().toISOString() }).select().single()
    profile = newProfile
  }

  // Verifica expiração do plano (planos pagos expiram em 30 dias)
  if (profile && profile.plan !== 'free' && !profile.team_owner_id && profile.plan_expires_at) {
    if (new Date(profile.plan_expires_at) < new Date()) {
      await supabase.from('users_profiles').update({ plan: 'free', plan_expires_at: null }).eq('id', user.id)
      profile = { ...profile, plan: 'free', plan_expires_at: null }
    }
  }

  // Ativa convite de equipe pendente (plano Empresa)
  if (profile && profile.plan !== 'enterprise' && !profile.team_owner_id && user.email) {
    const { data: invite } = await supabase
      .from('team_members')
      .select('id, owner_id')
      .eq('member_email', user.email)
      .eq('status', 'pending')
      .limit(1)
      .maybeSingle()

    if (invite) {
      await supabase.from('users_profiles').update({ plan: 'enterprise', team_owner_id: invite.owner_id }).eq('id', user.id)
      await supabase.from('team_members').update({ status: 'active' }).eq('id', invite.id)
      profile = { ...profile, plan: 'enterprise', team_owner_id: invite.owner_id }
    }
  }

  const { data: teamMembers } = await supabase.from('team_members').select('*').eq('owner_id', user.id)
  return <DashboardClient user={user} profile={profile} teamMembers={teamMembers || []} />
}
