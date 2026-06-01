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
    setTimeout(() => document.getElementById('dash-results')?.scrollIntoView({ behavior: 'smooth' }), 100)
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', color: '#fff' }}>
      {/* Nav */}
      <nav style={{ padding: '14px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(15,15,26,0.9)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(248,182,200,0.15)', position: 'sticky', top: 0, zIndex: 100 }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="https://site-oficial-br-y.github.io/Honkponk/logo.png" alt="Honk Ponk" width={30} height={30} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.15rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.4)', display: 'none' }}>{user.email}</span>
          <div style={{ background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 8, padding: '5px 12px', fontSize: '.8rem', fontWeight: 700, color: '#f8b6c8' }}>
            {planConfig.name}
          </div>
          <button onClick={handleLogout} disabled={loggingOut} style={{ background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, padding: '7px 14px', fontSize: '.82rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
            {loggingOut ? 'Saindo...' : 'Sair'}
          </button>
        </div>
      </nav>

      <QuizOverlay open={quizOpen} onClose={() => setQuizOpen(false)} onSearch={handleSearch} />

      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '36px 24px' }}>

        {/* Header + stats */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 16, marginBottom: 28 }}>
          <div>
            <h1 style={{ fontSize: '1.6rem', fontWeight: 800, letterSpacing: -1, marginBottom: 4 }}>Olá, {user.email?.split('@')[0]} 👋</h1>
            <p style={{ color: 'rgba(255,255,255,.4)', fontSize: '.85rem' }}>Pronto para encontrar novos clientes?</p>
          </div>
          <button onClick={() => setQuizOpen(true)} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '13px 24px', fontSize: '.95rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 6px 24px rgba(232,121,160,.35)' }}>
            🔍 Nova busca
          </button>
        </div>

        {/* Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(200px,1fr))', gap: 16, marginBottom: 32 }}>
          <div style={{ background: 'rgba(232,121,160,.1)', border: '1px solid rgba(232,121,160,.25)', borderRadius: 16, padding: '20px 24px' }}>
            <div style={{ fontSize: '.7rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8 }}>Plano</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 900, marginBottom: 4 }}>{planConfig.name}</div>
            <div style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.45)' }}>{planConfig.price === 0 ? 'Grátis' : `${formatPrice(planConfig.price)}/mês`}</div>
          </div>
          <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.15)', borderRadius: 16, padding: '20px 24px' }}>
            <div style={{ fontSize: '.7rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8 }}>Buscas hoje</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 900, marginBottom: 4 }}>{remaining === null ? '∞' : remaining}</div>
            <div style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.45)' }}>{remaining === null ? 'Ilimitadas' : `de ${planConfig.searchesPerDay} disponíveis`}</div>
          </div>
          {plan !== 'enterprise' && (
            <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.15)', borderRadius: 16, padding: '20px 24px', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div style={{ fontSize: '.7rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 8 }}>Upgrade</div>
              <div style={{ fontSize: '.85rem', color: 'rgba(255,255,255,.5)', marginBottom: 14 }}>Mais buscas, exportação Excel e mais.</div>
              <Link href="/#precos" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 10, padding: '9px 18px', fontSize: '.82rem', fontWeight: 700, textDecoration: 'none', textAlign: 'center' }}>Ver planos →</Link>
            </div>
          )}
        </div>

        {/* Busca vazia ou resultados */}
        {!searchParams ? (
          <div style={{ background: 'rgba(255,255,255,.03)', border: '1px dashed rgba(248,182,200,.2)', borderRadius: 20, padding: '60px 24px', textAlign: 'center' }}>
            <div style={{ fontSize: '3rem', marginBottom: 16 }}>🔍</div>
            <h2 style={{ fontSize: '1.3rem', fontWeight: 800, marginBottom: 8 }}>Nenhuma busca ainda</h2>
            <p style={{ color: 'rgba(255,255,255,.4)', marginBottom: 28, fontSize: '.9rem' }}>Clique em "Nova busca" para encontrar seus primeiros leads.</p>
            <button onClick={() => setQuizOpen(true)} style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 32px', fontSize: '1rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.3)' }}>
              🔍 Começar busca
            </button>
          </div>
        ) : (
          <div id="dash-results">
            {limitMsg && (
              <div style={{ background: 'rgba(251,146,60,.1)', border: '1px solid rgba(251,146,60,.25)', borderRadius: 14, padding: '16px 20px', marginBottom: 20, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                <p style={{ color: '#fb923c', fontSize: '.88rem', fontWeight: 600 }}>⚡ Limite de buscas atingido hoje.</p>
                <Link href="/#precos" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 10, padding: '9px 18px', fontSize: '.82rem', fontWeight: 700, textDecoration: 'none' }}>Fazer upgrade</Link>
              </div>
            )}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20, flexWrap: 'wrap', gap: 12 }}>
              <div>
                <h2 style={{ fontSize: '1.1rem', fontWeight: 800, marginBottom: 2 }}>Resultados da busca</h2>
                <p style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.4)' }}>{searchParams.allBrazil ? 'Todo o Brasil' : searchParams.city} · {searchParams.service}</p>
              </div>
              <button onClick={() => setQuizOpen(true)} style={{ background: 'rgba(255,255,255,.07)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: '9px 16px', fontSize: '.82rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>↺ Nova busca</button>
            </div>
            <SearchResults params={searchParams} userId={user.id} onLimitReached={() => setLimitMsg(true)} />
          </div>
        )}
      </div>
    </div>
  )
}
