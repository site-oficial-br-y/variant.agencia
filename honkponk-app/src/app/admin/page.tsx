import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { redirect } from 'next/navigation'
import { PLANS, type Plan } from '@/lib/plans'
import { AdminClient } from './AdminClient'

export const dynamic = 'force-dynamic'

export interface DayPoint { date: string; count: number }
export interface Ranked { label: string; count: number }

export interface AdminStats {
  users: {
    total: number
    last7: number
    last30: number
    signupsByDay: DayPoint[]
  }
  plans: {
    counts: Record<Plan, number>
    paying: number
    mrrCents: number
    activeSubscriptions: number | null
  }
  coins: { inCirculation: number | null }
  searches: {
    total: number | null
    last7: number | null
    last30: number | null
    today: number | null
    byDay: DayPoint[] | null
    topSegments: Ranked[] | null
    topCities: Ranked[] | null
  }
  warnings: string[]
}

const PLAN_KEYS: Plan[] = ['free', 'freelancer', 'agency', 'enterprise']

interface SearchLogRow {
  segment?: string | null
  location?: string | null
  created_at?: string | null
}

function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/** Últimos N dias como série contínua, sem buracos. */
function buildSeries(dates: string[], days: number): DayPoint[] {
  const bucket = new Map<string, number>()
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    bucket.set(dayKey(d), 0)
  }
  for (const iso of dates) {
    if (!iso) continue
    const k = iso.slice(0, 10)
    if (bucket.has(k)) bucket.set(k, (bucket.get(k) || 0) + 1)
  }
  return Array.from(bucket, ([date, count]) => ({ date, count }))
}

function rank(values: (string | null | undefined)[], limit: number): Ranked[] {
  const m = new Map<string, number>()
  for (const v of values) {
    const label = (v || '').trim()
    if (!label) continue
    m.set(label, (m.get(label) || 0) + 1)
  }
  return Array.from(m, ([label, count]) => ({ label, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, limit)
}

export default async function AdminPage() {
  // 1. Precisa estar logado
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  // 2. Precisa ser admin. Sem ADMIN_EMAILS configurado, ninguém entra (fail-closed).
  const allowList = (process.env.ADMIN_EMAILS || '')
    .split(',')
    .map(e => e.trim().toLowerCase())
    .filter(Boolean)

  if (allowList.length === 0) {
    return <AdminClient setup="no-admin-emails" />
  }
  if (!user.email || !allowList.includes(user.email.toLowerCase())) {
    redirect('/dashboard')
  }

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!serviceKey) {
    return <AdminClient setup="no-service-key" />
  }

  // 3. Cliente admin — só existe no servidor, a chave nunca vai pro navegador
  const admin = createAdminClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const warnings: string[] = []
  const now = Date.now()
  const DAY = 86400000
  const since7 = new Date(now - 7 * DAY)
  const since30 = new Date(now - 30 * DAY)

  // ── Usuários (auth.users tem created_at garantido) ──
  const signupDates: string[] = []
  try {
    for (let page = 1; page <= 20; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 })
      if (error) throw error
      const batch = data?.users || []
      for (const u of batch) if (u.created_at) signupDates.push(u.created_at)
      if (batch.length < 1000) break
    }
  } catch {
    warnings.push('Não consegui ler a lista de usuários (auth).')
  }

  const usersTotal = signupDates.length
  const last7 = signupDates.filter(d => new Date(d) >= since7).length
  const last30 = signupDates.filter(d => new Date(d) >= since30).length

  // ── Perfis: planos, moedas, buscas de hoje ──
  const planCounts = { free: 0, freelancer: 0, agency: 0, enterprise: 0 } as Record<Plan, number>
  let coinsTotal: number | null = null
  let searchesToday: number | null = null
  try {
    const { data, error } = await admin
      .from('users_profiles')
      .select('plan, honk_coins, searches_today')
      .limit(20000)
    if (error) throw error
    coinsTotal = 0
    searchesToday = 0
    for (const row of (data || []) as { plan?: string; honk_coins?: number; searches_today?: number }[]) {
      const p = (row.plan || 'free') as Plan
      if (PLAN_KEYS.includes(p)) planCounts[p]++
      coinsTotal += row.honk_coins || 0
      searchesToday += row.searches_today || 0
    }
  } catch {
    warnings.push('Não consegui ler users_profiles.')
  }

  const paying = planCounts.freelancer + planCounts.agency + planCounts.enterprise
  const mrrCents =
    planCounts.freelancer * PLANS.freelancer.price +
    planCounts.agency * PLANS.agency.price +
    planCounts.enterprise * PLANS.enterprise.price

  // ── Assinaturas ativas ──
  let activeSubscriptions: number | null = null
  try {
    const { count, error } = await admin
      .from('subscriptions')
      .select('user_id', { count: 'exact', head: true })
      .eq('status', 'active')
    if (error) throw error
    activeSubscriptions = count ?? 0
  } catch {
    activeSubscriptions = null
  }

  // ── Buscas ──
  let searchTotal: number | null = null
  let search7: number | null = null
  let search30: number | null = null
  let searchByDay: DayPoint[] | null = null
  let topSegments: Ranked[] | null = null
  let topCities: Ranked[] | null = null

  try {
    // Tenta com created_at; se a coluna não existir, cai no plano B sem datas.
    let list: SearchLogRow[] = []
    const withTime = await admin
      .from('search_logs')
      .select('segment, location, created_at')
      .order('created_at', { ascending: false })
      .limit(50000)

    if (withTime.error) {
      const plain = await admin.from('search_logs').select('segment, location').limit(50000)
      if (plain.error) throw plain.error
      list = (plain.data || []) as SearchLogRow[]
      warnings.push('search_logs não tem coluna de data — gráfico de buscas indisponível.')
    } else {
      list = (withTime.data || []) as SearchLogRow[]
    }

    searchTotal = list.length
    topSegments = rank(list.map(r => r.segment), 8)
    topCities = rank(list.map(r => r.location), 8)

    const stamps = list.map(r => r.created_at).filter(Boolean) as string[]
    if (stamps.length) {
      search7 = stamps.filter(d => new Date(d) >= since7).length
      search30 = stamps.filter(d => new Date(d) >= since30).length
      searchByDay = buildSeries(stamps, 30)
    }
  } catch {
    warnings.push('Não consegui ler search_logs.')
  }

  const stats: AdminStats = {
    users: { total: usersTotal, last7, last30, signupsByDay: buildSeries(signupDates, 30) },
    plans: { counts: planCounts, paying, mrrCents, activeSubscriptions },
    coins: { inCirculation: coinsTotal },
    searches: {
      total: searchTotal,
      last7: search7,
      last30: search30,
      today: searchesToday,
      byDay: searchByDay,
      topSegments,
      topCities,
    },
    warnings,
  }

  return <AdminClient stats={stats} email={user.email} />
}
