'use client'
import { useState, useEffect } from 'react'
import { SERVICE_META, SEGMENT_NAMES } from '@/lib/search'

interface QuizData { service: string; city: string; segment: string; allBrazil: boolean }

const SERVICES = [
  { key: 'sites', icon: '🌐', name: 'Criação de Sites', desc: 'Só mostra empresas sem site' },
  { key: 'marketing', icon: '📱', name: 'Marketing Digital', desc: 'Foco em baixa presença online' },
  { key: 'design', icon: '🎨', name: 'Design Gráfico', desc: 'Negócios com identidade visual' },
  { key: 'contabilidade', icon: '📊', name: 'Contabilidade', desc: 'Micro e pequenas empresas' },
  { key: 'software', icon: '💻', name: 'Software / Sistemas', desc: 'Negócios que precisam de gestão' },
  { key: 'foto', icon: '📷', name: 'Foto / Vídeo', desc: 'Empresas visuais e eventos' },
  { key: 'rh', icon: '👥', name: 'RH / Recrutamento', desc: 'Empresas em crescimento' },
  { key: 'outros', icon: '✨', name: 'Outro serviço', desc: 'Todos os resultados disponíveis' },
]

const SEGMENTS = [
  { value: 'restaurant', label: 'Restaurantes' }, { value: 'beauty', label: 'Salões de Beleza' },
  { value: 'car_repair', label: 'Oficinas / Mecânicas' }, { value: 'clinic', label: 'Clínicas & Consultórios' },
  { value: 'gym', label: 'Academias' }, { value: 'pharmacy', label: 'Farmácias' },
  { value: 'hotel', label: 'Hotéis & Pousadas' }, { value: 'supermarket', label: 'Supermercados' },
  { value: 'bakery', label: 'Padarias' }, { value: 'bar', label: 'Bares' },
  { value: 'dentist', label: 'Dentistas' }, { value: 'school', label: 'Escolas' },
  { value: 'lawyer', label: 'Escritórios de Advocacia' }, { value: 'accounting', label: 'Contabilidades' },
  { value: 'clothing', label: 'Lojas de Roupa' },
]

export function QuizOverlay({ open, onClose, onSearch }: { open: boolean; onClose: () => void; onSearch: (data: QuizData) => void }) {
  const [step, setStep] = useState(1)
  const [service, setService] = useState('')
  const [city, setCity] = useState('')
  const [segment, setSegment] = useState('')
  const [allBrazil, setAllBrazil] = useState(false)

  useEffect(() => {
    if (open) { document.body.style.overflow = 'hidden'; setStep(1) }
    else document.body.style.overflow = ''
  }, [open])

  const meta = SERVICE_META[service] || SERVICE_META.outros
  const segName = SEGMENT_NAMES[segment] || segment

  if (!open) return null

  return (
    <div style={{ position: 'fixed', inset: 0, zIndex: 2000, background: 'rgba(8,8,16,.85)', backdropFilter: 'blur(12px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}
      onClick={e => { if (e.target === e.currentTarget) onClose() }}>
      <div className="animate-quiz-in" style={{ background: '#16162a', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 24, width: '100%', maxWidth: 680, padding: '40px', boxShadow: '0 40px 100px rgba(0,0,0,.8)', maxHeight: '90vh', overflowY: 'auto', position: 'relative' }}>
        <button onClick={onClose} style={{ position: 'absolute', top: 18, right: 22, background: 'none', border: 'none', color: 'rgba(255,255,255,.3)', fontSize: '1.4rem', cursor: 'pointer' }}>✕</button>
        <div style={{ display: 'flex', gap: 6, marginBottom: 28 }}>
          {[1,2,3].map(i => <div key={i} style={{ height: 4, flex: 1, borderRadius: 2, background: i <= step ? '#e879a0' : 'rgba(255,255,255,.1)', transition: 'background .3s' }} />)}
        </div>

        {step === 1 && (
          <div>
            <div style={{ fontSize: '.75rem', fontWeight: 700, color: '#e879a0', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>Passo 1 de 3</div>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 8 }}>O que você oferece?</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(130px,1fr))', gap: 10, marginBottom: 28 }}>
              {SERVICES.map(s => (
                <div key={s.key} onClick={() => setService(s.key)} style={{ background: service === s.key ? 'rgba(232,121,160,.12)' : 'rgba(255,255,255,.04)', border: `1.5px solid ${service === s.key ? '#e879a0' : 'rgba(255,255,255,.08)'}`, borderRadius: 16, padding: '18px 14px', cursor: 'pointer', textAlign: 'center', transition: 'all .2s' }}>
                  <div style={{ fontSize: '1.8rem', marginBottom: 8 }}>{s.icon}</div>
                  <div style={{ fontSize: '.82rem', fontWeight: 700 }}>{s.name}</div>
                  <div style={{ fontSize: '.7rem', color: 'rgba(255,255,255,.4)', marginTop: 4 }}>{s.desc}</div>
                </div>
              ))}
            </div>
            <button disabled={!service} onClick={() => setStep(2)} style={{ width: '100%', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 28px', fontSize: '.95rem', fontWeight: 700, cursor: service ? 'pointer' : 'not-allowed', opacity: service ? 1 : 0.4, fontFamily: 'inherit' }}>Próximo →</button>
          </div>
        )}

        {step === 2 && (
          <div>
            <div style={{ fontSize: '.75rem', fontWeight: 700, color: '#e879a0', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>Passo 2 de 3</div>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 8 }}>Onde e para quem?</h2>
            <input type="text" value={city} onChange={e => setCity(e.target.value)} disabled={allBrazil} placeholder="Cidade (ex: Santos, Campinas)" style={{ width: '100%', background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 14, padding: '16px 20px', color: '#fff', fontSize: '1rem', fontFamily: 'inherit', outline: 'none', marginBottom: 16, opacity: allBrazil ? 0.35 : 1 }} />
            <label style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 18, cursor: 'pointer', fontSize: '.85rem', color: 'rgba(255,255,255,.5)' }}>
              <input type="checkbox" checked={allBrazil} onChange={e => { setAllBrazil(e.target.checked); if (e.target.checked) setCity('') }} style={{ width: 16, height: 16, accentColor: '#e879a0' }} />
              Buscar em <strong style={{ color: 'rgba(255,255,255,.8)', marginLeft: 4 }}>todo o Brasil</strong>
            </label>
            <select value={segment} onChange={e => setSegment(e.target.value)} style={{ width: '100%', background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 14, padding: '16px 20px', color: segment ? '#fff' : 'rgba(255,255,255,.3)', fontSize: '1rem', fontFamily: 'inherit', outline: 'none', cursor: 'pointer', appearance: 'none', marginBottom: 28 }}>
              <option value="" style={{ background: '#16162a' }}>Selecione o tipo de negócio...</option>
              {SEGMENTS.map(s => <option key={s.value} value={s.value} style={{ background: '#16162a', color: '#fff' }}>{s.label}</option>)}
            </select>
            <div style={{ display: 'flex', gap: 12 }}>
              <button onClick={() => setStep(1)} style={{ background: 'none', border: '1px solid rgba(255,255,255,.12)', color: 'rgba(255,255,255,.5)', borderRadius: 12, padding: '12px 22px', fontSize: '.9rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>← Voltar</button>
              <button disabled={!(city || allBrazil) || !segment} onClick={() => setStep(3)} style={{ flex: 1, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 28px', fontSize: '.95rem', fontWeight: 700, cursor: (city || allBrazil) && segment ? 'pointer' : 'not-allowed', opacity: (city || allBrazil) && segment ? 1 : 0.4, fontFamily: 'inherit' }}>Próximo →</button>
            </div>
          </div>
        )}

        {step === 3 && (
          <div>
            <div style={{ fontSize: '.75rem', fontWeight: 700, color: '#e879a0', letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>Passo 3 de 3</div>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 8 }}>Tudo certo!</h2>
            <div style={{ background: 'rgba(248,182,200,.07)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 14, padding: 20, marginBottom: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}><span style={{ color: 'rgba(255,255,255,.4)', fontSize: '.82rem' }}>Seu serviço</span><span style={{ fontWeight: 700 }}>{meta.icon} {meta.name}</span></div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}><span style={{ color: 'rgba(255,255,255,.4)', fontSize: '.82rem' }}>Região</span><span style={{ fontWeight: 700 }}>{allBrazil ? '🇧🇷 Todo o Brasil' : city}</span></div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}><span style={{ color: 'rgba(255,255,255,.4)', fontSize: '.82rem' }}>Segmento</span><span style={{ fontWeight: 700 }}>{segName}</span></div>
            </div>
            <div style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.4)', lineHeight: 1.5, marginBottom: 24, padding: 14, background: 'rgba(255,255,255,.03)', borderRadius: 10, borderLeft: '3px solid #e879a0' }}>
              🎯 <strong>Filtro ativo:</strong> {meta.filterLabel}
            </div>
            <div style={{ display: 'flex', gap: 12 }}>
              <button onClick={() => setStep(2)} style={{ background: 'none', border: '1px solid rgba(255,255,255,.12)', color: 'rgba(255,255,255,.5)', borderRadius: 12, padding: '12px 22px', fontSize: '.9rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>← Voltar</button>
              <button onClick={() => onSearch({ service, city, segment, allBrazil })} style={{ flex: 1, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 28px', fontSize: '.95rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit' }}>🔍 Buscar leads agora</button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
