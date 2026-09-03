'use client'

import { useState, useMemo, useEffect, useRef, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { PLANS, type Plan } from '@/lib/plans'
import type { AdminStats, DayPoint, Ranked, CoinPurchaseRow, ExtraRevenueRow } from './page'
import type { MpSummary } from '@/lib/mercadopago'

// Centavos importam aqui: com planos de 19,90 e 59,90 o total quase nunca é redondo,
// e arredondar escondia a diferença (ex: R$418,30 aparecia como R$418).
const BRL = (cents: number) =>
  (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', minimumFractionDigits: 2, maximumFractionDigits: 2 })

const num = (n: number | null | undefined) => (n === null || n === undefined ? '—' : n.toLocaleString('pt-BR'))

const PLAN_COLOR: Record<Plan, string> = {
  free: '#6b7280',
  freelancer: '#f8b6c8',
  agency: '#e879a0',
  enterprise: '#c2185b',
}

const PERIODS = [
  { key: 7, label: '7 dias' },
  { key: 30, label: '30 dias' },
  { key: 90, label: '90 dias' },
] as const
type PeriodKey = (typeof PERIODS)[number]['key']

const fmtDay = (iso: string) => `${iso.slice(8, 10)}/${iso.slice(5, 7)}`

/* ── número que sobe até o valor ── */
function useCountUp(target: number, ms = 900) {
  const [v, setV] = useState(0)
  const prev = useRef(0)
  useEffect(() => {
    const from = prev.current
    prev.current = target
    if (from === target) { setV(target); return }
    let raf = 0
    const t0 = performance.now()
    const tick = (t: number) => {
      const p = Math.min(1, (t - t0) / ms)
      const eased = 1 - Math.pow(1 - p, 3)
      setV(Math.round(from + (target - from) * eased))
      if (p < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, ms])
  return v
}

/* ────────── configuração ────────── */
function Setup({ kind }: { kind: 'no-admin-emails' | 'no-service-key' }) {
  const isEmails = kind === 'no-admin-emails'
  return (
    <main className="min-h-screen bg-[#0f0f1a] text-white flex items-center justify-center p-6">
      <div className="max-w-lg w-full rounded-3xl border border-white/10 bg-white/[0.04] backdrop-blur-2xl p-8">
        <div className="text-3xl mb-3">🔒</div>
        <h1 className="text-xl font-bold mb-3">Falta um passo pra liberar o painel</h1>
        <p className="text-white/60 text-sm mb-5">
          {isEmails
            ? 'A variável ADMIN_EMAILS ainda não foi configurada. Enquanto ela estiver vazia, ninguém acessa o painel — inclusive você.'
            : 'A variável SUPABASE_SERVICE_ROLE_KEY não está disponível no servidor. Ela é necessária para ler os dados de todos os usuários.'}
        </p>
        <div className="rounded-2xl bg-black/40 border border-white/10 p-4 text-sm">
          <div className="text-white/40 text-xs uppercase tracking-wider mb-2">Como resolver</div>
          <ol className="space-y-2 text-white/80 list-decimal list-inside">
            <li>Abra o projeto na Vercel</li>
            <li>Settings → Environment Variables</li>
            <li>
              Adicione{' '}
              <code className="px-1.5 py-0.5 rounded bg-white/10 text-[#f8b6c8]">
                {isEmails ? 'ADMIN_EMAILS' : 'SUPABASE_SERVICE_ROLE_KEY'}
              </code>
            </li>
            <li>{isEmails ? 'Valor: seu e-mail de login (vários separados por vírgula)' : 'Valor: a service_role key do Supabase'}</li>
            <li>Redeploy do projeto</li>
          </ol>
        </div>
        <Link href="/dashboard" className="mt-6 inline-block text-sm text-[#e879a0] hover:underline">
          ← Voltar ao dashboard
        </Link>
      </div>
    </main>
  )
}

/* ────────── blocos ────────── */
function Card({ children, className = '', delay = 0 }: { children: React.ReactNode; className?: string; delay?: number }) {
  return (
    <div
      className={`rounded-3xl border border-white/10 bg-white/[0.04] backdrop-blur-2xl p-5 relative overflow-hidden transition-transform duration-300 hover:-translate-y-0.5 ${className}`}
      style={{ animation: `fadeUp .5s ease ${delay}ms both` }}
    >
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-white/[0.07] to-transparent" />
      <div className="relative">{children}</div>
    </div>
  )
}

function Stat({
  label, value, hint, accent, delay = 0, money,
}: { label: string; value: number | null; hint?: string; accent?: string; delay?: number; money?: boolean }) {
  const animated = useCountUp(value ?? 0)
  const shown = value === null ? '—' : money ? BRL(animated) : animated.toLocaleString('pt-BR')
  return (
    <Card delay={delay}>
      <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold">{label}</div>
      <div className="text-3xl font-extrabold mt-1.5 tracking-tight tabular-nums" style={accent ? { color: accent } : undefined}>
        {shown}
      </div>
      {hint && <div className="text-xs text-white/40 mt-1">{hint}</div>}
    </Card>
  )
}

/* ── lista das últimas compras de Honk Coin ── */
function CoinPurchasesCard({ purchases }: { purchases: CoinPurchaseRow[] | null }) {
  return (
    <Card delay={420}>
      <div className="text-sm font-bold mb-4">Últimas compras de Honk Coins</div>
      {purchases === null && (
        <div className="text-sm text-white/40">
          Tabela <code className="text-xs px-1 py-0.5 rounded bg-white/10">coin_purchases</code> ainda não existe.
          Peça pro Claude te passar o SQL de criação e rode no SQL Editor do Supabase.
        </div>
      )}
      {purchases !== null && purchases.length === 0 && (
        <div className="text-sm text-white/40">Nenhuma compra registrada ainda.</div>
      )}
      {purchases !== null && purchases.length > 0 && (
        <div className="space-y-2">
          {purchases.map((p, i) => (
            <div key={i} className="flex items-center justify-between text-sm border-b border-white/5 last:border-0 pb-2 last:pb-0">
              <div className="min-w-0">
                <div className="font-medium truncate">{p.email || 'e-mail não registrado'}</div>
                <div className="text-xs text-white/40">
                  {new Date(p.created_at).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}
                </div>
              </div>
              <div className="text-right shrink-0 pl-3">
                <div className="font-bold tabular-nums">{p.coins} coins</div>
                {p.amount_cents !== null && <div className="text-xs text-[#4ade80] tabular-nums">{BRL(p.amount_cents)}</div>}
              </div>
            </div>
          ))}
        </div>
      )}
    </Card>
  )
}

const MONTH_LABEL = (m: string) =>
  new Date(m + '-01T12:00:00').toLocaleDateString('pt-BR', { month: 'short', year: '2-digit' })

/* ── faturamento acumulado de verdade, direto do Mercado Pago ──
   Diferente do MRR (que é projeção de quanto entra por mês), aqui é a soma de
   tudo que já foi aprovado desde o primeiro pagamento. */
function TotalReceivedCard({ mp }: { mp: MpSummary | null }) {
  if (!mp) {
    return (
      <Card delay={140}>
        <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold">Total recebido</div>
        <div className="text-sm text-white/40 mt-2">
          Não consegui falar com o Mercado Pago. Confira se a variável{' '}
          <code className="text-xs px-1 py-0.5 rounded bg-white/10">MP_ACCESS_TOKEN</code> está configurada na Vercel.
        </div>
      </Card>
    )
  }

  const since = mp.firstApprovedAt
    ? new Date(mp.firstApprovedAt).toLocaleDateString('pt-BR', { day: '2-digit', month: 'long', year: 'numeric' })
    : null
  const maxMonth = Math.max(1, ...mp.byMonth.map(m => m.netCents))

  return (
    <Card delay={140}>
      <div className="flex items-baseline justify-between flex-wrap gap-2">
        <div>
          <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold">Total recebido</div>
          <div className="text-4xl font-extrabold mt-1.5 tracking-tight tabular-nums text-[#4ade80]">
            {BRL(mp.netCents)}
          </div>
          <div className="text-xs text-white/40 mt-1.5">
            líquido, já sem a taxa do Mercado Pago · {mp.count} pagamento{mp.count === 1 ? '' : 's'} aprovado{mp.count === 1 ? '' : 's'}
            {since && ` desde ${since}`}
          </div>
        </div>
        <div className="text-right text-xs text-white/40 space-y-0.5">
          <div>bruto <span className="tabular-nums text-white/70">{BRL(mp.grossCents)}</span></div>
          <div>taxas <span className="tabular-nums text-[#fb923c]">-{BRL(mp.feeCents)}</span></div>
        </div>
      </div>

      {mp.truncated && (
        <div className="text-xs text-[#fbbf24] mt-3">
          Histórico grande demais pra paginação da API — esse total é parcial.
        </div>
      )}

      {mp.byMonth.length > 0 && (
        <div className="mt-5">
          <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold mb-3">Por mês</div>
          <div className="space-y-2">
            {mp.byMonth.map(m => (
              <div key={m.month} className="flex items-center gap-3">
                <div className="w-16 text-[13px] font-medium shrink-0 capitalize">{MONTH_LABEL(m.month)}</div>
                <div className="flex-1 h-2.5 rounded-full bg-white/[0.07] overflow-hidden">
                  <div
                    className="h-full rounded-full bg-[#4ade80] transition-all duration-700"
                    style={{ width: `${(m.netCents / maxMonth) * 100}%` }}
                  />
                </div>
                <div className="text-xs font-bold w-32 text-right tabular-nums">
                  {BRL(m.netCents)} <span className="text-white/30 font-normal">({m.count})</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </Card>
  )
}

/* ── pagamentos aprovados no Mercado Pago ── */
const PAYMENTS_PREVIEW = 20

function MpPaymentsCard({ mp }: { mp: MpSummary | null }) {
  const [showAll, setShowAll] = useState(false)
  if (!mp) return null

  const total = mp.list.length
  const shown = showAll ? mp.list : mp.list.slice(0, PAYMENTS_PREVIEW)

  return (
    <Card delay={500}>
      <div className="flex items-baseline justify-between gap-3 mb-4">
        <div className="text-sm font-bold">
          {showAll ? 'Todos os pagamentos' : 'Últimos pagamentos recebidos'}
        </div>
        <div className="text-xs text-white/40 tabular-nums">{total} no total</div>
      </div>
      {total === 0 ? (
        <div className="text-sm text-white/40">Nenhum pagamento aprovado ainda.</div>
      ) : (
        <div className={`space-y-2 ${showAll ? 'max-h-[60vh] overflow-y-auto pr-1' : ''}`}>
          {shown.map(p => (
            <div key={p.id} className="flex items-center justify-between text-sm border-b border-white/5 last:border-0 pb-2 last:pb-0">
              <div className="min-w-0">
                <div className="font-medium truncate">{p.email || 'e-mail não informado'}</div>
                <div className="text-xs text-white/40 truncate">
                  {new Date(p.approvedAt).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}
                  {p.description && ` · ${p.description}`}
                </div>
              </div>
              <div className="text-right shrink-0 pl-3">
                <div className="font-bold tabular-nums text-[#4ade80]">{BRL(p.netCents)}</div>
                {p.feeCents > 0 && <div className="text-xs text-white/30 tabular-nums">bruto {BRL(p.grossCents)}</div>}
              </div>
            </div>
          ))}
        </div>
      )}
      {total > PAYMENTS_PREVIEW && (
        <button
          onClick={() => setShowAll(v => !v)}
          className="mt-4 w-full rounded-xl border border-white/10 bg-white/[0.04] py-2.5 text-sm font-semibold text-[#f8b6c8] transition-colors hover:bg-white/[0.08]"
        >
          {showAll ? 'Mostrar menos' : `Ver todas as ${total} transações`}
        </button>
      )}
    </Card>
  )
}

/* ── receita fora do sistema (freela/bico) ── */
function ExtraRevenueCard({ rows }: { rows: ExtraRevenueRow[] | null }) {
  return (
    <Card delay={460}>
      <div className="text-sm font-bold mb-4">Freelas e bicos</div>
      {rows === null && (
        <div className="text-sm text-white/40">
          Tabela <code className="text-xs px-1 py-0.5 rounded bg-white/10">extra_revenue</code> ainda não existe.
          Rode o SQL de criação no Supabase pra começar a registrar.
        </div>
      )}
      {rows !== null && rows.length === 0 && (
        <div className="text-sm text-white/40">Nenhum freela registrado ainda.</div>
      )}
      {rows !== null && rows.length > 0 && (
        <div className="space-y-2">
          {rows.map((r, i) => (
            <div key={i} className="flex items-center justify-between text-sm border-b border-white/5 last:border-0 pb-2 last:pb-0">
              <div className="min-w-0">
                <div className="font-medium truncate">{r.description}</div>
                <div className="text-xs text-white/40">
                  {new Date(r.received_at + 'T12:00:00').toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' })}
                </div>
              </div>
              <div className="font-bold tabular-nums text-[#a78bfa] shrink-0 pl-3">{BRL(r.amount_cents)}</div>
            </div>
          ))}
        </div>
      )}
    </Card>
  )
}

/* ── gráfico de área com hover ── */
function AreaChart({ data, color, id }: { data: DayPoint[]; color: string; id: string }) {
  const [hover, setHover] = useState<number | null>(null)
  const w = 720
  const h = 180
  const pad = 10
  const max = Math.max(1, ...data.map(d => d.count))
  const step = data.length > 1 ? (w - pad * 2) / (data.length - 1) : 0
  const y = (v: number) => h - pad - (v / max) * (h - pad * 2)
  const pts = data.map((d, i) => [pad + i * step, y(d.count)] as const)
  const line = pts.map(([x, yy], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${yy.toFixed(1)}`).join(' ')
  const area = `${line} L${pad + (data.length - 1) * step},${h - pad} L${pad},${h - pad} Z`
  const total = data.reduce((s, d) => s + d.count, 0)
  const active = hover !== null ? data[hover] : null

  function pick(clientX: number, el: SVGSVGElement) {
    const r = el.getBoundingClientRect()
    const rel = ((clientX - r.left) / r.width) * w
    const i = Math.round((rel - pad) / (step || 1))
    setHover(Math.max(0, Math.min(data.length - 1, i)))
  }

  return (
    <div className="relative select-none">
      {active && (
        <div
          className="absolute -top-1 z-10 px-2.5 py-1.5 rounded-xl bg-black/85 border border-white/15 text-xs whitespace-nowrap pointer-events-none backdrop-blur"
          style={{
            left: `${((pts[hover!][0]) / w) * 100}%`,
            transform: `translateX(${hover! < data.length / 2 ? '-10%' : '-90%'})`,
          }}
        >
          <span className="text-white/50">{fmtDay(active.date)}</span>{' '}
          <span className="font-bold" style={{ color }}>{active.count}</span>
        </div>
      )}
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="w-full cursor-crosshair"
        style={{ height: 180 }}
        preserveAspectRatio="none"
        onMouseMove={e => pick(e.clientX, e.currentTarget)}
        onMouseLeave={() => setHover(null)}
        onTouchStart={e => pick(e.touches[0].clientX, e.currentTarget)}
        onTouchMove={e => pick(e.touches[0].clientX, e.currentTarget)}
        onTouchEnd={() => setHover(null)}
      >
        <defs>
          <linearGradient id={`g-${id}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.4" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map(f => (
          <line key={f} x1={pad} x2={w - pad} y1={h * f} y2={h * f} stroke="rgba(255,255,255,.06)" strokeWidth="1" />
        ))}
        {total > 0 && <path d={area} fill={`url(#g-${id})`} />}
        <path
          d={line}
          fill="none"
          stroke={color}
          strokeWidth="2.5"
          strokeLinejoin="round"
          strokeLinecap="round"
          style={{ transition: 'd .4s ease' }}
        />
        {hover !== null && (
          <>
            <line x1={pts[hover][0]} x2={pts[hover][0]} y1={pad} y2={h - pad} stroke="rgba(255,255,255,.25)" strokeWidth="1" />
            <circle cx={pts[hover][0]} cy={pts[hover][1]} r="5.5" fill={color} stroke="#0f0f1a" strokeWidth="2.5" />
          </>
        )}
        {hover === null && pts.length > 0 && (
          <circle cx={pts[pts.length - 1][0]} cy={pts[pts.length - 1][1]} r="4" fill={color} />
        )}
      </svg>
      <div className="flex justify-between text-[10px] text-white/30 mt-1 px-1">
        <span>{data[0] ? fmtDay(data[0].date) : ''}</span>
        <span>hoje</span>
      </div>
    </div>
  )
}

/* ── lista com barras clicáveis ── */
function RankList({ items, empty }: { items: Ranked[] | null; empty: string }) {
  const [sel, setSel] = useState<string | null>(null)
  if (!items || items.length === 0) {
    return <div className="text-sm text-white/30 py-6 text-center">{empty}</div>
  }
  const max = Math.max(...items.map(i => i.count))
  const sum = items.reduce((s, i) => s + i.count, 0)
  return (
    <div className="space-y-2.5">
      {items.map((i, idx) => {
        const on = sel === i.label
        return (
          <button
            key={i.label}
            onClick={() => setSel(on ? null : i.label)}
            className="w-full flex items-center gap-3 text-left group"
            style={{ animation: `fadeUp .4s ease ${idx * 45}ms both` }}
          >
            <div className="flex-1 min-w-0">
              <div className="flex items-baseline gap-2">
                <span className={`text-[13px] font-medium truncate transition-colors ${on ? 'text-[#f8b6c8]' : 'group-hover:text-[#f8b6c8]'}`}>
                  {i.label}
                </span>
                {on && <span className="text-[10px] text-white/40 shrink-0">{((i.count / sum) * 100).toFixed(1)}% do total</span>}
              </div>
              <div className="h-1.5 rounded-full bg-white/[0.07] mt-1.5 overflow-hidden">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-[#f8b6c8] to-[#c2185b] transition-all duration-700"
                  style={{ width: `${(i.count / max) * 100}%`, opacity: sel && !on ? 0.35 : 1 }}
                />
              </div>
            </div>
            <div className="text-xs font-bold text-white/50 w-12 text-right tabular-nums">{num(i.count)}</div>
          </button>
        )
      })}
    </div>
  )
}

/* ────────── painel ────────── */
export function AdminClient({
  stats, email, setup,
}: {
  stats?: AdminStats
  email?: string
  setup?: 'no-admin-emails' | 'no-service-key'
}) {
  const [tab, setTab] = useState<'geral' | 'buscas'>('geral')
  const [period, setPeriod] = useState<PeriodKey>(30)
  const router = useRouter()
  const [pending, startTransition] = useTransition()

  const slice = (s: DayPoint[] | null | undefined) => (s ? s.slice(-period) : [])
  const signups = useMemo(() => slice(stats?.users.signupsByDay), [stats, period])
  const searchSeries = useMemo(() => slice(stats?.searches.byDay), [stats, period])
  const sum = (s: DayPoint[]) => s.reduce((a, b) => a + b.count, 0)

  if (setup) return <Setup kind={setup} />
  if (!stats) return null

  const { users, plans, coins, extra, searches, payments, warnings, generatedAt } = stats
  const conv = users.total > 0 ? (plans.paying / users.total) * 100 : 0
  const periodLabel = PERIODS.find(p => p.key === period)!.label

  return (
    <main className="min-h-screen bg-[#0f0f1a] text-white">
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-32 -left-24 w-[420px] h-[420px] rounded-full blur-[110px] opacity-25 bg-[#e879a0]" />
        <div className="absolute -bottom-32 -right-24 w-[380px] h-[380px] rounded-full blur-[110px] opacity-20 bg-[#c2185b]" />
      </div>

      <div className={`relative max-w-5xl mx-auto px-4 py-8 transition-opacity ${pending ? 'opacity-50' : ''}`}>
        <header className="flex items-start justify-between gap-4 mb-6">
          <div>
            <h1 className="text-3xl font-extrabold tracking-tight">
              Como a <span className="text-gradient">Honk</span> tá indo
            </h1>
            <p className="text-white/40 text-sm mt-1">
              {email} · atualizado {new Date(generatedAt).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}
            </p>
          </div>
          <div className="flex gap-2 shrink-0">
            <button
              onClick={() => startTransition(() => router.refresh())}
              disabled={pending}
              className="text-sm px-3 py-2 rounded-xl border border-white/10 bg-white/[0.04] hover:bg-white/10 transition disabled:opacity-50"
              title="Atualizar dados"
            >
              <span className={`inline-block ${pending ? 'animate-spin' : ''}`}>↻</span>
            </button>
            <Link href="/dashboard" className="text-sm px-4 py-2 rounded-xl border border-white/10 bg-white/[0.04] hover:bg-white/10 transition">
              Dashboard
            </Link>
          </div>
        </header>

        {warnings.length > 0 && (
          <div className="mb-6 rounded-2xl border border-amber-400/25 bg-amber-400/[0.07] p-4">
            <div className="text-amber-300 text-xs font-bold uppercase tracking-wider mb-1.5">Avisos</div>
            {warnings.map(w => <div key={w} className="text-sm text-amber-100/80">• {w}</div>)}
          </div>
        )}

        {/* abas + período */}
        <div className="flex flex-wrap items-center justify-between gap-3 mb-6">
          <div className="flex gap-2">
            {(['geral', 'buscas'] as const).map(t => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={`px-4 py-2 rounded-xl text-sm font-semibold transition border ${
                  tab === t
                    ? 'bg-[#e879a0]/15 border-[#e879a0]/40 text-[#f8b6c8]'
                    : 'bg-white/[0.03] border-white/10 text-white/50 hover:bg-white/[0.07]'
                }`}
              >
                {t === 'geral' ? 'Visão geral' : 'Buscas'}
              </button>
            ))}
          </div>
          <div className="flex gap-1 p-1 rounded-xl bg-white/[0.03] border border-white/10">
            {PERIODS.map(p => (
              <button
                key={p.key}
                onClick={() => setPeriod(p.key)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition ${
                  period === p.key ? 'bg-[#e879a0]/20 text-[#f8b6c8]' : 'text-white/40 hover:text-white/70'
                }`}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>

        {tab === 'geral' && (
          <div className="space-y-4">
            {/* Dois blocos de dinheiro, mesmo peso visual:
                MRR = só o que se repete todo mês. Saldo = tudo que entrou (assinatura + coins + freela). */}
            <div className="grid md:grid-cols-2 gap-4">
              <Card delay={0}>
                <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold">MRR</div>
                <div className="text-4xl font-extrabold mt-1.5 tracking-tight tabular-nums text-[#4ade80]">
                  {BRL(plans.mrrCents)}
                </div>
                <div className="text-xs text-white/40 mt-1.5">
                  receita que se repete todo mês · {plans.paying} assinante{plans.paying === 1 ? '' : 's'}
                  {plans.courtesy !== null && plans.courtesy > 0 && ` · ${plans.courtesy} cortesia${plans.courtesy === 1 ? '' : 's'}`}
                </div>
              </Card>

              <Card delay={80}>
                <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold">Saldo atual</div>
                <div className="text-4xl font-extrabold mt-1.5 tracking-tight tabular-nums">
                  {BRL(plans.mrrCents + (coins.revenueCentsTotal || 0) + (extra.totalCents || 0))}
                </div>
                <div className="text-xs text-white/40 mt-1.5 space-y-0.5">
                  <div>assinaturas {BRL(plans.mrrCents)}</div>
                  {coins.revenueCentsTotal !== null && coins.revenueCentsTotal > 0 && <div>coins {BRL(coins.revenueCentsTotal)}</div>}
                  {extra.totalCents !== null && extra.totalCents > 0 && <div>freela {BRL(extra.totalCents)}</div>}
                </div>
              </Card>
            </div>

            <TotalReceivedCard mp={payments} />

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Stat label="Usuários" value={users.total} hint={`+${sum(signups)} em ${periodLabel}`} delay={0} />
              <Stat label="Pagantes" value={plans.paying} accent="#f8b6c8" hint={`${conv.toFixed(1)}% de conversão`} delay={60} />
              <Stat
                label="Freela / bico"
                value={extra.totalCents}
                money
                accent="#a78bfa"
                hint="receita fora do sistema"
                delay={120}
              />
              <Stat
                label="Vencendo em 7 dias"
                value={plans.expiringIn7}
                accent={plans.expiringIn7 > 0 ? '#fbbf24' : undefined}
                hint="planos a renovar"
                delay={180}
              />
            </div>

            <Card delay={240}>
              <div className="flex items-baseline justify-between mb-3">
                <div className="text-sm font-bold">Cadastros — {periodLabel}</div>
                <div className="text-sm text-white/40 tabular-nums">{num(sum(signups))} no período</div>
              </div>
              <AreaChart data={signups} color="#e879a0" id="signups" />
            </Card>

            <div className="grid md:grid-cols-2 gap-4">
              <Card delay={300}>
                <div className="text-sm font-bold mb-4">Distribuição por plano</div>
                <div className="space-y-3">
                  {(Object.keys(PLANS) as Plan[]).map(p => {
                    const n = plans.counts[p]
                    const pct = users.total > 0 ? (n / users.total) * 100 : 0
                    return (
                      <div key={p} className="flex items-center gap-3">
                        <div className="w-20 text-[13px] font-medium shrink-0">{PLANS[p].name}</div>
                        <div className="flex-1 h-2.5 rounded-full bg-white/[0.07] overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all duration-700"
                            style={{ width: `${pct}%`, background: PLAN_COLOR[p] }}
                          />
                        </div>
                        <div className="text-xs font-bold w-16 text-right tabular-nums">
                          {n} <span className="text-white/30 font-normal">({pct.toFixed(0)}%)</span>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </Card>

              <Card delay={360}>
                <div className="text-sm font-bold mb-4">Outros números</div>
                <div className="space-y-3 text-sm">
                  <div className="flex justify-between">
                    <span className="text-white/50">Moedas em circulação</span>
                    <span className="font-bold tabular-nums">{num(coins.inCirculation)}</span>
                  </div>
                  {coins.revenueCentsTotal !== null && (
                    <div className="flex justify-between">
                      <span className="text-white/50">Faturado em Honk Coins</span>
                      <span className="font-bold tabular-nums text-[#4ade80]">{BRL(coins.revenueCentsTotal)}</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-white/50">Membros de equipe</span>
                    <span className="font-bold tabular-nums">{num(plans.teamMembers)}</span>
                  </div>
                  {plans.activeSubscriptions !== null && (
                    <div className="flex justify-between">
                      <span className="text-white/50">Assinaturas <code className="text-xs">active</code></span>
                      <span className="font-bold tabular-nums">{num(plans.activeSubscriptions)}</span>
                    </div>
                  )}
                  {plans.courtesy !== null && (
                    <div className="flex justify-between">
                      <span className="text-white/50" title="Perfis com plano pago sem assinatura por trás: cortesias, sua própria conta e planos vencidos ainda não rebaixados">
                        Cortesias / não pagantes
                      </span>
                      <span className="font-bold tabular-nums text-[#fbbf24]">{num(plans.courtesy)}</span>
                    </div>
                  )}
                  <div className="flex justify-between">
                    <span className="text-white/50">Buscas consumidas hoje</span>
                    <span className="font-bold tabular-nums">{num(searches.today)}</span>
                  </div>
                </div>
              </Card>
            </div>

            <div className="grid md:grid-cols-2 gap-4">
              <CoinPurchasesCard purchases={coins.recent} />
              <ExtraRevenueCard rows={extra.recent} />
            </div>

            <MpPaymentsCard mp={payments} />
          </div>
        )}

        {tab === 'buscas' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Stat label="Buscas registradas" value={searches.total} delay={0} />
              <Stat label={`Em ${periodLabel}`} value={searches.byDay ? sum(searchSeries) : null} accent="#f8b6c8" delay={60} />
              <Stat
                label="Média por dia"
                value={searches.byDay ? Math.round(sum(searchSeries) / period) : null}
                delay={120}
              />
              <Stat label="Consumidas hoje" value={searches.today} hint="contador dos perfis" delay={180} />
            </div>

            {searches.byDay ? (
              <Card delay={240}>
                <div className="flex items-baseline justify-between mb-3">
                  <div className="text-sm font-bold">Buscas — {periodLabel}</div>
                  <div className="text-sm text-white/40 tabular-nums">pico de {num(Math.max(...searchSeries.map(d => d.count), 0))} num dia</div>
                </div>
                <AreaChart data={searchSeries} color="#f8b6c8" id="searches" />
              </Card>
            ) : (
              <Card delay={240}>
                <div className="text-sm text-white/30 py-6 text-center">
                  Gráfico indisponível — search_logs sem coluna de data.
                </div>
              </Card>
            )}

            <div className="grid md:grid-cols-2 gap-4">
              <Card delay={300}>
                <div className="text-sm font-bold mb-1">Segmentos mais buscados</div>
                <div className="text-[11px] text-white/30 mb-4">Toque numa barra para ver a fatia</div>
                <RankList items={searches.topSegments} empty="Nenhuma busca registrada ainda" />
              </Card>
              <Card delay={360}>
                <div className="text-sm font-bold mb-1">Cidades mais buscadas</div>
                <div className="text-[11px] text-white/30 mb-4">Toque numa barra para ver a fatia</div>
                <RankList items={searches.topCities} empty="Nenhuma busca registrada ainda" />
              </Card>
            </div>
          </div>
        )}

        <p className="text-[11px] text-white/25 mt-8 leading-relaxed">
          MRR é uma estimativa: o webhook do Mercado Pago não guarda o valor nem a data de cada pagamento,
          então o cálculo usa a quantidade de donos de plano pago vezes o preço de tabela — membros de equipe não entram na conta.
        </p>
      </div>
    </main>
  )
}
