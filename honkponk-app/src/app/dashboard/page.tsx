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

  const { data: teamMembers } = await supabase.from('team_members').select('*').eq('owner_id', user.id)
  return <DashboardClient user={user} profile={profile} teamMembers={teamMembers || []} />
}
