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
  const [hoveredCard, setHoveredCard] = useState<string | null>(null)
  const router = useRouter()
  const supabase = createClient()

  const plan = profile?.plan ?? 'free'
  const planConfig = PLANS[plan]
  const resetAt = profile ? new Date(profile.searches_reset_at) : new Date()
  const todaySearches = new Date() > resetAt ? 0 : (profile?.searches_today ?? 0)
  const initialRemaining = getRemainingSearches(plan, todaySearches)
  const [remaining, setRemaining] = useState(initialRemaining)

  async function handleLogout() {
    setLoggingOut(true)
    await supabase.auth.signOut()
    router.push('/')
  }

  function handleSearch(data: QuizData) {
    setQuizOpen(false)
    setSearchParams(data)
    setLimitMsg(false)
    if (remaining !== null) setRemaining(r => (r !== null && r > 0 ? r - 1 : 0))
    setTimeout(() => {
      const el = document.getElementById('dash-results')
      if (el) el.scrollIntoView({ behavior: 'smooth' })
    }, 200)
  }

  return (
    <div className="animate-pageFadeIn" style={{ minHeight: '100vh', background: '#0f0f1a', color: '#fff', fontFamily: 'Inter, -apple-system, sans-serif', position: 'relative' }}>

      {/* Fundo quadriculado */}
      <div style={{
        position: 'fixed', inset: 0, zIndex: 0, pointerEvents: 'none',
        backgroundImage: 'linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,.04) 1px, transparent 1px)',
        backgroundSize: '60px 60px',
        maskImage: 'radial-gradient(ellipse 100% 100% at 50% 0%, #000 30%, transparent 100%)',
        WebkitMaskImage: 'radial-gradient(ellipse 100% 100% at 50% 0%, #000 30%, transparent 100%)',
      }} />

      {/* Glow rosa sutil no topo */}
      <div style={{ position: 'fixed', top: 0, left: '50%', transform: 'translateX(-50%)', width: 600, height: 300, background: 'radial-gradient(ellipse at 50% 0%, rgba(232,121,160,.1) 0%, transparent 70%)', pointerEvents: 'none', zIndex: 0 }} />

      <QuizOverlay open={quizOpen} onClose={() => setQuizOpen(false)} onSearch={handleSearch} />

      {/* Nav */}
      <nav style={{ padding: '14px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(15,15,26,0.85)', backdropFilter: 'blur(24px)', borderBottom: '1px solid rgba(248,182,200,0.12)', position: 'sticky', top: 0, zIndex: 50 }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="/logo.png" alt="Honk Ponk" width={28} height={28} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.05rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 8, padding: '4px 12px', fontSize: '.76rem', fontWeight: 700, color: '#f8b6c8' }}>
            {planConfig.name}
          </span>
          <button onClick={handleLogout} disabled={loggingOut} style={{ background: 'rgba(255,255,255,.05)', color: 'rgba(255,255,255,.5)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, padding: '6px 14px', fontSize: '.78rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', transition: 'all .2s' }}>
            {loggingOut ? 'Saindo...' : 'Sair'}
          </button>
        </div>
      </nav>

      <div style={{ maxWidth: 960, margin: '0 auto', padding: '36px 20px', position: 'relative', zIndex: 1 }}>

        {/* Social proof bar */}
        <div className="animate-pageIn" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 20, marginBottom: 28, padding: '10px 20px', background: 'rgba(255,255,255,.025)', border: '1px solid rgba(255,255,255,.07)', borderRadius: 12, flexWrap: 'wrap', animationDelay: '0s' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: '.75rem', color: 'rgba(255,255,255,.45)' }}>
            <span style={{ color: '#e879a0', fontWeight: 700 }}>📍 12.847</span> leads encontrados essa semana
          </div>
          <div style={{ width: 1, height: 14, background: 'rgba(255,255,255,.1)' }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: '.75rem', color: 'rgba(255,255,255,.45)' }}>
            <span style={{ color: '#4ade80', fontWeight: 700 }}>✓ 3.201</span> usuários ativos
          </div>
          <div style={{ width: 1, height: 14, background: 'rgba(255,255,255,.1)' }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: '.75rem', color: 'rgba(255,255,255,.45)' }}>
            <span style={{ color: '#fbbf24', fontWeight: 700 }}>🔥 847</span> buscas nas últimas 24h
          </div>
        </div>

        {/* Saudação + botão */}
        <div className="animate-pageIn" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 14, marginBottom: 32, animationDelay: '.05s' }}>
          <div>
            <h1 style={{ fontSize: '1.6rem', fontWeight: 800, letterSpacing: -0.5, marginBottom: 4 }}>
              Olá, {user.email?.split('@')[0]} 👋
            </h1>
            <p style={{ color: 'rgba(255,255,255,.38)', fontSize: '.85rem' }}>Pronto para encontrar novos clientes?</p>
          </div>
          <button
            onClick={() => setQuizOpen(true)}
            style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '13px 22px', fontSize: '.92rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 6px 28px rgba(232,121,160,.38)', transition: 'transform .2s, box-shadow .2s' }}
            onMouseEnter={e => { (e.target as HTMLElement).style.transform = 'translateY(-2px)'; (e.target as HTMLElement).style.boxShadow = '0 10px 32px rgba(232,121,160,.5)' }}
            onMouseLeave={e => { (e.target as HTMLElement).style.transform = ''; (e.target as HTMLElement).style.boxShadow = '0 6px 28px rgba(232,121,160,.38)' }}
          >
            🔍 Nova busca
          </button>
        </div>

        {/* Cards */}
        <div className="animate-pageIn" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 14, marginBottom: 32, animationDelay: '.1s' }}>
          <div
            onMouseEnter={() => setHoveredCard('plan')}
            onMouseLeave={() => setHoveredCard(null)}
            style={{ background: 'linear-gradient(135deg,rgba(232,121,160,.14),rgba(194,24,91,.08))', border: `1px solid ${hoveredCard === 'plan' ? '#e879a0' : 'rgba(232,121,160,.25)'}`, borderRadius: 16, padding: '20px', backdropFilter: 'blur(10px)', transform: hoveredCard === 'plan' ? 'translateY(-5px) scale(1.02)' : 'none', boxShadow: hoveredCard === 'plan' ? '0 16px 40px rgba(232,121,160,.22)' : '0 0px 0px transparent', transition: 'all .3s cubic-bezier(.34,1.56,.64,1)', cursor: 'default' }}>
            <div style={{ fontSize: '.68rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase' as const, letterSpacing: 1, marginBottom: 8 }}>Plano atual</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 900, marginBottom: 2 }}>{planConfig.name}</div>
            <div style={{ fontSize: '.76rem', color: 'rgba(255,255,255,.38)' }}>{planConfig.price === 0 ? 'Grátis' : `${formatPrice(planConfig.price)}/mês`}</div>
          </div>
          <div
            onMouseEnter={() => setHoveredCard('searches')}
            onMouseLeave={() => setHoveredCard(null)}
            style={{ background: 'rgba(255,255,255,.03)', border: `1px solid ${hoveredCard === 'searches' ? 'rgba(248,182,200,.35)' : 'rgba(255,255,255,.08)'}`, borderRadius: 16, padding: '20px', backdropFilter: 'blur(10px)', transform: hoveredCard === 'searches' ? 'translateY(-5px)' : 'none', boxShadow: hoveredCard === 'searches' ? '0 16px 40px rgba(0,0,0,.35)' : 'none', transition: 'all .3s cubic-bezier(.34,1.56,.64,1)', cursor: 'default' }}>
            <div style={{ fontSize: '.68rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase' as const, letterSpacing: 1, marginBottom: 8 }}>Buscas hoje</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 900, marginBottom: 2 }}>{remaining === null ? '∞' : remaining}</div>
            <div style={{ fontSize: '.76rem', color: 'rgba(255,255,255,.38)' }}>{remaining === null ? 'Ilimitadas' : `de ${planConfig.searchesPerDay} disponível${planConfig.searchesPerDay === 1 ? '' : 'is'}`}</div>
          </div>
          {plan !== 'enterprise' && (
            <div
              onMouseEnter={() => setHoveredCard('upgrade')}
              onMouseLeave={() => setHoveredCard(null)}
              style={{ background: 'rgba(255,255,255,.03)', border: `1px solid ${hoveredCard === 'upgrade' ? 'rgba(248,182,200,.35)' : 'rgba(255,255,255,.08)'}`, borderRadius: 16, padding: '20px', backdropFilter: 'blur(10px)', display: 'flex', flexDirection: 'column' as const, gap: 10, transform: hoveredCard === 'upgrade' ? 'translateY(-5px)' : 'none', boxShadow: hoveredCard === 'upgrade' ? '0 16px 40px rgba(0,0,0,.35)' : 'none', transition: 'all .3s cubic-bezier(.34,1.56,.64,1)' }}>
              <div style={{ fontSize: '.68rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase' as const, letterSpacing: 1 }}>Upgrade</div>
              <div style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.42)', flex: 1 }}>Mais buscas, Excel e recursos avançados.</div>
              <Link href="/#precos" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 8, padding: '8px 14px', fontSize: '.78rem', fontWeight: 700, textDecoration: 'none', textAlign: 'center' as const }}>Ver planos →</Link>
            </div>
          )}
        </div>

        {/* Área principal */}
        {!searchParams ? (
          <div className="animate-pageIn" style={{ background: 'rgba(255,255,255,.02)', border: '1px dashed rgba(248,182,200,.15)', borderRadius: 20, padding: '64px 24px', textAlign: 'center' as const, backdropFilter: 'blur(10px)', animationDelay: '.18s' }}>
            <div style={{ fontSize: '3rem', marginBottom: 16 }}>🔍</div>
            <h2 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: 8 }}>Nenhuma busca ainda</h2>
            <p style={{ color: 'rgba(255,255,255,.38)', marginBottom: 28, fontSize: '.86rem' }}>
              Clique em "Nova busca" para encontrar seus primeiros leads.
            </p>
            <button
              onClick={() => setQuizOpen(true)}
              style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 32px', fontSize: '.95rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.3)', transition: 'transform .2s' }}
            >
              🔍 Começar busca
            </button>
          </div>
        ) : (
          <div id="dash-results">
            {limitMsg && (
              <div style={{ background: 'rgba(251,146,60,.08)', border: '1px solid rgba(251,146,60,.2)', borderRadius: 12, padding: '14px 18px', marginBottom: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, flexWrap: 'wrap' as const }}>
                <p style={{ color: '#fb923c', fontSize: '.85rem', fontWeight: 600 }}>⚡ Limite de buscas atingido hoje.</p>
                <Link href="/#precos" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 8, padding: '7px 14px', fontSize: '.78rem', fontWeight: 700, textDecoration: 'none' }}>Fazer upgrade</Link>
              </div>
            )}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18, flexWrap: 'wrap' as const, gap: 10 }}>
              <div>
                <h2 style={{ fontSize: '1.05rem', fontWeight: 800, marginBottom: 2 }}>Resultados da busca</h2>
                <p style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.38)' }}>
                  {searchParams.allBrazil ? 'Todo o Brasil' : searchParams.city} · {searchParams.segment}
                </p>
              </div>
              <button
                onClick={() => setQuizOpen(true)}
                style={{ background: 'rgba(255,255,255,.05)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '8px 16px', fontSize: '.8rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', transition: 'all .2s' }}
              >
                ↺ Nova busca
              </button>
            </div>
            <SearchResults key={JSON.stringify(searchParams)} params={searchParams} userId={user.id} plan={plan} onLimitReached={() => setLimitMsg(true)} />
          </div>
        )}
      </div>
    </div>
  )
}
