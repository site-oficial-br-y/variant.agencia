'use client'

import { useState } from 'react'
import Link from 'next/link'
import { PLANS, type Plan } from '@/lib/plans'
import type { AdminStats, DayPoint, Ranked } from './page'

const BRL = (cents: number) =>
  (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 })

/** Número formatado em pt-BR, ou travessão quando o dado não existe. */
const num = (n: number | null | undefined) => (n === null || n === undefined ? '—' : n.toLocaleString('pt-BR'))

const PLAN_COLOR: Record<Plan, string> = {
  free: '#6b7280',
  freelancer: '#f8b6c8',
  agency: '#e879a0',
  enterprise: '#c2185b',
}

/* ────────── tela de configuração ────────── */
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
            <li>
              {isEmails
                ? 'Valor: seu e-mail de login (pode separar vários por vírgula)'
                : 'Valor: a service_role key do Supabase (Settings → API)'}
            </li>
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

/* ────────── blocos visuais ────────── */
function Card({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <div
      className={`rounded-3xl border border-white/10 bg-white/[0.04] backdrop-blur-2xl p-5 relative overflow-hidden ${className}`}
    >
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-white/[0.07] to-transparent" />
      <div className="relative">{children}</div>
    </div>
  )
}

function Stat({
  label, value, hint, accent,
}: { label: string; value: string; hint?: string; accent?: string }) {
  return (
    <Card>
      <div className="text-[11px] uppercase tracking-wider text-white/40 font-semibold">{label}</div>
      <div className="text-3xl font-extrabold mt-1.5 tracking-tight" style={accent ? { color: accent } : undefined}>
        {value}
      </div>
      {hint && <div className="text-xs text-white/40 mt-1">{hint}</div>}
    </Card>
  )
}

/** Gráfico de área em SVG puro — sem biblioteca externa. */
function AreaChart({ data, color, id }: { data: DayPoint[]; color: string; id: string }) {
  const w = 720
  const h = 170
  const pad = 8
  const max = Math.max(1, ...data.map(d => d.count))
  const step = data.length > 1 ? (w - pad * 2) / (data.length - 1) : 0
  const y = (v: number) => h - pad - (v / max) * (h - pad * 2)
  const pts = data.map((d, i) => [pad + i * step, y(d.count)] as const)
  const line = pts.map(([x, yy], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${yy.toFixed(1)}`).join(' ')
  const area = `${line} L${pad + (data.length - 1) * step},${h - pad} L${pad},${h - pad} Z`
  const total = data.reduce((s, d) => s + d.count, 0)

  return (
    <div>
      <svg viewBox={`0 0 ${w} ${h}`} className="w-full" style={{ height: 170 }} preserveAspectRatio="none">
        <defs>
          <linearGradient id={`g-${id}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.38" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map(f => (
          <line key={f} x1={pad} x2={w - pad} y1={h * f} y2={h * f} stroke="rgba(255,255,255,.06)" strokeWidth="1" />
        ))}
        {total > 0 && <path d={area} fill={`url(#g-${id})`} />}
        <path d={line} fill="none" stroke={color} strokeWidth="2.5" strokeLinejoin="round" strokeLinecap="round" />
        {pts.length > 0 && (
          <circle cx={pts[pts.length - 1][0]} cy={pts[pts.length - 1][1]} r="4" fill={color} />
        )}
      </svg>
      <div className="flex justify-between text-[10px] text-white/30 mt-1 px-1">
        <span>{data[0]?.date.slice(8)}/{data[0]?.date.slice(5, 7)}</span>
        <span>hoje</span>
      </div>
    </div>
  )
}

function RankList({ items, empty }: { items: Ranked[] | null; empty: string }) {
  if (!items || items.length === 0) {
    return <div className="text-sm text-white/30 py-6 text-center">{empty}</div>
  }
  const max = Math.max(...items.map(i => i.count))
  return (
    <div className="space-y-2.5">
      {items.map(i => (
        <div key={i.label} className="flex items-center gap-3">
          <div className="flex-1 min-w-0">
            <div className="text-[13px] font-medium truncate">{i.label}</div>
            <div className="h-1.5 rounded-full bg-white/[0.07] mt-1.5 overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#f8b6c8] to-[#c2185b]"
                style={{ width: `${(i.count / max) * 100}%` }}
              />
            </div>
          </div>
          <div className="text-xs font-bold text-white/50 w-10 text-right">{i.count}</div>
        </div>
      ))}
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

  if (setup) return <Setup kind={setup} />
  if (!stats) return null

  const { users, plans, coins, searches, warnings } = stats
  const conv = users.total > 0 ? (plans.paying / users.total) * 100 : 0

  return (
    <main className="min-h-screen bg-[#0f0f1a] text-white">
      {/* luzes de fundo */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-32 -left-24 w-[420px] h-[420px] rounded-full blur-[110px] opacity-25 bg-[#e879a0]" />
        <div className="absolute -bottom-32 -right-24 w-[380px] h-[380px] rounded-full blur-[110px] opacity-20 bg-[#c2185b]" />
      </div>

      <div className="relative max-w-5xl mx-auto px-4 py-8">
        {/* topo */}
        <header className="flex items-start justify-between gap-4 mb-7">
          <div>
            <h1 className="text-3xl font-extrabold tracking-tight">
              Como a <span className="text-gradient">Honk</span> tá indo
            </h1>
            <p className="text-white/40 text-sm mt-1">{email}</p>
          </div>
          <Link
            href="/dashboard"
            className="shrink-0 text-sm px-4 py-2 rounded-xl border border-white/10 bg-white/[0.04] hover:bg-white/10 transition"
          >
            Dashboard
          </Link>
        </header>

        {warnings.length > 0 && (
          <div className="mb-6 rounded-2xl border border-amber-400/25 bg-amber-400/[0.07] p-4">
            <div className="text-amber-300 text-xs font-bold uppercase tracking-wider mb-1.5">Avisos</div>
            {warnings.map(w => (
              <div key={w} className="text-sm text-amber-100/80">• {w}</div>
            ))}
          </div>
        )}

        {/* abas */}
        <div className="flex gap-2 mb-6">
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

        {tab === 'geral' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Stat label="Usuários" value={num(users.total)} hint={`+${users.last7} nos últimos 7 dias`} />
              <Stat label="Pagantes" value={num(plans.paying)} accent="#f8b6c8" hint={`${conv.toFixed(1)}% de conversão`} />
              <Stat label="MRR estimado" value={BRL(plans.mrrCents)} accent="#4ade80" hint="planos ativos × preço" />
              <Stat
                label="Moedas em circulação"
                value={num(coins.inCirculation)}
                hint="saldo somado dos usuários"
              />
            </div>

            <Card>
              <div className="flex items-baseline justify-between mb-3">
                <div className="text-sm font-bold">Cadastros — últimos 30 dias</div>
                <div className="text-sm text-white/40">{users.last30} no total</div>
              </div>
              <AreaChart data={users.signupsByDay} color="#e879a0" id="signups" />
            </Card>

            <Card>
              <div className="text-sm font-bold mb-4">Distribuição por plano</div>
              <div className="space-y-3">
                {(Object.keys(PLANS) as Plan[]).map(p => {
                  const n = plans.counts[p]
                  const pct = users.total > 0 ? (n / users.total) * 100 : 0
                  return (
                    <div key={p} className="flex items-center gap-3">
                      <div className="w-24 text-[13px] font-medium shrink-0">{PLANS[p].name}</div>
                      <div className="flex-1 h-2.5 rounded-full bg-white/[0.07] overflow-hidden">
                        <div
                          className="h-full rounded-full transition-all"
                          style={{ width: `${pct}%`, background: PLAN_COLOR[p] }}
                        />
                      </div>
                      <div className="text-xs font-bold w-16 text-right">
                        {n} <span className="text-white/30 font-normal">({pct.toFixed(0)}%)</span>
                      </div>
                    </div>
                  )
                })}
              </div>
              {plans.activeSubscriptions !== null && (
                <div className="mt-4 pt-4 border-t border-white/[0.07] text-sm text-white/50">
                  Assinaturas com status <span className="text-white/80 font-semibold">active</span>:{' '}
                  <span className="text-white font-bold">{plans.activeSubscriptions}</span>
                </div>
              )}
            </Card>
          </div>
        )}

        {tab === 'buscas' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Stat label="Buscas registradas" value={num(searches.total)} />
              <Stat label="Últimos 7 dias" value={num(searches.last7)} accent="#f8b6c8" />
              <Stat label="Últimos 30 dias" value={num(searches.last30)} />
              <Stat label="Consumidas hoje" value={num(searches.today)} hint="contador dos perfis" />
            </div>

            {searches.byDay && (
              <Card>
                <div className="text-sm font-bold mb-3">Buscas — últimos 30 dias</div>
                <AreaChart data={searches.byDay} color="#f8b6c8" id="searches" />
              </Card>
            )}

            <div className="grid md:grid-cols-2 gap-4">
              <Card>
                <div className="text-sm font-bold mb-4">Segmentos mais buscados</div>
                <RankList items={searches.topSegments} empty="Nenhuma busca registrada ainda" />
              </Card>
              <Card>
                <div className="text-sm font-bold mb-4">Cidades mais buscadas</div>
                <RankList items={searches.topCities} empty="Nenhuma busca registrada ainda" />
              </Card>
            </div>
          </div>
        )}

        <p className="text-[11px] text-white/25 mt-8 leading-relaxed">
          MRR é uma estimativa: o webhook do Mercado Pago não guarda o valor nem a data de cada pagamento,
          então o cálculo usa a quantidade de usuários em cada plano vezes o preço de tabela.
        </p>
      </div>
    </main>
  )
}
