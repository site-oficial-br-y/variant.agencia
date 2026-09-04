import { createClient } from '@/lib/supabase/server'
import { createClient as createAdminClient } from '@supabase/supabase-js'
import { redirect } from 'next/navigation'
import { PLANS, type Plan } from '@/lib/plans'
import { AdminClient } from './AdminClient'
import { getMercadoPagoSummary, type MpSummary } from '@/lib/mercadopago'

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
    courtesy: number | null
  }
  coins: {
    inCirculation: number | null
    revenueCentsTotal: number | null
    recent: CoinPurchaseRow[] | null
  }
  extra: {
    totalCents: number | null
    recent: ExtraRevenueRow[] | null
  }
  /** Faturamento real, vindo da API do Mercado Pago. null = não deu pra ler. */
  payments: MpSummary | null
  /** Custo estimado da Places API. null = sem dados suficientes pra calibrar. */
  apiCost: ApiCostEstimate | null
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
  all_brazil?: boolean | null
}

/**
 * Estimativa de custo do Google, calculada a partir das buscas registradas.
 *
 * O painel de faturamento do Google atrasa dias e às vezes só solta o número
 * depois do mês fechar. Como toda busca fica em `search_logs` e o consumo de
 * API por busca é previsível, dá pra ter a conta em tempo real sem depender
 * deles.
 *
 * O preço por chamada não é chutado: vem da divisão entre uma fatura real e o
 * número de chamadas daquele mesmo mês. Se o Google mudar preço, é só atualizar
 * a referência abaixo com a fatura mais recente.
 */
const API_COST_REFERENCE = {
  month: '2026-08',
  invoiceCents: 2484, // fatura de agosto/2026, cobrada em 01/09
}

/** Busca "Todo Brasil" varre 10 cidades. Busca de cidade faz 1 a 3 chamadas
 *  conforme o plano, mais eventuais tentativas de raio maior — 2 é a média. */
const CALLS_ALL_BRAZIL = 10
const CALLS_SINGLE_CITY = 2

const callsOf = (r: SearchLogRow) => (r.all_brazil ? CALLS_ALL_BRAZIL : CALLS_SINGLE_CITY)

export interface ApiCostEstimate {
  /** Centavos por chamada, derivado da fatura de referência. */
  centsPerCall: number
  referenceMonth: string
  referenceInvoiceCents: number
  referenceCalls: number
  monthCalls: number
  monthCostCents: number
  /** Projeção do mês inteiro no ritmo atual. */
  projectedCostCents: number
  daysElapsed: number
  daysInMonth: number
}

export interface CoinPurchaseRow {
  email: string | null
  coins: number
  amount_cents: number | null
  created_at: string
}

/** Receita fora do sistema (freela, bico) — não é recorrente, então fica separada do MRR. */
export interface ExtraRevenueRow {
  description: string
  amount_cents: number
  received_at: string
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

  // MRR contado a partir das assinaturas de verdade, não do campo `plan` do perfil:
  // o perfil também fica pago em cortesia/parceria, na conta do próprio dono e em plano
  // vencido que ainda não foi rebaixado (o rebaixamento só roda quando a pessoa volta ao
  // site). Contar por perfil inflava o número — mrrCents agora é receita real, e
  // courtesyCount mostra quantos perfis pagos não têm assinatura por trás.
  let mrrCents = 0
  let courtesyCount: number | null = null
  try {
    const { data, error } = await admin
      .from('subscriptions')
      .select('plan')
      .eq('status', 'active')
      .limit(20000)
    if (error) throw error
    const realCounts = { free: 0, freelancer: 0, agency: 0, enterprise: 0 } as Record<Plan, number>
    for (const row of (data || []) as { plan?: string }[]) {
      const p = (row.plan || 'free') as Plan
      if (PLAN_KEYS.includes(p)) realCounts[p]++
    }
    mrrCents =
      realCounts.freelancer * PLANS.freelancer.price +
      realCounts.agency * PLANS.agency.price +
      realCounts.enterprise * PLANS.enterprise.price
    courtesyCount = Math.max(0, paying - (realCounts.freelancer + realCounts.agency + realCounts.enterprise))
  } catch {
    // Sem a tabela de assinaturas, cai no cálculo antigo (por perfil) e avisa que está inflado.
    mrrCents =
      payingCounts.freelancer * PLANS.freelancer.price +
      payingCounts.agency * PLANS.agency.price +
      payingCounts.enterprise * PLANS.enterprise.price
    warnings.push('Não consegui ler subscriptions — MRR calculado por perfil, então inclui cortesias e planos vencidos.')
  }

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

  let searchLogs: SearchLogRow[] = []
  try {
    // Tenta com created_at; se a coluna não existir, cai no plano B sem datas.
    let list: SearchLogRow[] = []
    const withTime = await admin
      .from('search_logs')
      .select('segment, location, created_at, all_brazil')
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

    searchLogs = list
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

  // ── Receita fora do sistema (freela/bico) ──
  let extraTotalCents: number | null = null
  let extraRecent: ExtraRevenueRow[] | null = null
  try {
    const { data, error } = await admin
      .from('extra_revenue')
      .select('description, amount_cents, received_at')
      .order('received_at', { ascending: false })
      .limit(500)
    if (error) throw error
    const rows = (data || []) as ExtraRevenueRow[]
    extraTotalCents = rows.reduce((acc, r) => acc + (r.amount_cents || 0), 0)
    extraRecent = rows.slice(0, 20)
  } catch {
    warnings.push('Tabela extra_revenue ainda não existe — receita de freela não entra no saldo.')
  }

  // ── Custo estimado da Places API ──
  let apiCost: ApiCostEstimate | null = null
  {
    const callsInMonth = (month: string) =>
      searchLogs.reduce((acc, r) => (r.created_at?.slice(0, 7) === month ? acc + callsOf(r) : acc), 0)

    const referenceCalls = callsInMonth(API_COST_REFERENCE.month)
    if (referenceCalls > 0) {
      const centsPerCall = API_COST_REFERENCE.invoiceCents / referenceCalls
      const today = new Date()
      const currentMonth = dayKey(today).slice(0, 7)
      const monthCalls = callsInMonth(currentMonth)
      const monthCostCents = Math.round(monthCalls * centsPerCall)
      const daysElapsed = today.getDate()
      const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()

      apiCost = {
        centsPerCall,
        referenceMonth: API_COST_REFERENCE.month,
        referenceInvoiceCents: API_COST_REFERENCE.invoiceCents,
        referenceCalls,
        monthCalls,
        monthCostCents,
        projectedCostCents: Math.round((monthCostCents / daysElapsed) * daysInMonth),
        daysElapsed,
        daysInMonth,
      }
    } else {
      warnings.push(`Sem buscas registradas em ${API_COST_REFERENCE.month} — não deu pra calibrar o custo por chamada.`)
    }
  }

  // ── Faturamento real (Mercado Pago) ──
  let payments: MpSummary | null = null
  try {
    payments = await getMercadoPagoSummary()
    if (!payments) {
      warnings.push('Não consegui ler os pagamentos no Mercado Pago — confira se MP_ACCESS_TOKEN está configurado na Vercel.')
    } else if (payments.truncated) {
      warnings.push('O histórico do Mercado Pago passou do limite de paginação — o total mostrado é parcial (só os mais recentes).')
    }
  } catch {
    warnings.push('Erro ao consultar o Mercado Pago.')
  }

  const stats: AdminStats = {
    users: { total: usersTotal, signupsByDay: buildSeries(signupDates, SERIES_DAYS) },
    plans: { counts: planCounts, paying, teamMembers, expiringIn7, mrrCents, activeSubscriptions, courtesy: courtesyCount },
    coins: { inCirculation: coinsTotal, revenueCentsTotal: coinsRevenueCentsTotal, recent: coinsRecent },
    extra: { totalCents: extraTotalCents, recent: extraRecent },
    payments,
    apiCost,
    searches: { total: searchTotal, today: searchesToday, byDay: searchByDay, topSegments, topCities },
    generatedAt: new Date().toISOString(),
    warnings,
  }

  return <AdminClient stats={stats} email={user.email} />
}
