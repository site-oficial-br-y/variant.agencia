'use client'
import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'
import { PLANS, formatPrice } from '@/lib/plans'
import type { Plan } from '@/lib/plans'

export default function CheckoutPage() {
  const params = useParams()
  const router = useRouter()
  const planKey = params.plan as Plan
  const planConfig = PLANS[planKey]
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [userId, setUserId] = useState<string | null>(null)
  const [userEmail, setUserEmail] = useState<string>('')
  const supabase = createClient()

  useEffect(() => {
    if (!planConfig || planKey === 'free') { router.push('/'); return }
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) { router.push('/login'); return }
      setUserId(data.user.id)
      setUserEmail(data.user.email || '')
    })
  }, [planConfig, planKey, router, supabase])

  if (!planConfig || planKey === 'free') return null

  async function handleCheckout() {
    if (!userId) { router.push('/login'); return }
    setLoading(true)
    setError('')
    try {
      const res = await fetch('/api/create-payment', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plan: planKey, userId, email: userEmail }),
      })
      const data = await res.json()
      if (data.init_point) { window.location.href = data.init_point }
      else { setError(data.error || 'Erro ao criar pagamento.') }
    } catch { setError('Erro de conexão.') }
    finally { setLoading(false) }
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 480 }}>
        <div style={{ textAlign: 'center', marginBottom: 36 }}>
          <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 10, textDecoration: 'none', marginBottom: 24 }}>
            <Image src="/logo.svg" alt="Honk Ponk" width={40} height={40} style={{ objectFit: 'contain', borderRadius: 8 }} />
            <span style={{ fontSize: '1.4rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
          </Link>
          <h1 style={{ fontSize: '1.8rem', fontWeight: 800, letterSpacing: -1, marginBottom: 8 }}>Assinar plano {planConfig.name}</h1>
        </div>
        <div style={{ background: '#16162a', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 32, marginBottom: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24, paddingBottom: 24, borderBottom: '1px solid rgba(255,255,255,.08)' }}>
            <div>
              <div style={{ fontWeight: 800, fontSize: '1.1rem' }}>{planConfig.name}</div>
              <div style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.5)', marginTop: 2 }}>{planConfig.description}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: '1.6rem', fontWeight: 900, color: '#e879a0' }}>{formatPrice(planConfig.price)}</div>
              <div style={{ fontSize: '.75rem', color: 'rgba(255,255,255,.4)' }}>/mês</div>
            </div>
          </div>
          <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 28 }}>
            {planConfig.features.map(f => (
              <li key={f} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '.9rem', color: 'rgba(255,255,255,.7)' }}>
                <span style={{ color: '#4ade80' }}>✓</span> {f}
              </li>
            ))}
          </ul>
          {error && <p style={{ color: '#fb923c', fontSize: '.85rem', textAlign: 'center', marginBottom: 16 }}>{error}</p>}
          <button onClick={handleCheckout} disabled={loading || !userId}
            style={{ width: '100%', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '16px', fontSize: '1.05rem', fontWeight: 700, cursor: loading || !userId ? 'not-allowed' : 'pointer', opacity: loading || !userId ? 0.7 : 1, fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.35)' }}>
            {loading ? 'Redirecionando...' : 'Pagar com Mercado Pago →'}
          </button>
        </div>
        <p style={{ textAlign: 'center', color: 'rgba(255,255,255,.4)', fontSize: '.875rem' }}>
          <Link href="/dashboard" style={{ color: '#f8b6c8', textDecoration: 'none' }}>← Voltar para o dashboard</Link>
        </p>
      </div>
    </div>
  )
}
