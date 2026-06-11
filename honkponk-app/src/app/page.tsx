'use client'
import { useState, useEffect, useRef } from 'react'
import Image from 'next/image'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { canSearch } from '@/lib/plans'
import type { Plan } from '@/lib/plans'
import { QuizOverlay } from '@/components/QuizOverlay'
import { SearchResults } from '@/components/SearchResults'
import { DemoResults } from '@/components/DemoResults'
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

  useEffect(() => {
    const obs = new IntersectionObserver(
      entries => entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('visible'); obs.unobserve(e.target) } }),
      { threshold: 0.08 }
    )
    document.querySelectorAll('.reveal').forEach(el => obs.observe(el))
    return () => obs.disconnect()
  }, [])

  function handleSearch(data: QuizData) {
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
      <section style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', padding: '100px 24px 60px', position: 'relative', overflow: 'hidden' }}>
        <div className="hero-grid" />
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse 70% 60% at 60% 20%, rgba(232,121,160,.12) 0%, transparent 70%)', pointerEvents: 'none' }} />
        <div style={{ maxWidth: 1200, margin: '0 auto', width: '100%', display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(300px,1fr))', gap: 60, alignItems: 'center', position: 'relative', zIndex: 1 }}>
          {/* Texto */}
          <div className="reveal">
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'rgba(248,182,200,.1)', border: '1px solid rgba(248,182,200,.25)', borderRadius: 100, padding: '6px 14px', fontSize: '.78rem', fontWeight: 600, color: '#f8b6c8', marginBottom: 24 }}>
              <span style={{ width: 6, height: 6, background: '#e879a0', borderRadius: '50%', display: 'inline-block', animation: 'blink 2s ease-in-out infinite' }} />
              Prospecção inteligente com dados reais
            </div>
            <h1 style={{ fontSize: 'clamp(2.2rem,5vw,3.6rem)', fontWeight: 900, lineHeight: 1.1, letterSpacing: -2, marginBottom: 20 }}>
              Encontre clientes<br />
              <span style={{ background: 'linear-gradient(135deg,#e879a0,#f8b6c8)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>antes da concorrência.</span>
            </h1>
            <p style={{ fontSize: '1.05rem', color: 'rgba(255,255,255,.55)', lineHeight: 1.7, marginBottom: 36, maxWidth: 480 }}>
              Honk Ponk rastreia negócios por região e filtra leads que realmente precisam do seu serviço. Chega de prospectar empresas que já têm o que você vende.
            </p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 14 }}>
              <button onClick={() => setQuizOpen(true)} style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.35)' }}>
                🔍 Buscar leads agora
              </button>
              <a href="#como-funciona" style={{ display: 'inline-flex', alignItems: 'center', gap: 8, background: 'transparent', color: 'rgba(255,255,255,.75)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 600, textDecoration: 'none' }}>
                Ver como funciona
              </a>
            </div>
            <div style={{ display: 'flex', gap: 28, marginTop: 40 }}>
              {[['+ 180k', 'negócios mapeados'], ['340+', 'cidades cobertas'], ['94%', 'taxa de contato']].map(([num, lbl]) => (
                <div key={lbl}>
                  <div style={{ fontSize: '1.6rem', fontWeight: 800 }}>{num}</div>
                  <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>{lbl}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Monitor flutuante */}
          <div className="animate-float reveal" style={{ position: 'relative' }}>
            <div style={{ position: 'absolute', top: -18, right: 20, animation: 'float 4.5s 1s ease-in-out infinite', background: 'rgba(22,22,42,.95)', border: '1px solid rgba(248,182,200,.2)', borderRadius: 12, padding: '10px 14px', boxShadow: '0 20px 50px rgba(0,0,0,.5)', fontSize: '.72rem', whiteSpace: 'nowrap', zIndex: 10 }}>
              <div style={{ color: 'rgba(255,255,255,.4)', fontSize: '.62rem', marginBottom: 3 }}>Novo lead encontrado</div>
              <div style={{ fontWeight: 700, color: '#f8b6c8', fontSize: '.85rem' }}>Clínica Bella Vida</div>
              <div style={{ color: '#4ade80', fontSize: '.65rem' }}>↑ Score 98 · Santos/SP · sem site</div>
            </div>
            <div style={{ background: 'rgba(22,22,42,.95)', border: '1px solid rgba(248,182,200,.15)', borderRadius: 20, overflow: 'hidden', boxShadow: '0 40px 100px rgba(0,0,0,.6)' }}>
              <div style={{ background: 'rgba(30,30,53,.8)', padding: '10px 16px', display: 'flex', alignItems: 'center', gap: 8, borderBottom: '1px solid rgba(248,182,200,.1)' }}>
                {['#ff5f57','#febc2e','#28c840'].map(c => <div key={c} style={{ width: 10, height: 10, borderRadius: '50%', background: c }} />)}
                <div style={{ flex: 1, background: 'rgba(255,255,255,.05)', borderRadius: 6, padding: '4px 10px', fontSize: '.72rem', color: 'rgba(255,255,255,.3)', margin: '0 12px' }}>
                  🔒 app.honkponk.com.br/dashboard
                </div>
              </div>
              <div style={{ padding: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
                  <span style={{ fontSize: '.8rem', fontWeight: 700 }}>Painel de Prospecção</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '.68rem', color: '#4ade80', fontWeight: 600 }}>
                    <span style={{ width: 6, height: 6, background: '#4ade80', borderRadius: '50%', display: 'inline-block', animation: 'blink 2s ease-in-out infinite' }} />
                    ao vivo
                  </span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8, marginBottom: 12 }}>
                  {[['1.247','Leads hoje','+18%'],['83','Contatados','+7%'],['R$12k','Em negócios','+31%']].map(([val,lbl,delta]) => (
                    <div key={lbl} style={{ background: 'rgba(255,255,255,.05)', borderRadius: 10, padding: '10px 12px' }}>
                      <div style={{ fontSize: '1.1rem', fontWeight: 800 }}>{val}</div>
                      <div style={{ fontSize: '.62rem', color: 'rgba(255,255,255,.4)', margin: '2px 0' }}>{lbl}</div>
                      <div style={{ fontSize: '.62rem', color: '#4ade80' }}>↑ {delta}</div>
                    </div>
                  ))}
                </div>
                <div style={{ background: 'rgba(255,255,255,.04)', borderRadius: 10, padding: '10px 12px', marginBottom: 10, display: 'flex', alignItems: 'flex-end', gap: 3, height: 60 }}>
                  {[30,45,28,60,42,75,55,80,48,65,35,70,58,85,62,78,40,90,55,68].map((h, i) => (
                    <div key={i} style={{ flex: 1, background: 'rgba(232,121,160,.5)', borderRadius: 2, height: `${h}%` }} />
                  ))}
                </div>
                {[['Restaurante Sabor Caseiro','Sem site','97'],['Auto Center Silva','Sem site','91']].map(([name,tag,score]) => (
                  <div key={name} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '7px 0', borderTop: '1px solid rgba(255,255,255,.05)', fontSize: '.72rem' }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#e879a0', display: 'inline-block' }} />
                      {name}
                    </span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ background: 'rgba(74,222,128,.1)', color: '#4ade80', borderRadius: 4, padding: '2px 6px', fontSize: '.62rem' }}>{tag} ✓</span>
                      <span style={{ fontWeight: 700 }}>{score}</span>
                    </span>
                  </div>
                ))}
                <div style={{ background: 'rgba(232,121,160,.08)', border: '1px solid rgba(232,121,160,.2)', borderRadius: 8, padding: '8px 10px', marginTop: 8, fontSize: '.68rem' }}>
                  <div style={{ color: 'rgba(255,255,255,.4)', marginBottom: 2 }}>Filtro ativo</div>
                  <div style={{ fontWeight: 700, color: '#f8b6c8', fontSize: '.78rem' }}>Criação de Sites</div>
                  <div style={{ color: 'rgba(255,255,255,.4)', marginTop: 1 }}>Só leads sem site cadastrado</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Ticker */}
        <div style={{ position: 'absolute', bottom: 24, left: 0, right: 0, overflow: 'hidden', maskImage: 'linear-gradient(90deg,transparent,#000 15%,#000 85%,transparent)' }}>
          <div style={{ display: 'flex', gap: 32, animation: 'ticker 20s linear infinite', width: 'max-content' }}>
            {[...TICKER_ITEMS, ...TICKER_ITEMS].map((c, i) => (
              <span key={i} style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.2)', whiteSpace: 'nowrap', fontWeight: 600 }}>📍 {c}</span>
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
            {userId
              ? <SearchResults params={searchParams} userId={userId} plan={userPlan} onLimitReached={() => setLimitMsg(true)} />
              : <DemoResults params={searchParams} />}
          </div>
        </section>
      )}

      {/* Como funciona */}
      <section id="como-funciona" style={{ padding: '90px 24px', background: '#0f0f1a', position: 'relative', overflow: 'hidden' }}>
        <div className="hero-grid" style={{ opacity: 0.5 }} />
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
      <section id="recursos" style={{ padding: '90px 24px', background: '#16162a' }}>
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
      <section style={{ padding: '90px 24px', background: '#0f0f1a', position: 'relative', overflow: 'hidden' }}>
        <div className="hero-grid" style={{ opacity: 0.4 }} />
        <div style={{ maxWidth: 900, margin: '0 auto' }}>
          <div className="reveal" style={{ textAlign: 'center', marginBottom: 60 }}>
            <h2 style={{ fontSize: 'clamp(1.8rem,4vw,2.6rem)', fontWeight: 800, letterSpacing: -1.5 }}>Quem já usa, aprova.</h2>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(260px,1fr))', gap: 20 }}>
            {[
              { name: 'Lucas Martins', role: 'Designer Freelancer • Santos, SP', avatar: 'LM', color: '#e879a0', text: 'Em 10 minutos encontrei 30 empresas sem identidade visual na minha cidade. Fechei 2 clientes na mesma semana. Melhor ferramenta que já usei para prospecção.', stars: 5, ago: '3 dias atrás' },
              { name: 'Ana Paula R.', role: 'Dona de Agência • Campinas, SP', avatar: 'AP', color: '#a855f7', text: 'A mensagem pronta no WhatsApp faz toda diferença. A taxa de resposta é muito maior do que cold email. Já indiquei para 4 amigos do ramo.', stars: 5, ago: '1 semana atrás' },
              { name: 'Rafael Souza', role: 'Dev Web Freelancer • São Paulo, SP', avatar: 'RS', color: '#3b82f6', text: 'O filtro de empresas sem site é simplesmente perfeito. Só aparecem leads que realmente precisam do meu serviço. Economizo horas de pesquisa manual.', stars: 5, ago: '2 semanas atrás' },
            ].map(t => (
              <div key={t.name} className="reveal" style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 28, display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ display: 'flex', gap: 4 }}>
                  {[1,2,3,4,5].map(i => <span key={i} style={{ color: '#fbbf24', fontSize: '1rem' }}>★</span>)}
                </div>
                <p style={{ fontSize: '.88rem', color: 'rgba(255,255,255,.75)', lineHeight: 1.75, flex: 1 }}>"{t.text}"</p>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12, borderTop: '1px solid rgba(255,255,255,.06)', paddingTop: 16 }}>
                  <div style={{ width: 38, height: 38, borderRadius: '50%', background: t.color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '.75rem', fontWeight: 800, color: '#fff', flexShrink: 0 }}>{t.avatar}</div>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '.88rem' }}>{t.name}</div>
                    <div style={{ fontSize: '.72rem', color: 'rgba(255,255,255,.4)' }}>{t.role}</div>
                  </div>
                  <div style={{ marginLeft: 'auto', fontSize: '.68rem', color: 'rgba(255,255,255,.25)' }}>{t.ago}</div>
                </div>
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
          <Image src="/logo.png" alt="Honk Ponk" width={28} height={28} style={{ objectFit: 'contain', borderRadius: 6 }} />
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

    </>
  )
}
