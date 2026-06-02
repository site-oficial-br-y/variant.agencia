'use client'
import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { PLANS, formatPrice, getRemainingSearches } from '@/lib/plans'
import type { Plan } from '@/lib/plans'
import type { User } from '@supabase/supabase-js'
import { QuizOverlay } from '@/components/QuizOverlay'
import { SearchResults } from '@/components/SearchResults'

interface Profile { id: string; email: string; plan: Plan; searches_today: number; searches_reset_at: string; team_owner_id?: string | null }
interface TeamMember { id: string; owner_id: string; member_email: string; status: string }
interface QuizData { service: string; city: string; segment: string; allBrazil: boolean }

export function DashboardClient({ user, profile, teamMembers }: { user: User; profile: Profile | null; teamMembers: TeamMember[] }) {
  const [quizOpen, setQuizOpen] = useState(false)
  const [searchParams, setSearchParams] = useState<QuizData | null>(null)
  const [limitMsg, setLimitMsg] = useState(false)
  const [loggingOut, setLoggingOut] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  const plan = profile?.plan ?? 'free'
  const planConfig = PLANS[plan]
  const resetAt = profile ? new Date(profile.searches_reset_at) : new Date()
  const todaySearches = new Date() > resetAt ? 0 : (profile?.searches_today ?? 0)
  const remaining = getRemainingSearches(plan, todaySearches)

  async function handleLogout() {
    setLoggingOut(true)
    await supabase.auth.signOut()
    router.push('/')
  }

  function handleSearch(data: QuizData) {
    setQuizOpen(false)
    setSearchParams(data)
    setLimitMsg(false)
    setTimeout(() => {
      const el = document.getElementById('dash-results')
      if (el) el.scrollIntoView({ behavior: 'smooth' })
    }, 200)
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', color: '#fff', fontFamily: 'Inter, -apple-system, sans-serif' }}>

      {/* QuizOverlay - fora do nav para não ter conflito de z-index */}
      <QuizOverlay open={quizOpen} onClose={() => setQuizOpen(false)} onSearch={handleSearch} />

      {/* Nav */}
      <nav style={{ padding: '14px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(15,15,26,0.95)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(248,182,200,0.15)', position: 'sticky', top: 0, zIndex: 50 }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="https://site-oficial-br-y.github.io/Honkponk/logo.png" alt="Honk Ponk" width={30} height={30} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.1rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 8, padding: '5px 12px', fontSize: '.78rem', fontWeight: 700, color: '#f8b6c8' }}>
            {planConfig.name}
          </span>
          <button
            onClick={handleLogout}
            disabled={loggingOut}
            style={{ background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, padding: '7px 14px', fontSize: '.8rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}
          >
            {loggingOut ? 'Saindo...' : 'Sair'}
          </button>
        </div>
      </nav>

      <div style={{ maxWidth: 960, margin: '0 auto', padding: '32px 20px' }}>

        {/* Saudação + botão nova busca */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 14, marginBottom: 28 }}>
          <div>
            <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4 }}>Olá, {user.email?.split('@')[0]} 👋</h1>
            <p style={{ color: 'rgba(255,255,255,.4)', fontSize: '.85rem' }}>Pronto para encontrar novos clientes?</p>
          </div>
          <button
            onClick={() => setQuizOpen(true)}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '13px 22px', fontSize: '.95rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 6px 24px rgba(232,121,160,.35)' }}
          >
            🔍 Nova busca
          </button>
        </div>

        {/* Cards de info */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 14, marginBottom: 28 }}>
          <div style={{ background: 'rgba(232,121,160,.1)', border: '1px solid rgba(232,121,160,.25)', borderRadius: 14, padding: '18px 20px' }}>
            <div style={{ fontSize: '.68rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase' as const, letterSpacing: 1, marginBottom: 6 }}>Plano</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 900, marginBottom: 2 }}>{planConfig.name}</div>
            <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)' }}>{planConfig.price === 0 ? 'Grátis' : `${formatPrice(planConfig.price)}/mês`}</div>
          </div>
          <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.15)', borderRadius: 14, padding: '18px 20px' }}>
            <div style={{ fontSize: '.68rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase' as const, letterSpacing: 1, marginBottom: 6 }}>Buscas hoje</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 900, marginBottom: 2 }}>{remaining === null ? '∞' : remaining}</div>
            <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)' }}>{remaining === null ? 'Ilimitadas' : `de ${planConfig.searchesPerDay} disponíveis`}</div>
          </div>
          {plan !== 'enterprise' && (
            <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.15)', borderRadius: 14, padding: '18px 20px', display: 'flex', flexDirection: 'column' as const, gap: 10 }}>
              <div style={{ fontSize: '.68rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase' as const, letterSpacing: 1 }}>Upgrade</div>
              <div style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.5)', flex: 1 }}>Mais buscas, Excel e mais recursos.</div>
              <Link href="/#precos" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 8, padding: '8px 14px', fontSize: '.8rem', fontWeight: 700, textDecoration: 'none', textAlign: 'center' as const }}>Ver planos →</Link>
            </div>
          )}
        </div>

        {/* Área de resultados / estado vazio */}
        {!searchParams ? (
          <div style={{ background: 'rgba(255,255,255,.03)', border: '1px dashed rgba(248,182,200,.2)', borderRadius: 18, padding: '56px 24px', textAlign: 'center' as const }}>
            <div style={{ fontSize: '2.8rem', marginBottom: 14 }}>🔍</div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 800, marginBottom: 8 }}>Nenhuma busca ainda</h2>
            <p style={{ color: 'rgba(255,255,255,.4)', marginBottom: 24, fontSize: '.88rem' }}>Clique em "Nova busca" para encontrar seus primeiros leads.</p>
            <button
              onClick={() => setQuizOpen(true)}
              style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 30px', fontSize: '.95rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.3)' }}
            >
              🔍 Começar busca
            </button>
          </div>
        ) : (
          <div id="dash-results">
            {limitMsg && (
              <div style={{ background: 'rgba(251,146,60,.1)', border: '1px solid rgba(251,146,60,.25)', borderRadius: 12, padding: '14px 18px', marginBottom: 18, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' as const }}>
                <p style={{ color: '#fb923c', fontSize: '.86rem', fontWeight: 600 }}>⚡ Limite de buscas atingido hoje.</p>
                <Link href="/#precos" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 8, padding: '8px 16px', fontSize: '.8rem', fontWeight: 700, textDecoration: 'none' }}>Fazer upgrade</Link>
              </div>
            )}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18, flexWrap: 'wrap' as const, gap: 10 }}>
              <div>
                <h2 style={{ fontSize: '1.05rem', fontWeight: 800, marginBottom: 2 }}>Resultados da busca</h2>
                <p style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)' }}>
                  {searchParams.allBrazil ? 'Todo o Brasil' : searchParams.city} · {searchParams.segment}
                </p>
              </div>
              <button
                onClick={() => setQuizOpen(true)}
                style={{ background: 'rgba(255,255,255,.07)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: '9px 16px', fontSize: '.8rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}
              >
                ↺ Nova busca
              </button>
            </div>
            <SearchResults params={searchParams} userId={user.id} onLimitReached={() => setLimitMsg(true)} />
          </div>
        )}
      </div>
    </div>
  )
}
