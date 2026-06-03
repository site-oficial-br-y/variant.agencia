'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

const COIN_PACKAGES = [
  { id: 'coins_10', coins: 10, price: 'R$9,90', description: 'Ideal para testar' },
  { id: 'coins_30', coins: 30, price: 'R$19,90', description: 'Mais popular', featured: true },
  { id: 'coins_60', coins: 60, price: 'R$34,90', description: 'Melhor custo-benefício' },
]

export default function CoinsCheckoutPage() {
  const router = useRouter()
  const supabase = createClient()
  const [userId, setUserId] = useState<string | null>(null)
  const [userEmail, setUserEmail] = useState<string>('')
  const [loading, setLoading] = useState<string | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) { router.push('/login'); return }
      setUserId(data.user.id)
      setUserEmail(data.user.email || '')
    })
  }, [router, supabase])

  async function handleBuy(packageId: string) {
    if (!userId) { router.push('/login'); return }
    setLoading(packageId)
    setError('')
    try {
      const res = await fetch('/api/coins/purchase', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ packageId, userId, email: userEmail }),
      })
      const data = await res.json()
      if (data.init_point) { window.location.href = data.init_point }
      else { setError(data.error || 'Erro ao criar pagamento.') }
    } catch { setError('Erro de conexão.') }
    finally { setLoading(null) }
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24, color: '#fff', fontFamily: 'Inter, -apple-system, sans-serif' }}>
      <div style={{ width: '100%', maxWidth: 640 }}>
        <div style={{ textAlign: 'center', marginBottom: 40 }}>
          <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 10, textDecoration: 'none', marginBottom: 28 }}>
            <Image src="/logo.png" alt="Honk Ponk" width={40} height={40} style={{ objectFit: 'contain', borderRadius: 8 }} />
            <span style={{ fontSize: '1.4rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
          </Link>
          <h1 style={{ fontSize: '2rem', fontWeight: 800, letterSpacing: -1, marginBottom: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10 }}>
            <Image src="/honk-coin.png" alt="Honk Coins" width={32} height={32} style={{ objectFit: 'contain' }} />
            Honk Coins
          </h1>
          <p style={{ color: 'rgba(255,255,255,.45)', fontSize: '1rem' }}>Pague só quando precisar. Sem assinatura.</p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))', gap: 18, marginBottom: 24 }}>
          {COIN_PACKAGES.map(pkg => (
            <div key={pkg.id} style={{
              background: pkg.featured ? 'linear-gradient(135deg,rgba(232,121,160,.18),rgba(194,24,91,.12))' : 'rgba(255,255,255,.04)',
              border: `1px solid ${pkg.featured ? '#e879a0' : 'rgba(248,182,200,0.15)'}`,
              borderRadius: 20,
              padding: 28,
              textAlign: 'center',
              position: 'relative',
              boxShadow: pkg.featured ? '0 24px 60px rgba(232,121,160,.25)' : 'none',
            }}>
              {pkg.featured && (
                <div style={{ position: 'absolute', top: -12, left: '50%', transform: 'translateX(-50%)', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 100, padding: '4px 14px', fontSize: '.72rem', fontWeight: 700, whiteSpace: 'nowrap', boxShadow: '0 4px 12px rgba(232,121,160,.4)' }}>⭐ Mais popular</div>
              )}
              <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
                <Image src="/honk-coin.png" alt="Honk Coin" width={56} height={56} style={{ objectFit: 'contain' }} />
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 900, color: '#e879a0', marginBottom: 4 }}>{pkg.coins}</div>
              <div style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.5)', marginBottom: 16 }}>coins · {pkg.description}</div>
              <div style={{ fontSize: '1.4rem', fontWeight: 800, marginBottom: 20 }}>{pkg.price}</div>
              <button
                onClick={() => handleBuy(pkg.id)}
                disabled={loading === pkg.id || !userId}
                style={{
                  width: '100%',
                  background: pkg.featured ? 'linear-gradient(135deg,#e879a0,#c2185b)' : 'rgba(232,121,160,.15)',
                  color: '#fff',
                  border: pkg.featured ? 'none' : '1px solid rgba(232,121,160,.3)',
                  borderRadius: 12,
                  padding: '12px 16px',
                  fontSize: '.9rem',
                  fontWeight: 700,
                  cursor: loading === pkg.id || !userId ? 'not-allowed' : 'pointer',
                  opacity: loading === pkg.id || !userId ? 0.7 : 1,
                  fontFamily: 'inherit',
                  boxShadow: pkg.featured ? '0 8px 30px rgba(232,121,160,.35)' : 'none',
                }}
              >
                {loading === pkg.id ? 'Redirecionando...' : 'Comprar →'}
              </button>
            </div>
          ))}
        </div>

        {error && <p style={{ color: '#fb923c', fontSize: '.85rem', textAlign: 'center', marginBottom: 16 }}>{error}</p>}

        <p style={{ textAlign: 'center', color: 'rgba(255,255,255,.4)', fontSize: '.875rem' }}>
          <Link href="/dashboard" style={{ color: '#f8b6c8', textDecoration: 'none' }}>← Voltar para o dashboard</Link>
        </p>
      </div>
    </div>
  )
}
