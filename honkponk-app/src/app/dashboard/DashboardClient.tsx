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

interface Profile { id: string; email: string; plan: Plan; searches_today: number; searches_reset_at: string; team_owner_id?: string | null; honk_coins?: number }
interface TeamMember { id: string; owner_id: string; member_email: string; status: string }
interface QuizData { service: string; city: string; segment: string; allBrazil: boolean }

export function DashboardClient({ user, profile, teamMembers }: { user: User; profile: Profile | null; teamMembers: TeamMember[] }) {
  const [quizOpen, setQuizOpen] = useState(false)
  const [searchParams, setSearchParams] = useState<QuizData | null>(null)
  const [limitMsg, setLimitMsg] = useState(false)
  const [loggingOut, setLoggingOut] = useState(false)
  const [hoveredCard, setHoveredCard] = useState<string | null>(null)
  const [members, setMembers] = useState<TeamMember[]>(teamMembers)
  const [inviteEmail, setInviteEmail] = useState('')
  const [teamLoading, setTeamLoading] = useState(false)
  const [teamError, setTeamError] = useState('')
  const [feedbackOpen, setFeedbackOpen] = useState(false)
  const [feedbackRating, setFeedbackRating] = useState(0)
  const [feedbackMsg, setFeedbackMsg] = useState('')
  const [feedbackLoading, setFeedbackLoading] = useState(false)
  const [feedbackSent, setFeedbackSent] = useState(false)
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

  async function handleInvite(e: React.FormEvent) {
    e.preventDefault()
    setTeamError('')
    if (!inviteEmail) return
    setTeamLoading(true)
    try {
      const res = await fetch('/api/team/invite', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ownerId: user.id, email: inviteEmail }),
      })
      const data = await res.json()
      if (!res.ok) { setTeamError(data.error || 'Erro ao convidar.'); return }
      setMembers(m => [...m, { id: crypto.randomUUID(), owner_id: user.id, member_email: inviteEmail.trim().toLowerCase(), status: 'pending' }])
      setInviteEmail('')
    } catch { setTeamError('Erro de conexão.') }
    finally { setTeamLoading(false) }
  }

  async function handleFeedback() {
    if (feedbackRating === 0 && !feedbackMsg.trim()) return
    setFeedbackLoading(true)
    try {
      const res = await fetch('/api/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rating: feedbackRating, message: feedbackMsg.trim() }),
      })
      if (res.ok) {
        setFeedbackSent(true)
        setTimeout(() => { setFeedbackOpen(false); setFeedbackSent(false); setFeedbackRating(0); setFeedbackMsg('') }, 1800)
      }
    } catch { /* silencioso */ }
    finally { setFeedbackLoading(false) }
  }

  async function handleRemoveMember(memberId: string) {
    setTeamError('')
    setTeamLoading(true)
    try {
      const res = await fetch('/api/team/remove', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ownerId: user.id, memberId }),
      })
      const data = await res.json()
      if (!res.ok) { setTeamError(data.error || 'Erro ao remover.'); return }
      setMembers(m => m.filter(member => member.id !== memberId))
    } catch { setTeamError('Erro de conexão.') }
    finally { setTeamLoading(false) }
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
          <a href="/checkout/coins" style={{ background: 'rgba(232,121,160,.1)', border: '1px solid rgba(232,121,160,.2)', borderRadius: 8, padding: '4px 10px', fontSize: '.76rem', fontWeight: 700, color: '#f8b6c8', display: 'flex', alignItems: 'center', gap: 5, textDecoration: 'none', cursor: 'pointer' }}>
            🪙 {profile?.honk_coins ?? 0}
          </a>
          <button onClick={() => setFeedbackOpen(true)} style={{ background: 'rgba(255,255,255,.05)', color: 'rgba(255,255,255,.5)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, padding: '6px 14px', fontSize: '.78rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', transition: 'all .2s' }}>
            💬 Feedback
          </button>
          <button onClick={handleLogout} disabled={loggingOut} style={{ background: 'rgba(255,255,255,.05)', color: 'rgba(255,255,255,.5)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, padding: '6px 14px', fontSize: '.78rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', transition: 'all .2s' }}>
            {loggingOut ? 'Saindo...' : 'Sair'}
          </button>
        </div>
      </nav>

      {/* Modal de feedback */}
      {feedbackOpen && (
        <div onClick={() => !feedbackLoading && setFeedbackOpen(false)} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.6)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24, zIndex: 100 }}>
          <div onClick={e => e.stopPropagation()} style={{ background: '#16162a', border: '1px solid rgba(248,182,200,.18)', borderRadius: 20, padding: 32, width: '100%', maxWidth: 420 }}>
            {feedbackSent ? (
              <div style={{ textAlign: 'center', padding: '20px 0' }}>
                <div style={{ fontSize: '2.5rem', marginBottom: 12 }}>🙏</div>
                <p style={{ fontSize: '1.05rem', fontWeight: 700, color: '#4ade80' }}>Obrigado pelo feedback!</p>
              </div>
            ) : (
              <>
                <h2 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: 6 }}>Deixe seu feedback</h2>
                <p style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.5)', marginBottom: 20 }}>Sua opinião ajuda a melhorar o Honk Ponk.</p>
                <div style={{ display: 'flex', gap: 8, marginBottom: 18, justifyContent: 'center' }}>
                  {[1,2,3,4,5].map(i => (
                    <button key={i} onClick={() => setFeedbackRating(i)} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '1.8rem', color: i <= feedbackRating ? '#fbbf24' : 'rgba(255,255,255,.2)', padding: 0, lineHeight: 1 }}>★</button>
                  ))}
                </div>
                <textarea value={feedbackMsg} onChange={e => setFeedbackMsg(e.target.value)} placeholder="Conte o que achou, o que faltou, sugestões..." rows={4}
                  style={{ width: '100%', background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '12px 14px', color: '#fff', fontSize: '.9rem', fontFamily: 'inherit', outline: 'none', resize: 'vertical', marginBottom: 18 }} />
                <div style={{ display: 'flex', gap: 10 }}>
                  <button onClick={() => setFeedbackOpen(false)} style={{ flex: 1, background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 12, padding: '12px', fontSize: '.9rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>Cancelar</button>
                  <button onClick={handleFeedback} disabled={feedbackLoading || (feedbackRating === 0 && !feedbackMsg.trim())} style={{ flex: 2, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '12px', fontSize: '.9rem', fontWeight: 700, cursor: feedbackLoading ? 'not-allowed' : 'pointer', fontFamily: 'inherit', opacity: (feedbackLoading || (feedbackRating === 0 && !feedbackMsg.trim())) ? 0.6 : 1 }}>
                    {feedbackLoading ? 'Enviando...' : 'Enviar feedback'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      <div style={{ maxWidth: 960, margin: '0 auto', padding: '36px 20px', position: 'relative', zIndex: 1 }}>

        {/* Barra de destaques (sem números inventados) */}
        <div className="animate-pageIn" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 20, marginBottom: 28, padding: '10px 20px', background: 'rgba(255,255,255,.025)', border: '1px solid rgba(255,255,255,.07)', borderRadius: 12, flexWrap: 'wrap', animationDelay: '0s' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: '.75rem', color: 'rgba(255,255,255,.45)' }}>
            <span style={{ color: '#e879a0', fontWeight: 700 }}>📍 Dados reais</span> direto do Google
          </div>
          <div style={{ width: 1, height: 14, background: 'rgba(255,255,255,.1)' }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: '.75rem', color: 'rgba(255,255,255,.45)' }}>
            <span style={{ color: '#4ade80', fontWeight: 700 }}>✓ Contatos prontos</span> pra abordar
          </div>
          <div style={{ width: 1, height: 14, background: 'rgba(255,255,255,.1)' }} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: '.75rem', color: 'rgba(255,255,255,.45)' }}>
            <span style={{ color: '#fbbf24', fontWeight: 700 }}>🔥 Todo o Brasil</span> ou por cidade
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

        {/* Equipe (plano Empresa) */}
        {plan === 'enterprise' && !profile?.team_owner_id && (
          <div className="animate-pageIn" style={{ background: 'rgba(255,255,255,.02)', border: '1px solid rgba(248,182,200,.15)', borderRadius: 20, padding: '24px', marginBottom: 32, animationDelay: '.14s' }}>
            <h2 style={{ fontSize: '1.05rem', fontWeight: 800, marginBottom: 4 }}>👥 Equipe</h2>
            <p style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.4)', marginBottom: 18 }}>
              Adicione até {PLANS.enterprise.maxUsers - 1} membros para terem acesso ao plano Empresa.
            </p>
            <form onSubmit={handleInvite} style={{ display: 'flex', gap: 10, marginBottom: 18, flexWrap: 'wrap' as const }}>
              <input
                type="email"
                value={inviteEmail}
                onChange={e => setInviteEmail(e.target.value)}
                placeholder="email@exemplo.com"
                disabled={teamLoading || members.length >= PLANS.enterprise.maxUsers - 1}
                style={{ flex: '1 1 220px', background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 10, padding: '10px 14px', color: '#fff', fontSize: '.88rem', fontFamily: 'inherit', outline: 'none' }}
              />
              <button
                type="submit"
                disabled={teamLoading || !inviteEmail || members.length >= PLANS.enterprise.maxUsers - 1}
                style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 10, padding: '10px 20px', fontSize: '.85rem', fontWeight: 700, cursor: teamLoading ? 'not-allowed' : 'pointer', fontFamily: 'inherit', opacity: teamLoading ? 0.7 : 1 }}
              >
                Convidar
              </button>
            </form>
            {teamError && <p style={{ color: '#fb923c', fontSize: '.82rem', marginBottom: 14 }}>{teamError}</p>}
            {members.length > 0 ? (
              <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 8 }}>
                {members.map(member => (
                  <li key={member.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 10, padding: '10px 14px', fontSize: '.85rem' }}>
                    <span>{member.member_email}</span>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <span style={{ fontSize: '.72rem', fontWeight: 700, color: member.status === 'active' ? '#4ade80' : '#fbbf24', textTransform: 'uppercase' as const }}>
                        {member.status === 'active' ? 'Ativo' : 'Pendente'}
                      </span>
                      <button onClick={() => handleRemoveMember(member.id)} disabled={teamLoading} style={{ background: 'none', border: 'none', color: 'rgba(255,255,255,.4)', cursor: 'pointer', fontSize: '.8rem' }}>✕</button>
                    </div>
                  </li>
                ))}
              </ul>
            ) : (
              <p style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.35)' }}>Nenhum membro adicionado ainda.</p>
            )}
          </div>
        )}

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
