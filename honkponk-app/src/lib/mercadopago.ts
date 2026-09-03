/**
 * Leitura do histórico real de pagamentos no Mercado Pago.
 *
 * A tabela `subscriptions` do Supabase só sabe quem assinou e quando — ela não
 * registra cobrança nenhuma. Então MRR dali é projeção, não faturamento.
 * Quem tem o número de verdade (quantas renovações foram aprovadas, quanto o
 * Mercado Pago descontou de taxa, quanto caiu líquido) é a API deles.
 *
 * Só roda no servidor: usa MP_ACCESS_TOKEN, que nunca pode ir pro navegador.
 */

const MP_ACCESS_TOKEN = process.env.MP_ACCESS_TOKEN

export interface MpPayment {
  id: number
  email: string | null
  description: string | null
  grossCents: number
  netCents: number
  feeCents: number
  approvedAt: string
}

export interface MpMonthPoint {
  month: string // YYYY-MM
  grossCents: number
  netCents: number
  count: number
}

export interface MpSummary {
  count: number
  grossCents: number
  netCents: number
  feeCents: number
  byMonth: MpMonthPoint[]
  /** Histórico completo, do mais recente pro mais antigo. O painel mostra
   *  os primeiros e revela o resto num botão. */
  list: MpPayment[]
  firstApprovedAt: string | null
  truncated: boolean
}

const toCents = (v: unknown) => Math.round((typeof v === 'number' ? v : 0) * 100)

interface RawPayment {
  id?: number
  status?: string
  description?: string | null
  transaction_amount?: number
  date_approved?: string | null
  date_created?: string | null
  payer?: { email?: string | null } | null
  transaction_details?: { net_received_amount?: number } | null
  fee_details?: { amount?: number }[] | null
}

/**
 * Busca os pagamentos aprovados, do mais recente pro mais antigo.
 * A busca do Mercado Pago pagina de 100 em 100 e não deixa passar de offset 1000,
 * daí o teto — acima disso o retorno vem marcado como truncado em vez de mentir
 * um total menor que o real.
 */
export async function getMercadoPagoSummary(): Promise<MpSummary | null> {
  if (!MP_ACCESS_TOKEN) return null

  const PAGE = 100
  const MAX_OFFSET = 1000
  const all: RawPayment[] = []
  let truncated = false

  for (let offset = 0; offset <= MAX_OFFSET; offset += PAGE) {
    const url = new URL('https://api.mercadopago.com/v1/payments/search')
    url.searchParams.set('status', 'approved')
    url.searchParams.set('sort', 'date_created')
    url.searchParams.set('criteria', 'desc')
    url.searchParams.set('limit', String(PAGE))
    url.searchParams.set('offset', String(offset))

    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
      cache: 'no-store',
    })
    if (!res.ok) {
      // Token inválido/sem permissão de leitura: melhor não mostrar nada do que
      // mostrar um total parcial que o dono vai ler como faturamento real.
      if (all.length === 0) return null
      truncated = true
      break
    }

    const data = await res.json()
    const batch: RawPayment[] = data?.results || []
    all.push(...batch)

    const total: number = data?.paging?.total ?? all.length
    if (batch.length < PAGE) break
    if (offset + PAGE > MAX_OFFSET && total > all.length) {
      truncated = true
      break
    }
  }

  const payments: MpPayment[] = all
    .filter(p => p.status === 'approved')
    .map(p => {
      const gross = toCents(p.transaction_amount)
      const fee = (p.fee_details || []).reduce((acc, f) => acc + toCents(f.amount), 0)
      // net_received_amount é o que o Mercado Pago diz que caiu. Quando ele não
      // vem preenchido, bruto menos taxas é a melhor aproximação.
      const netRaw = p.transaction_details?.net_received_amount
      const net = typeof netRaw === 'number' && netRaw > 0 ? toCents(netRaw) : gross - fee
      return {
        id: p.id ?? 0,
        email: p.payer?.email ?? null,
        description: p.description ?? null,
        grossCents: gross,
        netCents: net,
        feeCents: fee,
        approvedAt: p.date_approved || p.date_created || '',
      }
    })
    .filter(p => p.approvedAt)
    .sort((a, b) => b.approvedAt.localeCompare(a.approvedAt))

  const monthMap = new Map<string, MpMonthPoint>()
  for (const p of payments) {
    const month = p.approvedAt.slice(0, 7)
    const cur = monthMap.get(month) || { month, grossCents: 0, netCents: 0, count: 0 }
    cur.grossCents += p.grossCents
    cur.netCents += p.netCents
    cur.count++
    monthMap.set(month, cur)
  }

  return {
    count: payments.length,
    grossCents: payments.reduce((a, p) => a + p.grossCents, 0),
    netCents: payments.reduce((a, p) => a + p.netCents, 0),
    feeCents: payments.reduce((a, p) => a + p.feeCents, 0),
    byMonth: Array.from(monthMap.values()).sort((a, b) => a.month.localeCompare(b.month)),
    list: payments,
    firstApprovedAt: payments.length ? payments[payments.length - 1].approvedAt : null,
    truncated,
  }
}
