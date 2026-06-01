'use client'
import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { PLANS, formatPrice, getRemainingSearches } from '@/lib/plans'
import type { Plan } from '@/lib/plans'
import type { User } from '@supabase/supabase-js'

interface Profile { id: string; email: string; plan: Plan; searches_today: number; searches_reset_at: string; team_owner_id?: string | null }
interface TeamMember { id: string; owner_id: string; member_email: string; status: string }

export function DashboardClient({ user, profile, teamMembers }: { user: User; profile: Profile | null; teamMembers: TeamMember[] }) {
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviteStatus, setInviteStatus] = useState('')
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

  async function handleInvite(e: React.FormEvent) {
    e.preventDefault()
    setInviteStatus('')
    if (teamMembers.length >= 4) { setInviteStatus('Limite de 4 membros atingido.'); return }
    const { error } = await supabase.from('team_members').insert({ owner_id: user.id, member_email: inviteEmail, status: 'pending' })
    if (error) { setInviteStatus('Erro ao convidar.') }
    else { setInviteStatus(`✓ Convite enviado para ${inviteEmail}`); setInviteEmail('') }
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a' }}>
      <nav style={{ padding: '16px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(15,15,26,0.8)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(248,182,200,0.18)', position: 'sticky', top: 0, zIndex: 100 }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="https://site-oficial-br-y.github.io/Honkponk/logo.png" alt="Honk Ponk" width={32} height={32} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.2rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <Link href="/" style={{ color: 'rgba(255,255,255,.6)', textDecoration: 'none', fontSize: '.875rem' }}>← Início</Link>
          <button onClick={handleLogout} disabled={loggingOut} style={{ background: 'rgba(255,255,255,.08)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 10, padding: '8px 16px', fontSize: '.875rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
            {loggingOut ? 'Saindo...' : 'Sair'}
          </button>
        </div>
      </nav>
      <div style={{ maxWidth: 900, margin: '0 auto', padding: '40px 24px' }}>
        <h1 style={{ fontSize: '1.8rem', fontWeight: 800, letterSpacing: -1, marginBottom: 8 }}>Minha Conta</h1>
        <p style={{ color: 'rgba(255,255,255,.5)', marginBottom: 40 }}>{user.email}</p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(260px,1fr))', gap: 20, marginBottom: 32 }}>
          <div style={{ background: 'rgba(248,182,200,.15)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 20, padding: 28 }}>
            <div style={{ fontSize: '.75rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Plano atual</div>
            <div style={{ fontSize: '2rem', fontWeight: 900, marginBottom: 4 }}>{planConfig.name}</div>
            <div style={{ fontSize: '.9rem', color: 'rgba(255,255,255,.5)', marginBottom: 20 }}>{planConfig.price === 0 ? 'Grátis' : `${formatPrice(planConfig.price)}/mês`}</div>
            {plan !== 'enterprise' && <Link href="/#precos" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 10, padding: '10px 20px', fontSize: '.875rem', fontWeight: 700, textDecoration: 'none' }}>Fazer upgrade →</Link>}
          </div>
          <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28 }}>
            <div style={{ fontSize: '.75rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Buscas hoje</div>
            <div style={{ fontSize: '2rem', fontWeight: 900, marginBottom: 4 }}>{remaining === null ? '∞' : remaining}</div>
            <div style={{ fontSize: '.9rem', color: 'rgba(255,255,255,.5)' }}>{remaining === null ? 'Buscas ilimitadas' : `de ${planConfig.searchesPerDay} disponíveis hoje`}</div>
          </div>
          <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28 }}>
            <div style={{ fontSize: '.75rem', fontWeight: 700, color: '#f8b6c8', textTransform: 'uppercase', letterSpacing: 1, marginBottom: 12 }}>Recursos do plano</div>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 8 }}>
              {planConfig.features.map(f => <li key={f} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '.85rem', color: 'rgba(255,255,255,.7)' }}><span style={{ color: '#4ade80' }}>✓</span> {f}</li>)}
            </ul>
          </div>
        </div>
        {plan === 'enterprise' && (
          <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28, marginBottom: 32 }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 800, marginBottom: 6 }}>Gerenciar equipe</h2>
            <p style={{ fontSize: '.85rem', color: 'rgba(255,255,255,.5)', marginBottom: 24 }}>Convide até 4 membros adicionais.</p>
            <form onSubmit={handleInvite} style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
              <input type="email" value={inviteEmail} onChange={e => setInviteEmail(e.target.value)} placeholder="email@exemplo.com" required style={{ flex: 1, minWidth: 220, background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '12px 16px', color: '#fff', fontSize: '.95rem', fontFamily: 'inherit', outline: 'none' }} />
              <button type="submit" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '12px 20px', fontSize: '.9rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit' }}>Convidar</button>
            </form>
            {inviteStatus && <p style={{ fontSize: '.85rem', color: inviteStatus.startsWith('✓') ? '#4ade80' : '#fb923c', marginBottom: 16 }}>{inviteStatus}</p>}
          </div>
        )}
        <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28 }}>
          <h2 style={{ fontSize: '1.1rem', fontWeight: 800, marginBottom: 20 }}>Ações rápidas</h2>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
            <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '12px 20px', fontSize: '.9rem', fontWeight: 700, textDecoration: 'none' }}>🔍 Buscar leads</Link>
            <Link href="/#precos" style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'rgba(248,182,200,.1)', color: '#f8b6c8', border: '1px solid rgba(248,182,200,.2)', borderRadius: 12, padding: '12px 20px', fontSize: '.9rem', fontWeight: 600, textDecoration: 'none' }}>📊 Ver planos</Link>
            <a href="mailto:honkponkoficial@gmail.com" style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 12, padding: '12px 20px', fontSize: '.9rem', fontWeight: 600, textDecoration: 'none' }}>💬 Suporte</a>
          </div>
        </div>
      </div>
    </div>
  )
}
