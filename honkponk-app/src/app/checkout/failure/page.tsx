import Link from 'next/link'

export default function FailurePage() {
  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ textAlign: 'center', maxWidth: 480 }}>
        <div style={{ fontSize: '4rem', marginBottom: 24 }}>😕</div>
        <h1 style={{ fontSize: '2rem', fontWeight: 900, letterSpacing: -1, marginBottom: 12 }}>Pagamento não aprovado</h1>
        <p style={{ color: 'rgba(255,255,255,.6)', lineHeight: 1.7, marginBottom: 36 }}>Ocorreu um problema com o seu pagamento. Verifique os dados do cartão ou tente outro método.</p>
        <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link href="/#precos" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 700, textDecoration: 'none' }}>Tentar novamente</Link>
          <Link href="/dashboard" style={{ display: 'inline-block', background: 'rgba(255,255,255,.08)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 600, textDecoration: 'none' }}>Voltar ao dashboard</Link>
        </div>
      </div>
    </div>
  )
}
