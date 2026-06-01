'use client'
import { useState, useEffect, useRef } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { canSearch } from '@/lib/plans'
import type { Plan } from '@/lib/plans'
import { QuizOverlay } from '@/components/QuizOverlay'
import { SearchResults } from '@/components/SearchResults'
import { PricingSection } from '@/components/PricingSection'
import { Navbar } from '@/components/Navbar'

const TICKER_ITEMS = ['Santos','Campinas','São Paulo','Curitiba','Porto Alegre','Belo Horizonte','Fortaleza','Recife','Manaus','Goiânia','Florianópolis','Salvador','Belém','Natal','Maceió']

interface QuizData { service: string; city: string; segment: string; allBrazil: boolean }

export default function HomePage() {
  const [quizOpen, setQuizOpen] = useState(false)
  const [searchParams, setSearchParams] = useState<QuizData | null>(null)
  const [userId, setUserId] = useState<string | null>(null)
  const [userPlan, setUserPlan] = useState<Plan>('free')
  const [limitMsg, setLimitMsg] = useState(false)
  const supabase = createClient()

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (data.user) {
        setUserId(data.user.id)
        supabase.from('users_profiles').select('plan').eq('id', data.user.id).single().then(({ data: p }) => {
          if (p) setUserPlan(p.plan as Plan)
        })
      }
    })
  }, [supabase])

  function handleSearch(data: QuizData) {
    if (!userId) { window.location.href = '/signup'; return }
    setQuizOpen(false)
    setSearchParams(data)
    setLimitMsg(false)
    setTimeout(() => document.getElementById('results')?.scrollIntoView({ behavior: 'smooth' }), 100)
  }

  return (
    <>
      <Navbar onOpenQuiz={() => setQuizOpen(true)} />
      <QuizOverlay open={quizOpen} onClose={() => setQuizOpen(false)} onSearch={handleSearch} />

      {/* Hero */}
      <section style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '120px 24px 80px', textAlign: 'center', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse 80% 60% at 50% 0%, rgba(232,121,160,.18) 0%, transparent 70%)', pointerEvents: 'none' }} />
        <div className="reveal" style={{ position: 'relative', zIndex: 1, maxWidth: 760, margin: '0 auto' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 100, padding: '6px 16px', fontSize: '.78rem', fontWeight: 700, color: '#f8b6c8', marginBottom: 28, letterSpacing: '.5px', textTransform: 'uppercase' as const }}>
            🎯 Prospecção inteligente de leads B2B
          </div>
          <h1 style={{ fontSize: 'clamp(2.4rem,6vw,4.2rem)', fontWeight: 900, letterSpacing: -2, lineHeight: 1.05, marginBottom: 24 }}>
            Encontre seus próximos<br />
            <span style={{ background: 'linear-gradient(135deg,#e879a0,#f8b6c8)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>clientes agora.</span>
          </h1>
          <p style={{ fontSize: 'clamp(1rem,2vw,1.2rem)', color: 'rgba(255,255,255,.55)', maxWidth: 520, margin: '0 auto 40px', lineHeight: 1.6 }}>
            Pesquise empresas no Google Maps filtradas pelo seu serviço. Contato direto via WhatsApp em segundos.
          </p>
          <div style={{ display: 'flex', gap: 14, justifyContent: 'center', flexWrap: 'wrap' }}>
            <button onClick={() => setQuizOpen(true)} style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 14, padding: '16px 36px', fontSize: '1.05rem', fontWeight: 800, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 12px 40px rgba(232,121,160,.4)', letterSpacing: -.3 }}>
              🔍 Buscar leads grátis
            </button>
            <a href="#como-funciona" style={{ background: 'rgba(255,255,255,.07)', color: 'rgba(255,255,255,.8)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 14, padding: '16px 28px', fontSize: '1rem', fontWeight: 600, textDecoration: 'none' }}>
              Como funciona →
            </a>
          </div>
          <p style={{ marginTop: 20, fontSize: '.8rem', color: 'rgba(255,255,255,.3)' }}>Grátis para sempre • Sem cartão • Resultados reais</p>
        </div>

        {/* Ticker */}
        <div style={{ position: 'absolute', bottom: 32, left: 0, right: 0, overflow: 'hidden', maskImage: 'linear-gradient(90deg,transparent,#000 15%,#000 85%,transparent)' }}>
          <div style={{ display: 'flex', gap: 32, animation: 'ticker 20s linear infinite', width: 'max-content' }}>
            {[...TICKER_ITEMS, ...TICKER_ITEMS].map((c, i) => (
              <span key={i} style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.25)', whiteSpace: 'nowrap', fontWeight: 600 }}>📍 {c}</span>
            ))}
          </div>
        </div>
      </section>

      {/* Search results */}
      {searchParams && (
        <section id="results" style={{ padding: '60px 24px', background: '#16162a' }}>
          <div style={{ maxWidth: 900, margin: '0 auto' }}>
            {limitMsg && (
              <div style={{ background: 'rgba(251,146,60,.1)', border: '1px solid rgba(251,146,60,.25)', borderRadius: 14, padding: 20, marginBottom: 28, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
                <p style={{ color: '#fb923c', fontSize: '.9rem', fontWeight: 600 }}>⚡ Você atingiu o limite de buscas do seu plano hoje.</p>
                <Link href="/#precos" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 10, padding: '10px 20px', fontSize: '.85rem', fontWeight: 700, textDecoration: 'none' }}>Fazer upgrade</Link>
              </div>
            )}
            <SearchResults params={searchParams} userId={userId} onLimitReached={() => setLimitMsg(true)} />
          </div>
        </section>
      )}

      {/* Como funciona */}
      <section id="como-funciona" style={{ padding: '90px 24px', background: '#0f0f1a' }}>
        <div style={{ maxWidth: 1000, margin: '0 auto' }}>
          <div className="reveal" style={{ textAlign: 'center', marginBottom: 60 }}>
            <span style={{ display: 'inline-block', background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 100, padding: '4px 14px', fontSize: '.75rem', fontWeight: 700, color: '#f8b6c8', marginBottom: 16, letterSpacing: '.5px', textTransform: 'uppercase' as const }}>Como funciona</span>
            <h2 style={{ fontSize: 'clamp(1.8rem,4vw,2.8rem)', fontWeight: 800, letterSpacing: -1.5 }}>3 passos para encontrar clientes.</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(260px,1fr))', gap: 24 }}>
            {[
              { n: '01', icon: '🎯', title: 'Diga o que você oferece', desc: 'Selecione seu serviço — criação de sites, marketing, design, e mais.' },
              { n: '02', icon: '📍', title: 'Escolha a cidade e o nicho', desc: 'Filtramos pelo segmento certo: restaurantes, clínicas, oficinas...' },
              { n: '03', icon: '💬', title: 'Contate na hora', desc: 'Abra o WhatsApp com mensagem personalizada já preenchida.' },
            ].map(s => (
              <div key={s.n} className="reveal" style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28 }}>
                <div style={{ fontSize: '.72rem', fontWeight: 800, color: '#e879a0', letterSpacing: 2, marginBottom: 16 }}>{s.n}</div>
                <div style={{ fontSize: '2rem', marginBottom: 12 }}>{s.icon}</div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 800, marginBottom: 8 }}>{s.title}</h3>
                <p style={{ fontSize: '.85rem', color: 'rgba(255,255,255,.5)', lineHeight: 1.6 }}>{s.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features */}
      <section style={{ padding: '90px 24px', background: '#16162a' }}>
        <div style={{ maxWidth: 1000, margin: '0 auto' }}>
          <div className="reveal" style={{ textAlign: 'center', marginBottom: 60 }}>
            <h2 style={{ fontSize: 'clamp(1.8rem,4vw,2.8rem)', fontWeight: 800, letterSpacing: -1.5 }}>Tudo que você precisa para prospectar.</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 20 }}>
            {[
              { icon: '🗺️', title: 'Google Maps real', desc: 'Dados atualizados diretamente do Google Places.' },
              { icon: '🎯', title: 'Filtros inteligentes', desc: 'Só aparecem empresas que precisam do seu serviço.' },
              { icon: '💬', title: 'WhatsApp com 1 clique', desc: 'Mensagem personalizada gerada automaticamente.' },
              { icon: '📊', title: 'Export para Excel', desc: 'Baixe todos os leads em planilha com um clique.' },
              { icon: '🔒', title: 'Seguro e privado', desc: 'Seus dados protegidos com Supabase + RLS.' },
              { icon: '⚡', title: 'Resultados na hora', desc: 'Sem espera. Resultados em segundos.' },
            ].map(f => (
              <div key={f.title} className="reveal" style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.14)', borderRadius: 16, padding: 22 }}>
                <div style={{ fontSize: '1.8rem', marginBottom: 10 }}>{f.icon}</div>
                <h3 style={{ fontSize: '.95rem', fontWeight: 700, marginBottom: 6 }}>{f.title}</h3>
                <p style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.45)', lineHeight: 1.5 }}>{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials */}
      <section style={{ padding: '90px 24px', background: '#0f0f1a' }}>
        <div style={{ maxWidth: 900, margin: '0 auto' }}>
          <div className="reveal" style={{ textAlign: 'center', marginBottom: 60 }}>
            <h2 style={{ fontSize: 'clamp(1.8rem,4vw,2.6rem)', fontWeight: 800, letterSpacing: -1.5 }}>Quem já usa, aprova.</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(260px,1fr))', gap: 20 }}>
            {[
              { name: 'Lucas M.', role: 'Designer freelancer', text: '"Em 10 minutos encontrei 30 empresas sem identidade visual na minha cidade. Fechei 2 clientes na semana."' },
              { name: 'Ana P.', role: 'Agência de marketing', text: '"A mensagem pronta no WhatsApp faz toda diferença. Taxa de resposta muito maior que cold email."' },
              { name: 'Rafael S.', role: 'Desenvolvedor web', text: '"O filtro de empresas sem site é perfeito. Só aparecem leads qualificados que realmente precisam de mim."' },
            ].map(t => (
              <div key={t.name} className="reveal" style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28 }}>
                <p style={{ fontSize: '.9rem', color: 'rgba(255,255,255,.7)', lineHeight: 1.7, marginBottom: 20, fontStyle: 'italic' }}>{t.text}</p>
                <div style={{ fontWeight: 700, fontSize: '.88rem' }}>{t.name}</div>
                <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)' }}>{t.role}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <PricingSection onGetStarted={() => setQuizOpen(true)} />

      {/* Newsletter */}
      <section style={{ padding: '80px 24px', background: '#0f0f1a' }}>
        <div className="reveal" style={{ maxWidth: 520, margin: '0 auto', textAlign: 'center' }}>
          <h2 style={{ fontSize: '1.8rem', fontWeight: 800, letterSpacing: -1, marginBottom: 10 }}>Novidades e dicas de prospecção.</h2>
          <p style={{ color: 'rgba(255,255,255,.45)', marginBottom: 28, fontSize: '.9rem' }}>Receba dicas de vendas e atualizações do Honk Ponk. Sem spam.</p>
          <form action="https://api.web3forms.com/submit" method="POST" style={{ display: 'flex', gap: 10 }}>
            <input type="hidden" name="access_key" value="886d635d-f949-4a6d-b349-e11fdfa5463f" />
            <input type="email" name="email" required placeholder="seu@email.com" style={{ flex: 1, background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '13px 18px', color: '#fff', fontSize: '.95rem', fontFamily: 'inherit', outline: 'none' }} />
            <button type="submit" style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '13px 22px', fontSize: '.9rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', whiteSpace: 'nowrap' }}>Inscrever →</button>
          </form>
        </div>
      </section>

      {/* Footer */}
      <footer style={{ borderTop: '1px solid rgba(248,182,200,0.1)', padding: '32px 24px', textAlign: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, marginBottom: 16 }}>
          <Image src="https://site-oficial-br-y.github.io/Honkponk/logo.png" alt="Honk Ponk" width={28} height={28} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontWeight: 800, fontSize: '1rem' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </div>
        <div style={{ display: 'flex', gap: 20, justifyContent: 'center', marginBottom: 16, flexWrap: 'wrap' }}>
          <Link href="/termos" style={{ color: 'rgba(255,255,255,.35)', fontSize: '.8rem', textDecoration: 'none' }}>Termos de Uso</Link>
          <a href="mailto:honkponkoficial@gmail.com" style={{ color: 'rgba(255,255,255,.35)', fontSize: '.8rem', textDecoration: 'none' }}>Contato</a>
          <Link href="/dashboard" style={{ color: 'rgba(255,255,255,.35)', fontSize: '.8rem', textDecoration: 'none' }}>Dashboard</Link>
        </div>
        <p style={{ fontSize: '.75rem', color: 'rgba(255,255,255,.2)' }}>© 2025 Honk Ponk. Todos os direitos reservados.</p>
      </footer>

      <style>{`
        @keyframes ticker { from { transform: translateX(0) } to { transform: translateX(-50%) } }
        .reveal { opacity: 0; transform: translateY(24px); transition: opacity .6s ease, transform .6s ease; }
        .reveal.visible { opacity: 1; transform: translateY(0); }
      `}</style>

      <script dangerouslySetInnerHTML={{ __html: `
        const obs = new IntersectionObserver(entries => entries.forEach(e => { if(e.isIntersecting) { e.target.classList.add('visible'); obs.unobserve(e.target) } }), { threshold: 0.1 });
        document.querySelectorAll('.reveal').forEach(el => obs.observe(el));
      `}} />
    </>
  )
}
