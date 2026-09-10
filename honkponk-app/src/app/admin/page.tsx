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
    /** Assinantes que realmente pagam, contados em `subscriptions`. */
    paidSubscriptions: number | null
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
  /** Consumo real da API do Google. null = tabela api_calls ainda não existe. */
  apiUsage: ApiUsage | null
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

/**
 * Consumo real da API do Google, contado em `api_calls`.
 *
 * A versão anterior estimava custo multiplicando linhas de `search_logs` por um
 * peso por tipo de busca. Errava por mais de 20x: `search_logs` grava toda busca
 * do usuário, e a maioria é respondida pelo cache sem nunca chegar no Google.
 * Contava busca, não chamada paga. Agora a rota registra só o que de fato sai
 * para o Google, e aqui é contagem, não dedução.
 *
 * Também não converte mais para reais. O Google tem cota mensal gratuita e cobra
 * só o excedente, então chamada não tem preço único — enquanto o consumo couber
 * no gratuito, qualquer valor em reais que o painel mostrasse seria ficção.
 * O que dá para afirmar é quantas chamadas foram feitas e o quanto isso se
 * aproxima do teto gratuito.
 */
const FREE_TIER_REFERENCE = 1000 // por API, por mês — confirmar no relatório por SKU

export interface ApiUsage {
  places: number
  geocode: number
  total: number
  /** Mesmo período do mês anterior, para comparar ritmo. */
  previousMonthTotal: number
  /** Projeção de chamadas no mês inteiro, mantido o ritmo atual. */
  projectedTotal: number
  freeTierReference: number
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

// A Vercel roda em UTC e Brasília é UTC-3. Agrupar por dia sem corrigir isso jogava
// tudo que acontece depois das 21h para o dia seguinte no gráfico.
const BRASILIA_OFFSET_MS = 3 * 60 * 60 * 1000

/** Data no calendário de Brasília, no formato YYYY-MM-DD. */
function dayKey(d: Date) {
  return new Date(d.getTime() - BRASILIA_OFFSET_MS).toISOString().slice(0, 10)
}

/** Últimos N dias como série contínua, sem buracos. */
function buildSeries(dates: string[], days: number): DayPoint[] {
  const bucket = new Map<string, number>()
  const now = Date.now()
  for (let i = days - 1; i >= 0; i--) {
    bucket.set(dayKey(new Date(now - i * 86400000)), 0)
  }
  for (const iso of dates) {
    if (!iso) continue
    const k = dayKey(new Date(iso))
    if (bucket.has(k)) bucket.set(k, (bucket.get(k) || 0) + 1)
  }
  return Array.from(bucket, ([date, count]) => ({ date, count }))
}


/**
 * O Supabase corta cada requisição em 1.000 linhas, e `.limit()` não passa por
 * cima disso. Sem paginar, o painel lia só o primeiro milheiro de perfis e
 * calculava plano, moedas e buscas em cima de um pedaço da base — foi o que fez
 * o MRR aparecer com 13 assinantes ao lado de 31 assinaturas ativas.
 */
async function fetchAll<T>(
  run: (from: number, to: number) => PromiseLike<{ data: unknown; error: unknown }>,
): Promise<T[]> {
  const PAGE = 1000
  const out: T[] = []
  for (let from = 0; from < 200000; from += PAGE) {
    const { data, error } = await run(from, from + PAGE - 1)
    if (error) throw error
    const batch = (data || []) as T[]
    out.push(...batch)
    if (batch.length < PAGE) break
  }
  return out
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
    const fullCols = 'plan, honk_coins, searches_today, searches_reset_at, plan_expires_at, team_owner_id'
    let profiles: Record<string, unknown>[] = []
    try {
      profiles = await fetchAll((from, to) => admin.from('users_profiles').select(fullCols).range(from, to))
    } catch {
      // Banco ainda sem as colunas novas — cai no conjunto mínimo.
      profiles = await fetchAll((from, to) => admin.from('users_profiles').select('plan, honk_coins, searches_today').range(from, to))
      warnings.push('users_profiles sem plan_expires_at/team_owner_id — MRR não desconta membros de equipe.')
    }

    coinsTotal = 0
    searchesToday = 0
    type Row = {
      plan?: string
      honk_coins?: number
      searches_today?: number
      searches_reset_at?: string | null
      plan_expires_at?: string | null
      team_owner_id?: string | null
    }
    for (const row of profiles as Row[]) {
      const p = (row.plan || 'free') as Plan
      if (PLAN_KEYS.includes(p)) {
        planCounts[p]++
        if (row.team_owner_id) teamMembers++
        else payingCounts[p]++
      }
      coinsTotal += row.honk_coins || 0
      // O contador só zera quando a pessoa busca de novo, então perfil parado
      // guarda o número de dias atrás. Sem checar a validade, este card somava
      // buscas antigas e mostrava sempre mais do que aconteceu hoje.
      if (row.searches_reset_at && new Date(row.searches_reset_at).getTime() > now) {
        searchesToday += row.searches_today || 0
      }

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
  // Quantos assinantes de verdade sustentam o MRR — o card mostrava o total de
  // perfis pagos, que é outra coisa e vinha do trecho truncado.
  let paidSubscriptions: number | null = null
  try {
    const data = await fetchAll<{ plan?: string }>((from, to) =>
      admin.from('subscriptions').select('plan').eq('status', 'active').range(from, to))
    const realCounts = { free: 0, freelancer: 0, agency: 0, enterprise: 0 } as Record<Plan, number>
    for (const row of data) {
      const p = (row.plan || 'free') as Plan
      if (PLAN_KEYS.includes(p)) realCounts[p]++
    }
    paidSubscriptions = realCounts.freelancer + realCounts.agency + realCounts.enterprise
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

  try {
    // Tenta com created_at; se a coluna não existir, cai no plano B sem datas.
    let list: SearchLogRow[] = []
    try {
      list = await fetchAll<SearchLogRow>((from, to) =>
        admin.from('search_logs').select('segment, location, created_at').order('created_at', { ascending: false }).range(from, to))
    } catch {
      list = await fetchAll<SearchLogRow>((from, to) =>
        admin.from('search_logs').select('segment, location').range(from, to))
      warnings.push('search_logs não tem coluna de data — gráfico de buscas indisponível.')
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
    const rows = await fetchAll<CoinPurchaseRow>((from, to) =>
      admin.from('coin_purchases').select('email, coins, amount_cents, created_at').order('created_at', { ascending: false }).range(from, to))
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

  // ── Consumo real da API do Google ──
  let apiUsage: ApiUsage | null = null
  try {
    const today = new Date()
    const daysElapsed = today.getDate()
    const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()
    const monthStart = new Date(Date.UTC(today.getFullYear(), today.getMonth(), 1)).toISOString()
    const prevStart = new Date(Date.UTC(today.getFullYear(), today.getMonth() - 1, 1)).toISOString()

    const rows = await fetchAll<{ provider?: string; created_at?: string }>((from, to) =>
      admin.from('api_calls').select('provider, created_at').gte('created_at', prevStart).range(from, to))
    let places = 0
    let geocode = 0
    let previousMonthTotal = 0
    for (const r of rows) {
      if (!r.created_at) continue
      if (r.created_at >= monthStart) {
        if (r.provider === 'geocode') geocode++
        else places++
      } else if (new Date(r.created_at).getUTCDate() <= daysElapsed) {
        // Mesmo trecho do mês anterior, senão comparar um mês fechado com
        // um mês pela metade sempre acusaria queda.
        previousMonthTotal++
      }
    }

    const total = places + geocode
    apiUsage = {
      places,
      geocode,
      total,
      previousMonthTotal,
      projectedTotal: Math.round((total / daysElapsed) * daysInMonth),
      freeTierReference: FREE_TIER_REFERENCE,
      daysElapsed,
      daysInMonth,
    }
  } catch {
    warnings.push('Tabela api_calls ainda não existe — rode api_calls.sql no Supabase pra acompanhar o consumo do Google.')
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
    plans: { counts: planCounts, paying, paidSubscriptions, teamMembers, expiringIn7, mrrCents, activeSubscriptions, courtesy: courtesyCount },
    coins: { inCirculation: coinsTotal, revenueCentsTotal: coinsRevenueCentsTotal, recent: coinsRecent },
    extra: { totalCents: extraTotalCents, recent: extraRecent },
    payments,
    apiUsage,
    searches: { total: searchTotal, today: searchesToday, byDay: searchByDay, topSegments, topCities },
    generatedAt: new Date().toISOString(),
    warnings,
  }

  return <AdminClient stats={stats} email={user.email} />
}
