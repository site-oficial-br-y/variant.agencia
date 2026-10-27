'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { SERVICE_META, SEGMENT_NAMES } from '@/lib/search'

interface DemoParams { service: string; city: string; segment: string; allBrazil: boolean }

// Demonstração encenada: quem não tem plano pago vê a busca "acontecendo" e os leads
// aparecendo, com os contatos travados. Não chama o Google (cada busca real é paga).
const SAMPLE_NAMES = [
  { name: 'Studio Bella Estética', rating: 4.8, reviews: 127, site: false },
  { name: 'Padaria Pão Quente', rating: 4.6, reviews: 89, site: false },
  { name: 'Auto Center Silva', rating: 4.9, reviews: 203, site: true },
  { name: 'Clínica Vida & Saúde', rating: 4.7, reviews: 156, site: false },
  { name: 'Restaurante Sabor Caseiro', rating: 4.5, reviews: 64, site: false },
  { name: 'Pet Shop Amigo Fiel', rating: 4.8, reviews: 98, site: false },
]

const ETAPAS = ['Procurando empresas', 'Conferindo avaliações', 'Separando quem precisa do seu serviço', 'Juntando WhatsApp e Instagram']

export function DemoResults({ params, logado = false }: { params: DemoParams; logado?: boolean }) {
  const meta = SERVICE_META[params.service] || SERVICE_META.outros
  const local = params.allBrazil ? 'todo o Brasil' : (params.city || 'sua região')
  const segmento = SEGMENT_NAMES[params.segment] || params.segment || 'empresas'
  const [etapa, setEtapa] = useState(0)
  const [achados, setAchados] = useState(0)
  const [mostrados, setMostrados] = useState(0)
  const buscando = etapa < ETAPAS.length

  useEffect(() => {
    setEtapa(0); setAchados(0); setMostrados(0)
    const timers: ReturnType<typeof setTimeout>[] = []
    ETAPAS.forEach((_, i) => timers.push(setTimeout(() => setEtapa(i + 1), 650 * (i + 1))))
    const conta = setInterval(() => setAchados(n => Math.min(43, n + 3)), 120)
    timers.push(setTimeout(() => clearInterval(conta), 650 * ETAPAS.length))
    SAMPLE_NAMES.forEach((_, i) => timers.push(setTimeout(() => setMostrados(i + 1), 650 * ETAPAS.length + 180 * i)))
    return () => { timers.forEach(clearTimeout); clearInterval(conta) }
  }, [params.service, params.city, params.segment, params.allBrazil])

  if (buscando) {
    return (
      <div style={{ background: 'rgba(255,255,255,.03)', border: '1px solid rgba(248,182,200,.12)', borderRadius: 20, padding: '40px 28px', textAlign: 'center' }}>
        <div style={{ fontSize: '.78rem', fontWeight: 700, color: '#f8b6c8', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>
          {segmento} · {local}
        </div>
        <div style={{ fontSize: '2.6rem', fontWeight: 900, letterSpacing: -1.5, marginBottom: 6 }}>{achados}</div>
        <div style={{ fontSize: '.85rem', color: 'rgba(255,255,255,.45)', marginBottom: 24 }}>empresas encontradas</div>
        <div style={{ height: 6, background: 'rgba(255,255,255,.06)', borderRadius: 6, overflow: 'hidden', maxWidth: 420, margin: '0 auto 20px' }}>
          <div style={{ height: '100%', width: `${(etapa / ETAPAS.length) * 100}%`, background: 'linear-gradient(90deg,#e879a0,#c2185b)', transition: 'width .6s ease' }} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'center' }}>
          {ETAPAS.map((t, i) => (
            <div key={t} style={{ fontSize: '.82rem', color: i < etapa ? '#4ade80' : i === etapa ? '#fff' : 'rgba(255,255,255,.25)', transition: 'color .3s' }}>
              {i < etapa ? '✓ ' : i === etapa ? '… ' : ''}{t}
            </div>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16, flexWrap: 'wrap' }}>
        <div style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', borderRadius: 8, padding: '6px 14px', fontSize: '.82rem', fontWeight: 800, letterSpacing: .5 }}>
          {achados} leads encontrados
        </div>
        <span style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.35)' }}>{meta.filterLabel} · {local}</span>
        <span style={{ fontSize: '.72rem', fontWeight: 700, color: '#fbbf24', background: 'rgba(251,191,36,.08)', border: '1px solid rgba(251,191,36,.2)', borderRadius: 6, padding: '3px 8px' }}>DEMONSTRAÇÃO</span>
      </div>

      <div style={{ position: 'relative' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {SAMPLE_NAMES.slice(0, mostrados).map((s, i) => (
            <div key={s.name} style={{
              background: 'rgba(255,255,255,.03)',
              border: '1px solid rgba(248,182,200,.1)',
              borderRadius: 16, padding: '16px 20px',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap',
              filter: i > 1 ? `blur(${Math.min(i * 1.5, 5)}px)` : 'none',
              opacity: i > 1 ? 0.7 : 1,
              animation: 'pageIn .35s ease both',
            }}>
              <div style={{ flex: 1, minWidth: 200 }}>
                <div style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 6 }}>{s.name}</div>
                <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)', marginBottom: 8 }}>📍 {local}</div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <span style={{ fontSize: '.72rem', fontWeight: 700, color: '#fbbf24', background: 'rgba(251,191,36,.08)', borderRadius: 6, padding: '3px 8px' }}>⭐ {s.rating} ({s.reviews})</span>
                  {!s.site && <span style={{ fontSize: '.72rem', fontWeight: 700, color: '#f8b6c8', background: 'rgba(232,121,160,.1)', borderRadius: 6, padding: '3px 8px' }}>📷 Sem site</span>}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <span style={{ background: 'linear-gradient(135deg,#25D366,#128C7E)', color: '#fff', borderRadius: 10, padding: '8px 16px', fontSize: '.8rem', fontWeight: 700, filter: 'blur(1.5px)' }}>💬 (13) 9••••-••••</span>
                <span style={{ background: 'rgba(255,255,255,.08)', color: '#fff', borderRadius: 10, padding: '8px 16px', fontSize: '.8rem', fontWeight: 700 }}>🔒 Instagram</span>
              </div>
            </div>
          ))}
        </div>

        {mostrados >= SAMPLE_NAMES.length && (
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(180deg, transparent 0%, rgba(22,22,42,.6) 40%, rgba(22,22,42,.96) 75%)',
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end',
            textAlign: 'center', padding: '0 24px 28px', borderRadius: 16,
            animation: 'pageIn .4s ease both',
          }}>
            <div style={{ fontSize: '2rem', marginBottom: 8 }}>🔒</div>
            <h3 style={{ fontSize: '1.4rem', fontWeight: 800, marginBottom: 8, letterSpacing: -.5 }}>
              É assim que seus leads aparecem
            </h3>
            <p style={{ color: 'rgba(255,255,255,.6)', fontSize: '.92rem', maxWidth: 420, marginBottom: 20, lineHeight: 1.6 }}>
              {logado
                ? `Isto é uma demonstração. Assine pra buscar ${segmento.toLowerCase()} de verdade em ${local}, com WhatsApp, Instagram e telefone.`
                : 'Isto é uma demonstração. Crie sua conta e escolha um plano pra ver os leads de verdade, com WhatsApp, Instagram e telefone.'}
            </p>
            <Link href={logado ? '/#precos' : '/signup'} style={{
              background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff',
              borderRadius: 14, padding: '15px 34px', fontSize: '1rem', fontWeight: 700,
              textDecoration: 'none', boxShadow: '0 8px 30px rgba(232,121,160,.4)',
            }}>
              {logado ? 'Ver planos e liberar os leads →' : 'Criar conta e ver os planos →'}
            </Link>
            <p style={{ color: 'rgba(255,255,255,.35)', fontSize: '.78rem', marginTop: 14 }}>
              Freelancer por R$ 19,90/mês · 10 buscas por dia
            </p>
          </div>
        )}
      </div>
    </div>
  )
}
