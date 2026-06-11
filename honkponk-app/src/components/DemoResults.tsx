'use client'
import Link from 'next/link'
import { SERVICE_META } from '@/lib/search'

interface DemoParams { service: string; city: string; segment: string; allBrazil: boolean }

// Sample leads shown to visitors WITHOUT an account, so the quiz isn't a dead end.
const SAMPLE_NAMES = [
  { name: 'Studio Bella Estética', rating: 4.8, reviews: 127 },
  { name: 'Padaria Pão Quente', rating: 4.6, reviews: 89 },
  { name: 'Auto Center Silva', rating: 4.9, reviews: 203 },
  { name: 'Clínica Vida & Saúde', rating: 4.7, reviews: 156 },
  { name: 'Restaurante Sabor Caseiro', rating: 4.5, reviews: 64 },
]

export function DemoResults({ params }: { params: DemoParams }) {
  const meta = SERVICE_META[params.service] || SERVICE_META.outros
  const local = params.allBrazil ? 'todo o Brasil' : (params.city || 'sua região')

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16, flexWrap: 'wrap' }}>
        <div style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', borderRadius: 8, padding: '6px 14px', fontSize: '.82rem', fontWeight: 800, letterSpacing: .5 }}>
          +40 leads encontrados
        </div>
        <span style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.35)' }}>{meta.filterLabel} · {local}</span>
      </div>

      {/* Sample cards (blurred teaser) */}
      <div style={{ position: 'relative' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {SAMPLE_NAMES.map((s, i) => (
            <div key={i} style={{
              background: 'rgba(255,255,255,.03)',
              border: '1px solid rgba(248,182,200,.1)',
              borderRadius: 16, padding: '16px 20px',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap',
              filter: i > 1 ? `blur(${Math.min(i * 1.5, 5)}px)` : 'none',
              opacity: i > 1 ? 0.7 : 1,
            }}>
              <div style={{ flex: 1, minWidth: 200 }}>
                <div style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 6 }}>{s.name}</div>
                <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)', marginBottom: 8 }}>📍 {local}</div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <span style={{ fontSize: '.72rem', fontWeight: 700, color: '#fbbf24', background: 'rgba(251,191,36,.08)', borderRadius: 6, padding: '3px 8px' }}>⭐ {s.rating} ({s.reviews})</span>
                  <span style={{ fontSize: '.72rem', fontWeight: 700, color: '#f8b6c8', background: 'rgba(232,121,160,.1)', borderRadius: 6, padding: '3px 8px' }}>📷 Sem site</span>
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <span style={{ background: 'linear-gradient(135deg,#25D366,#128C7E)', color: '#fff', borderRadius: 10, padding: '8px 16px', fontSize: '.8rem', fontWeight: 700 }}>💬 WhatsApp</span>
                <span style={{ background: 'rgba(255,255,255,.08)', color: '#fff', borderRadius: 10, padding: '8px 16px', fontSize: '.8rem', fontWeight: 700 }}>📷 Instagram</span>
              </div>
            </div>
          ))}
        </div>

        {/* Signup overlay */}
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(180deg, transparent 0%, rgba(22,22,42,.6) 40%, rgba(22,22,42,.96) 75%)',
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end',
          textAlign: 'center', padding: '0 24px 28px', borderRadius: 16,
        }}>
          <div style={{ fontSize: '2rem', marginBottom: 8 }}>🔒</div>
          <h3 style={{ fontSize: '1.4rem', fontWeight: 800, marginBottom: 8, letterSpacing: -.5 }}>
            Achamos seus clientes ideais!
          </h3>
          <p style={{ color: 'rgba(255,255,255,.6)', fontSize: '.92rem', maxWidth: 400, marginBottom: 20, lineHeight: 1.6 }}>
            Crie sua conta grátis em segundos e veja todos os leads com WhatsApp, Instagram e telefone.
          </p>
          <Link href="/signup" style={{
            background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff',
            borderRadius: 14, padding: '15px 34px', fontSize: '1rem', fontWeight: 700,
            textDecoration: 'none', boxShadow: '0 8px 30px rgba(232,121,160,.4)',
          }}>
            Criar conta grátis e ver os leads →
          </Link>
          <p style={{ color: 'rgba(255,255,255,.35)', fontSize: '.78rem', marginTop: 14 }}>
            Sem cartão de crédito · 1 busca grátis por dia
          </p>
        </div>
      </div>
    </div>
  )
}
