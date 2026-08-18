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
    signupsByDay: DayPoint[] // 90 dias — o cliente fatia por período
  }
  plans: {
    counts: Record<Plan, number>
    paying: number
    teamMembers: number
    expiringIn7: number
    mrrCents: number
    activeSubscriptions: number | null
  }
  coins: {
    inCirculation: number | null
    revenueCentsTotal: number | null
    recent: CoinPurchaseRow[] | null
  }
  searches: {
    total: number | null
    today: number | null
    byDay: DayPoint[] | null // 90 dias
    topSegments: Ranked[] | null
    topCities: Ranked[] | null
  }
  generatedAt: string
  warnings: string[]
}

const SERIES_DAYS = 90

const PLAN_KEYS: Plan[] = ['free', 'freelancer', 'agency', 'enterprise']

interface SearchLogRow {
  segment?: string | null
  location?: string | null
  created_at?: string | null
}

export interface CoinPurchaseRow {
  email: string | null
  coins: number
  amount_cents: number | null
  created_at: string
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

  // ── Perfis: planos, moedas, buscas de hoje ──
  const planCounts = { free: 0, freelancer: 0, agency: 0, enterprise: 0 } as Record<Plan, number>
  // MRR conta só quem realmente paga: membros de equipe herdam o plano do dono.
  const payingCounts = { free: 0, freelancer: 0, agency: 0, enterprise: 0 } as Record<Plan, number>
  let coinsTotal: number | null = null
  let searchesToday: number | null = null
  let teamMembers = 0
  let expiringIn7 = 0

  try {
    let cols = 'plan, honk_coins, searches_today, plan_expires_at, team_owner_id'
    let res = await admin.from('users_profiles').select(cols).limit(20000)
    if (res.error) {
      // Banco ainda sem as colunas novas — cai no conjunto mínimo.
      cols = 'plan, honk_coins, searches_today'
      res = await admin.from('users_profiles').select(cols).limit(20000)
      if (res.error) throw res.error
      warnings.push('users_profiles sem plan_expires_at/team_owner_id — MRR não desconta membros de equipe.')
    }

    coinsTotal = 0
    searchesToday = 0
    type Row = {
      plan?: string
      honk_coins?: number
      searches_today?: number
      plan_expires_at?: string | null
      team_owner_id?: string | null
    }
    for (const row of (res.data || []) as Row[]) {
      const p = (row.plan || 'free') as Plan
      if (PLAN_KEYS.includes(p)) {
        planCounts[p]++
        if (row.team_owner_id) teamMembers++
        else payingCounts[p]++
      }
      coinsTotal += row.honk_coins || 0
      searchesToday += row.searches_today || 0

      if (p !== 'free' && !row.team_owner_id && row.plan_expires_at) {
        const exp = new Date(row.plan_expires_at).getTime()
        if (exp >= now && exp <= now + 7 * DAY) expiringIn7++
      }
    }
  } catch {
    warnings.push('Não consegui ler users_profiles.')
  }

  const paying = payingCounts.freelancer + payingCounts.agency + payingCounts.enterprise
  const mrrCents =
    payingCounts.freelancer * PLANS.freelancer.price +
    payingCounts.agency * PLANS.agency.price +
    payingCounts.enterprise * PLANS.enterprise.price

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
    if (stamps.length) searchByDay = buildSeries(stamps, SERIES_DAYS)
  } catch {
    warnings.push('Não consegui ler search_logs.')
  }

  // ── Histórico de compra de coin ──
  let coinsRevenueCentsTotal: number | null = null
  let coinsRecent: CoinPurchaseRow[] | null = null
  try {
    const { data, error } = await admin
      .from('coin_purchases')
      .select('email, coins, amount_cents, created_at')
      .order('created_at', { ascending: false })
      .limit(500)
    if (error) throw error
    const rows = (data || []) as CoinPurchaseRow[]
    coinsRevenueCentsTotal = rows.reduce((acc, r) => acc + (r.amount_cents || 0), 0)
    coinsRecent = rows.slice(0, 20)
  } catch {
    warnings.push('Tabela coin_purchases ainda não existe — histórico de compras indisponível (só o saldo atual).')
  }

  const stats: AdminStats = {
    users: { total: usersTotal, signupsByDay: buildSeries(signupDates, SERIES_DAYS) },
    plans: { counts: planCounts, paying, teamMembers, expiringIn7, mrrCents, activeSubscriptions },
    coins: { inCirculation: coinsTotal, revenueCentsTotal: coinsRevenueCentsTotal, recent: coinsRecent },
    searches: { total: searchTotal, today: searchesToday, byDay: searchByDay, topSegments, topCities },
    generatedAt: new Date().toISOString(),
    warnings,
  }

  return <AdminClient stats={stats} email={user.email} />
}
