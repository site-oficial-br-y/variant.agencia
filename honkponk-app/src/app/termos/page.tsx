import Link from 'next/link'
import Image from 'next/image'

export default function TermosPage() {
  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', color: '#fff' }}>
      <nav style={{ padding: '16px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(15,15,26,0.8)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(248,182,200,0.18)' }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="/logo.svg" alt="Honk Ponk" width={32} height={32} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.2rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <Link href="/" style={{ color: 'rgba(255,255,255,.6)', textDecoration: 'none', fontSize: '.875rem' }}>← Voltar</Link>
      </nav>
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '60px 24px' }}>
        <h1 style={{ fontSize: '2.5rem', fontWeight: 900, letterSpacing: -1.5, marginBottom: 8 }}>Termos de Uso</h1>
        <p style={{ color: 'rgba(255,255,255,.4)', marginBottom: 48, fontSize: '.9rem' }}>Última atualização: Janeiro de 2025</p>
        {[
          { title: '1. Aceitação dos Termos', content: 'Ao acessar e utilizar a plataforma Honk Ponk, você concorda com os presentes Termos de Uso. Se você não concordar com algum dos termos, não utilize nossos serviços.' },
          { title: '2. Descrição do Serviço', content: 'A Honk Ponk é uma plataforma de prospecção B2B que utiliza a API do Google Places para fornecer dados públicos de negócios.' },
          { title: '3. Uso Aceitável', content: 'Você concorda em utilizar a plataforma apenas para fins legais e legítimos de prospecção comercial. É proibido: usar para spam ou assédio; automatizar ou fazer scraping; vender ou redistribuir os dados; violar a LGPD.' },
          { title: '4. Planos e Pagamentos', content: 'Os planos pagos são cobrados mensalmente via Mercado Pago. O cancelamento pode ser solicitado a qualquer momento. Reembolsos são analisados caso a caso, em até 7 dias após a contratação.' },
          { title: '5. Privacidade e Dados', content: 'Coletamos apenas os dados necessários para o funcionamento da plataforma: e-mail, histórico de buscas e dados de pagamento. Não vendemos seus dados a terceiros.' },
          { title: '6. LGPD', content: 'Em conformidade com a Lei nº 13.709/2018 (LGPD), você tem direito a acessar, corrigir, excluir e portar seus dados pessoais. Contato: honkponkoficial@gmail.com.' },
          { title: '7. Limitação de Responsabilidade', content: 'A Honk Ponk não se responsabiliza por decisões comerciais tomadas com base nos dados fornecidos ou imprecisões nos dados do Google Places.' },
          { title: '8. Contato', content: 'Dúvidas? honkponkoficial@gmail.com' },
        ].map(s => (
          <div key={s.title} style={{ marginBottom: 36 }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: '#f8b6c8', marginBottom: 10 }}>{s.title}</h2>
            <p style={{ fontSize: '.95rem', color: 'rgba(255,255,255,.65)', lineHeight: 1.8 }}>{s.content}</p>
          </div>
        ))}
        <div style={{ marginTop: 60, textAlign: 'center' }}>
          <Link href="/" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '12px 24px', fontSize: '.9rem', fontWeight: 700, textDecoration: 'none' }}>
            ← Voltar para o início
          </Link>
        </div>
      </div>
    </div>
  )
}
