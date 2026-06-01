import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { canSearch } from '@/lib/plans'
import { SEGMENT_QUERIES } from '@/lib/search'
import type { Plan } from '@/lib/plans'

const GOOGLE_KEY = process.env.GOOGLE_PLACES_KEY || ''

export async function POST(req: NextRequest) {
  const { service, city, segment, allBrazil } = await req.json()

  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  let profile: { id: string; plan: Plan; searches_today: number; searches_reset_at: string } | null = null

  if (user) {
    const { data } = await supabase.from('users_profiles').select('id,plan,searches_today,searches_reset_at').eq('id', user.id).single()
    profile = data
  }

  const plan: Plan = profile?.plan ?? 'free'
  const resetAt = profile ? new Date(profile.searches_reset_at) : new Date(0)
  const todaySearches = new Date() > resetAt ? 0 : (profile?.searches_today ?? 0)

  if (!canSearch(plan, todaySearches)) {
    return NextResponse.json({ error: 'Limite atingido' }, { status: 403 })
  }

  const segConfig = SEGMENT_QUERIES[segment]
  if (!segConfig) return NextResponse.json({ error: 'Segmento inválido' }, { status: 400 })

  let lat = -23.9618, lng = -46.3322
  if (!allBrazil && city) {
    const geo = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(city + ', Brasil')}&key=${GOOGLE_KEY}`)
    const geoData = await geo.json()
    if (geoData.results?.[0]) {
      lat = geoData.results[0].geometry.location.lat
      lng = geoData.results[0].geometry.location.lng
    }
  }

  const radius = allBrazil ? 50000 : 15000
  const query = segConfig

  const placesRes = await fetch(
    `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&radius=${radius}&keyword=${encodeURIComponent(query)}&key=${GOOGLE_KEY}`
  )
  const placesData = await placesRes.json()
  const results = placesData.results || []

  if (user && profile) {
    const newCount = todaySearches + 1
    const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1); tomorrow.setHours(0, 0, 0, 0)
    await supabase.from('users_profiles').update({ searches_today: newCount, searches_reset_at: new Date() > resetAt ? tomorrow.toISOString() : profile.searches_reset_at }).eq('id', user.id)
  }

  return NextResponse.json({ results })
}
