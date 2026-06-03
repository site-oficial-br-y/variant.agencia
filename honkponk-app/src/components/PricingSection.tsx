'use client'
import { useState } from 'react'
import Link from 'next/link'
import { PLANS, formatPrice } from '@/lib/plans'

export function PricingSection({ onGetStarted }: { onGetStarted?: () => void }) {
  const [hovered, setHovered] = useState<string | null>(null)

  const plans = [
    { key: 'free', featured: false },
    { key: 'freelancer', featured: false },
    { key: 'agency', featured: true },
    { key: 'enterprise', featured: false },
  ] as const

  return (
    <section id="precos" style={{ padding: '90px 24px', background: '#0f0f1a', position: 'relative', overflow: 'hidden' }}>
      <div className="hero-grid" style={{ opacity: 0.4 }} />
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse 60% 40% at 50% 100%, rgba(232,121,160,.08) 0%, transparent 70%)', pointerEvents: 'none' }} />
      <div style={{ maxWidth: 1200, margin: '0 auto', position: 'relative', zIndex: 1 }}>
        <div className="reveal" style={{ textAlign: 'center', marginBottom: 60 }}>
          <span style={{ display: 'inline-block', background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 100, padding: '4px 14px', fontSize: '.75rem', fontWeight: 700, color: '#f8b6c8', marginBottom: 16, letterSpacing: '.5px', textTransform: 'uppercase' as const }}>Preços</span>
          <h2 style={{ fontSize: 'clamp(1.8rem,4vw,2.8rem)', fontWeight: 800, letterSpacing: -1.5, lineHeight: 1.15, marginBottom: 14 }}>Planos para todos os tamanhos.</h2>
          <p style={{ color: 'rgba(255,255,255,.45)', fontSize: '1rem' }}>Comece grátis. Escale quando precisar.</p>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(240px,1fr))', gap: 20 }}>
          {plans.map(({ key, featured }, i) => {
            const plan = PLANS[key]
            const isHovered = hovered === key
            return (
              <div key={key} className="reveal"
                onMouseEnter={() => setHovered(key)}
                onMouseLeave={() => setHovered(null)}
                style={{
                  background: featured ? 'linear-gradient(135deg,rgba(232,121,160,.18),rgba(194,24,91,.12))' : 'rgba(255,255,255,.04)',
                  border: `1px solid ${featured ? '#e879a0' : isHovered ? 'rgba(248,182,200,.35)' : 'rgba(248,182,200,0.15)'}`,
                  borderRadius: 20,
                  padding: 28,
                  position: 'relative',
                  boxShadow: featured ? '0 24px 60px rgba(232,121,160,.28)' : isHovered ? '0 20px 50px rgba(0,0,0,.5), 0 0 0 1px rgba(248,182,200,.15)' : 'none',
                  transform: featured ? (isHovered ? 'scale(1.06) translateY(-4px)' : 'scale(1.04)') : isHovered ? 'translateY(-8px)' : 'none',
                  transition: 'all .35s cubic-bezier(.34,1.56,.64,1)',
                  animationDelay: `${i * 0.1}s`,
                }}>
                {featured && (
                  <div style={{ position: 'absolute', top: -12, left: '50%', transform: 'translateX(-50%)', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 100, padding: '4px 14px', fontSize: '.72rem', fontWeight: 700, whiteSpace: 'nowrap', boxShadow: '0 4px 12px rgba(232,121,160,.4)' }}>⭐ Mais popular</div>
                )}
                <div style={{ marginBottom: 20 }}>
                  <h3 style={{ fontSize: '1.1rem', fontWeight: 800, marginBottom: 6 }}>{plan.name}</h3>
                  <p style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.5)', marginBottom: 16 }}>{plan.description}</p>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
                    <span style={{ fontSize: plan.price === 0 ? '2rem' : '2.2rem', fontWeight: 900, color: plan.price === 0 ? '#fff' : '#e879a0' }}>
                      {plan.price === 0 ? 'Grátis' : formatPrice(plan.price)}
                    </span>
                    {plan.price > 0 && <span style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.4)' }}>/mês</span>}
                  </div>
                </div>
                <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 28 }}>
                  {plan.features.map(f => (
                    <li key={f} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '.85rem', color: 'rgba(255,255,255,.75)' }}>
                      <span style={{ color: '#4ade80', flexShrink: 0, fontSize: '.9rem' }}>✓</span>{f}
                    </li>
                  ))}
                </ul>
                {plan.price === 0 ? (
                  <button onClick={onGetStarted} style={{ width: '100%', background: 'rgba(255,255,255,.08)', color: '#fff', border: '1px solid rgba(255,255,255,.15)', borderRadius: 12, padding: '13px 20px', fontSize: '.9rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', transition: 'background .2s' }}>
                    Começar grátis
                  </button>
                ) : (
                  <Link href={`/checkout/${key}`} style={{ display: 'block', width: '100%', background: featured ? 'linear-gradient(135deg,#e879a0,#c2185b)' : 'rgba(232,121,160,.15)', color: '#fff', border: featured ? 'none' : '1px solid rgba(232,121,160,.3)', borderRadius: 12, padding: '13px 20px', fontSize: '.9rem', fontWeight: 700, textDecoration: 'none', textAlign: 'center', boxShadow: featured ? '0 8px 30px rgba(232,121,160,.35)' : 'none', transition: 'all .2s' }}>
                    Assinar {plan.name}
                  </Link>
                )}
              </div>
            )
          })}
        </div>
      </div>

      {/* Honk Coins Section */}
      <div style={{ marginTop: 72 }}>
        <div className="reveal" style={{ textAlign: 'center', marginBottom: 40 }}>
          <span style={{ display: 'inline-block', background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 100, padding: '4px 14px', fontSize: '.75rem', fontWeight: 700, color: '#f8b6c8', marginBottom: 16, letterSpacing: '.5px', textTransform: 'uppercase' as const }}>Avulso</span>
          <h2 style={{ fontSize: 'clamp(1.6rem,3.5vw,2.4rem)', fontWeight: 800, letterSpacing: -1, lineHeight: 1.15, marginBottom: 10 }}>🪙 Honk Coins</h2>
          <p style={{ color: 'rgba(255,255,255,.45)', fontSize: '1rem' }}>Pague só quando precisar. Sem assinatura.</p>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(200px,1fr))', gap: 20, maxWidth: 760, margin: '0 auto' }}>
          {[
            { id: 'coins_10', coins: 10, price: 'R$9,90', label: 'Ideal para testar' },
            { id: 'coins_30', coins: 30, price: 'R$19,90', label: 'Mais popular', featured: true },
            { id: 'coins_60', coins: 60, price: 'R$34,90', label: 'Melhor custo-benefício' },
          ].map((pkg) => (
            <div key={pkg.id} className="reveal" style={{
              background: pkg.featured ? 'linear-gradient(135deg,rgba(232,121,160,.18),rgba(194,24,91,.12))' : 'rgba(255,255,255,.04)',
              border: `1px solid ${pkg.featured ? '#e879a0' : 'rgba(248,182,200,0.15)'}`,
              borderRadius: 20,
              padding: 28,
              textAlign: 'center' as const,
              position: 'relative',
              boxShadow: pkg.featured ? '0 24px 60px rgba(232,121,160,.22)' : 'none',
            }}>
              {pkg.featured && (
                <div style={{ position: 'absolute', top: -12, left: '50%', transform: 'translateX(-50%)', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 100, padding: '4px 14px', fontSize: '.72rem', fontWeight: 700, whiteSpace: 'nowrap' }}>⭐ Mais popular</div>
              )}
              <div style={{ fontSize: '2rem', marginBottom: 8 }}>🪙</div>
              <div style={{ fontSize: '2rem', fontWeight: 900, color: '#e879a0', marginBottom: 4 }}>{pkg.coins}</div>
              <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.45)', marginBottom: 12 }}>coins · {pkg.label}</div>
              <div style={{ fontSize: '1.35rem', fontWeight: 800, marginBottom: 20 }}>{pkg.price}</div>
              <Link href="/checkout/coins" style={{
                display: 'block',
                background: pkg.featured ? 'linear-gradient(135deg,#e879a0,#c2185b)' : 'rgba(232,121,160,.15)',
                color: '#fff',
                border: pkg.featured ? 'none' : '1px solid rgba(232,121,160,.3)',
                borderRadius: 12,
                padding: '12px 16px',
                fontSize: '.88rem',
                fontWeight: 700,
                textDecoration: 'none',
                boxShadow: pkg.featured ? '0 8px 30px rgba(232,121,160,.35)' : 'none',
              }}>
                Comprar coins →
              </Link>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
